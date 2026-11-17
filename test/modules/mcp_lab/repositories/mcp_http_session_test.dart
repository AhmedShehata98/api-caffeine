import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_diagnostic_sanitizer.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_diagnostic_stream.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_rpc_diagnostics.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_sse_parser.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Completer<ResponseBody>? held;
  final arrived = Completer<void>();
  int deleteStatus = 405;
  Map<String, dynamic> Function(String method)? resultFor;
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'DELETE') {
      return ResponseBody.fromString('', deleteStatus);
    }
    final bytes = <int>[];
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.addAll(chunk);
      }
    }
    final body = jsonDecode(utf8.decode(bytes)) as Map<String, dynamic>;
    if (body['method'] == 'tools/call' && held != null) {
      if (!arrived.isCompleted) arrived.complete();
      return held!.future;
    }
    return ResponseBody.fromString(
      jsonEncode({
        'jsonrpc': '2.0',
        'id': body['id'],
        'result':
            resultFor?.call(body['method'] as String) ??
            {
              'protocolVersion': '2025-11-25',
              'serverInfo': {'name': 'fake'},
              'value': 'canary',
            },
      }),
      200,
      headers: {
        'content-type': ['application/json'],
        if (body['method'] == 'initialize') 'mcp-session-id': ['fake-session'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const context = McpAccessContext(
    userId: 'user',
    workspaceId: 'workspace',
    generation: 1,
  );
  const server = McpServer(
    id: 'server',
    workspaceId: 'workspace',
    draft: McpServerDraft(
      name: 'HTTP',
      transport: McpTransport.http,
      url: 'https://example.test/mcp',
      headers: {'authorization': 'Bearer canary', 'x-team': 'qa'},
      secretKeys: ['header.authorization'],
    ),
    secretStates: {'header.authorization': SecretValueState.present},
  );
  Future<McpSession> open(
    _Adapter adapter, {
    bool Function()? authorized,
    Dio? client,
  }) async {
    final repository = McpHttpConnectionRepository(
      isAuthorized: (_, _) => authorized?.call() ?? true,
      clientVersion: '1',
      createClient: (_, _) => (client ?? Dio())..httpClientAdapter = adapter,
    );
    final result = await repository.connect(
      McpConnectTarget(
        context: context,
        server: server,
        timeout: const Duration(seconds: 3),
      ),
    );
    final session = result.valueOrNull!;
    expect((await session.request('initialize', {})).isSuccess, isTrue);
    expect(
      session
          .configureProtocol(era: NegotiatedEra.legacy, version: '2025-11-25')
          .isSuccess,
      isTrue,
    );
    expect(
      (await session.notify('notifications/initialized', {})).isSuccess,
      isTrue,
    );
    return session;
  }

  test(
    'large JSON network body retains sanitized full text behind the preview',
    () async {
      final text = '${'é' * (170 * 1024)}canary';
      final adapter = _Adapter()
        ..resultFor = (method) => method == 'tools/call'
            ? {'text': text, 'tail': 'end-marker'}
            : {'protocolVersion': '2025-11-25'};
      final session = await open(adapter);
      final captured = session.network
          .firstWhere((entry) => entry.body?.contains('end-marker') ?? false)
          .timeout(const Duration(seconds: 5));
      final response = await session.request('tools/call', {'name': 'large'});
      expect(response.valueOrNull!['text'], text);
      final entry = await captured;
      expect(entry.truncated, isFalse);
      expect(entry.body, isNot(contains('canary')));
      expect(jsonDecode(entry.requestBody!)['params']['name'], 'large');
      final buffer = McpDiagnosticBuffer()..addNetwork(entry);
      expect(buffer.entries.single.truncated, isTrue);
      expect(buffer.entries.single.fullAvailable, isTrue);
      expect(
        utf8.encode(buffer.entries.single.text).length,
        lessThanOrEqualTo(256 * 1024),
      );
      final loaded = (await buffer.loadFullJson(0)).valueOrNull as Map;
      expect(loaded['result']['tail'], 'end-marker');
      expect(loaded['result']['text'], endsWith('[REDACTED]'));
      buffer.dispose();
      expect(buffer.copyText(0).isSuccess, isFalse);
      await session.close();
    },
  );

  test(
    'network retains the sanitized request, notifications and bodyless DELETE',
    () async {
      final adapter = _Adapter();
      final session = await open(adapter);
      final entries = <NetworkEntry>[];
      final done = Completer<void>();
      final subscription = session.network.listen(
        entries.add,
        onDone: done.complete,
      );
      final captured = session.network.firstWhere(
        (entry) => entry.requestBody?.contains('request-tail') ?? false,
      );
      final requestText = '${'é' * (170 * 1024)}canary-request-tail';
      await session.request('tools/call', {
        'name': 'large',
        'arguments': {'text': requestText},
      });
      final entry = await captured;
      expect(entry.requestBody, isNot(contains('canary')));
      expect(entry.requestBody, contains('[REDACTED]-request-tail'));
      final buffer = McpDiagnosticBuffer()..addNetwork(entry);
      expect(buffer.entries.single.requestBody!.truncated, isTrue);
      expect(buffer.entries.single.truncated, isFalse);
      expect(
        (await buffer.loadFullJson(
          0,
          side: McpNetworkBodySide.request,
        )).valueOrNull,
        isA<Map>(),
      );
      expect(
        jsonDecode(
          buffer.copyText(0, side: McpNetworkBodySide.request).valueOrNull!,
        )['params']['arguments']['text'],
        endsWith('[REDACTED]-request-tail'),
      );
      expect(
        jsonDecode(
          adapter.requests.last.data as String,
        )['params']['arguments']['text'],
        requestText,
      );
      await session.close();
      await done.future;
      await subscription.cancel();
      final notice = entries.firstWhere(
        (value) =>
            value.requestBody?.contains('notifications/initialized') ?? false,
      );
      expect(
        jsonDecode(notice.requestBody!)['method'],
        'notifications/initialized',
      );
      final deleted = entries.singleWhere((value) => value.method == 'DELETE');
      expect(notice.truncated, isTrue);
      expect(deleted.requestBody, isNull);
      expect(deleted.body, isNull);
      buffer.dispose();
    },
  );

  test('large multi-frame SSE network body loads sanitized complete frames', () async {
    final adapter = _Adapter();
    final session = await open(adapter);
    adapter.held = Completer<ResponseBody>();
    final captured = session.network
        .firstWhere((entry) => (entry.body?.length ?? 0) > 256 * 1024)
        .timeout(const Duration(seconds: 5));
    final request = session.request('tools/call', {'name': 'large'});
    await adapter.arrived.future;
    final id = jsonDecode(adapter.requests.last.data as String)['id'];
    final frames = [
      {
        'jsonrpc': '2.0',
        'method': 'notifications/message',
        'params': {'text': '${'x' * (300 * 1024)}canary'},
      },
      {
        'jsonrpc': '2.0',
        'id': id,
        'result': {'text': 'canary', 'tail': 'last-frame'},
      },
    ];
    final wire = frames
        .map(
          (frame) =>
              '${const JsonEncoder.withIndent('  ').convert(frame).split('\n').map((line) => 'data: $line').join('\n')}\n\n',
        )
        .join();
    adapter.held!.complete(
      ResponseBody.fromString(
        wire,
        200,
        headers: {
          'content-type': ['text/event-stream'],
        },
      ),
    );
    expect((await request).valueOrNull!['text'], 'canary');
    final entry = await captured;
    expect(entry.truncated, isFalse);
    expect(entry.body, isNot(contains('canary')));
    final buffer = McpDiagnosticBuffer()..addNetwork(entry);
    final loaded = (await buffer.loadFullJson(0)).valueOrNull as List;
    expect(loaded, hasLength(2));
    expect(loaded.last['result']['tail'], 'last-frame');
    expect(loaded.last['result']['text'], '[REDACTED]');
    buffer.dispose();
    await session.close();
  });

  group('SSE parser', () {
    test(
      'decodes byte-fragmented UTF-8, CRLF, comments and multiline data',
      () async {
        const event =
            ': comment\r\nid: ignored\r\ndata: {"text":\r\ndata: "雪"}\r\n\r\n';
        final chunks = Stream<List<int>>.fromIterable(
          utf8.encode(event).map((byte) => [byte]),
        );
        final frames = await mcpSseFrames(chunks).toList();
        expect(jsonDecode(frames.single), {'text': '雪'});
      },
    );
    test('dispatches independent events without inheriting metadata-only events', () async {
      for (final ending in ['\n', '\r\n', '\r']) {
        final events = await mcpSseFrames(
          Stream.value(
            utf8.encode(
              '\uFEFFdata: one$ending${ending}id: ignored$ending${ending}data: two$ending$ending',
            ),
          ),
        ).toList();
        expect(events, ['one', 'two']);
      }
    });
    test('rejects incomplete EOF and oversized events', () async {
      await expectLater(
        mcpSseFrames(Stream.value(utf8.encode('data: {}\n'))).toList(),
        throwsFormatException,
      );
      await expectLater(
        mcpSseFrames(
          Stream.value(utf8.encode('data: oversized\n\n')),
          maxBytes: 8,
        ).toList(),
        throwsFormatException,
      );
    });
    test('malformed UTF-8 is explicit', () async {
      await expectLater(
        mcpSseFrames(Stream.value([100, 97, 116, 97, 58, 255, 10, 10]))
            .toList(),
        throwsFormatException,
      );
    });
  });
  group('shared diagnostic capture', () {
    test(
      'startup limits surface dropped entries and disposal removes backlog',
      () async {
        final events = McpDiagnosticStream<String>((count) => 'dropped:$count');
        events.add('kept', 4);
        events.add('oversized', 2 * 1024 * 1024);
        expect(await events.stream.take(2).toList(), ['kept', 'dropped:1']);
        await events.close();
        final disposed = McpDiagnosticStream<String>(
          (count) => 'dropped:$count',
        );
        disposed.add('must-clear', 10);
        await disposed.close();
        expect(await disposed.stream.toList(), isEmpty);
        expect(() => disposed.add('late', 4), throwsStateError);
      },
    );
    test('frame IDs and metadata use the sanitized representation', () async {
      final sanitizer = McpDiagnosticSanitizer(secretValues: ['canary']);
      final diagnostics = McpRpcDiagnostics(sanitizer);
      diagnostics.record(
        '{"jsonrpc":"2.0","id":"canary","method":"tools/call","params":{"_meta":{"token":"canary"}}}',
        RpcDirection.outgoing,
      );
      final frame = await diagnostics.stream.first;
      expect(frame.id, '[REDACTED]');
      expect(frame.meta['token'], '[REDACTED]');
      expect(frame.redacted, isTrue);
      await diagnostics.close();
      sanitizer.dispose();
    });
    test(
      'known credentials remain protected in encoded MCP header sentinels',
      () {
        const secret = '雪 credential';
        final sanitizer = McpDiagnosticSanitizer(secretValues: [secret]);
        expect(
          sanitizer.text('=?base64?${base64Encode(utf8.encode(secret))}?='),
          '[REDACTED]',
        );
      },
    );
  });

  test('dedicated HTTP client suppresses raw interceptors and uses session headers', () async {
    var intercepted = false;
    final client = Dio()
      ..interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            intercepted = true;
            handler.next(options);
          },
        ),
      );
    final adapter = _Adapter();
    final session = await open(adapter, client: client);
    try {
      expect(
        (await session.request('tools/call', {'name': 'echo'})).isSuccess,
        isTrue,
      );
      expect(intercepted, isFalse);
      expect(adapter.requests.last.headers['mcp-session-id'], 'fake-session');
      expect(
        adapter.requests.last.headers['mcp-protocol-version'],
        '2025-11-25',
      );
      expect(adapter.requests.last.headers['x-team'], 'qa');
    } finally {
      expect((await session.close()).isSuccess, isTrue);
    }
  });
  test('invalid URL, missing secrets and deprecated transport fail before client creation', () async {
    var created = 0;
    final repository = McpHttpConnectionRepository(
      isAuthorized: (_, _) => true,
      clientVersion: '1',
      createClient: (_, _) {
        created++;
        return Dio();
      },
    );
    for (final invalid in [
      server.copyWith(
        draft: server.draft.copyWith(url: 'https://@example.test'),
      ),
      server.copyWith(
        draft: server.draft.copyWith(transport: McpTransport.sse),
      ),
      server.copyWith(secretStates: {}),
    ]) {
      final result = await repository.connect(
        McpConnectTarget(
          context: context,
          server: invalid,
          timeout: const Duration(seconds: 3),
        ),
      );
      expect(result.failureOrNull, isA<McpValidationFailure>());
    }
    expect(created, 0);
  });
  test(
    'modern tools/call mirrors annotated scalar arguments after tools/list',
    () async {
      final adapter = _Adapter()
        ..resultFor = (method) => method == 'tools/list'
            ? {
                'tools': [
                  {
                    'name': 'route',
                    'inputSchema': {
                      'type': 'object',
                      'properties': {
                        'region': {'type': 'string', 'x-mcp-header': 'Region'},
                        'enabled': {
                          'type': 'boolean',
                          'x-mcp-header': 'Enabled',
                        },
                        'count': {'type': 'integer', 'x-mcp-header': 'Count'},
                        'profile': {
                          'type': 'object',
                          'properties': {
                            'zone': {'type': 'string', 'x-mcp-header': 'Zone'},
                          },
                        },
                      },
                    },
                  },
                  {
                    'name': 'invalid',
                    'inputSchema': {
                      'properties': {
                        'value': {'type': 'number', 'x-mcp-header': 'Value'},
                      },
                    },
                  },
                ],
              }
            : {'ok': true};
      final repository = McpHttpConnectionRepository(
        isAuthorized: (_, _) => true,
        clientVersion: '1',
        createClient: (_, _) => Dio()..httpClientAdapter = adapter,
      );
      final connected = await repository.connect(
        McpConnectTarget(
          context: context,
          server: server,
          timeout: const Duration(seconds: 3),
        ),
      );
      final session = connected.valueOrNull!;
      expect(
        session
            .configureProtocol(era: NegotiatedEra.modern, version: '2026-07-28')
            .isSuccess,
        isTrue,
      );
      final listed = await session.request('tools/list', {});
      expect(listed.isSuccess, isTrue);
      expect(listed.valueOrNull!['tools'], hasLength(1));
      adapter.resultFor = (method) => method == 'tools/list'
          ? {
              'tools': [
                {'name': 'next-page-tool', 'inputSchema': <String, dynamic>{}},
              ],
            }
          : {'ok': true};
      await session.request('tools/list', {'cursor': 'next-page'});
      expect(
        (await session.request('tools/call', {
          'name': 'route',
          'arguments': {
            'region': 'eu west',
            'enabled': true,
            'count': 4,
            'profile': {'zone': 'west'},
          },
        })).isSuccess,
        isTrue,
      );
      final headers = adapter.requests.last.headers;
      expect(headers['mcp-param-region'], 'eu west');
      expect(headers['mcp-param-enabled'], 'true');
      expect(headers['mcp-param-count'], '4');
      expect(headers['mcp-param-zone'], 'west');
      expect(
        jsonDecode(adapter.requests.last.data as String)['params']['arguments'],
        {
          'region': 'eu west',
          'enabled': true,
          'count': 4,
          'profile': {'zone': 'west'},
        },
      );
      await session.request('tools/call', {
        'name': 'route',
        'arguments': {
          'region': null,
          'count': 9007199254740992,
          'enabled': 'true',
        },
      });
      final omittedHeaders = adapter.requests.last.headers;
      expect(omittedHeaders.containsKey('mcp-param-region'), isFalse);
      expect(omittedHeaders.containsKey('mcp-param-count'), isFalse);
      expect(omittedHeaders.containsKey('mcp-param-enabled'), isFalse);
      await session.request('tools/list', {});
      await session.request('tools/call', {
        'name': 'route',
        'arguments': {'region': 'west'},
      });
      expect(
        adapter.requests.last.headers.containsKey('mcp-param-region'),
        isFalse,
      );
      await session.close();
    },
  );
  test(
    'mirrored values use base64 sentinel when HTTP header bytes are unsafe',
    () async {
      final adapter = _Adapter()
        ..resultFor = (method) => method == 'tools/list'
            ? {
                'tools': [
                  {
                    'name': 'route',
                    'inputSchema': {
                      'properties': {
                        'region': {'type': 'string', 'x-mcp-header': 'Region'},
                      },
                    },
                  },
                ],
              }
            : {};
      final repository = McpHttpConnectionRepository(
        isAuthorized: (_, _) => true,
        clientVersion: '1',
        createClient: (_, _) => Dio()..httpClientAdapter = adapter,
      );
      final session = (await repository.connect(
        McpConnectTarget(
          context: context,
          server: server,
          timeout: const Duration(seconds: 3),
        ),
      )).valueOrNull!;
      session.configureProtocol(
        era: NegotiatedEra.modern,
        version: '2026-07-28',
      );
      await session.request('tools/list', {});
      await session.request('tools/call', {
        'name': 'route',
        'arguments': {'region': '雪'},
      });
      expect(
        adapter.requests.last.headers['mcp-param-region'],
        '=?base64?${base64Encode(utf8.encode('雪'))}?=',
      );
      await session.close();
    },
  );
  test(
    'cleanup failure stays visible while local session becomes closed',
    () async {
      final adapter = _Adapter()..deleteStatus = 500;
      final session = await open(adapter);
      expect((await session.close()).failureOrNull, isA<McpNetworkFailure>());
      expect((await session.request('tools/call', {})).isSuccess, isFalse);
    },
  );
  test('late HTTP responses after account changes never publish raw result payloads', () async {
    var authorized = true;
    final adapter = _Adapter();
    final session = await open(adapter, authorized: () => authorized);
    final frames = <RpcFrame>[];
    final subscription = session.frames.listen(frames.add);
    adapter.held = Completer<ResponseBody>();
    final request = session.request('tools/call', {'name': 'echo'});
    await adapter.arrived.future;
    authorized = false;
    adapter.held!.complete(
      ResponseBody.fromString(
        '{"jsonrpc":"2.0","id":2,"result":{"late":"canary"}}',
        200,
        headers: {
          'content-type': ['application/json'],
        },
      ),
    );
    expect((await request).failureOrNull, isA<McpAuthFailure>());
    expect(frames.where((frame) => frame.rawJson.contains('late')), isEmpty);
    await session.close();
    await subscription.cancel();
  });
  test(
    'request timeout completes even when a fake adapter ignores cancellation',
    () async {
      final adapter = _Adapter();
      final session = await open(adapter);
      adapter.held = Completer<ResponseBody>();
      final request = session.request('tools/call', {
        'name': 'echo',
      }, timeout: const Duration(milliseconds: 20));
      await adapter.arrived.future;
      expect((await request).failureOrNull, isA<McpNetworkFailure>());
      adapter.held!.complete(ResponseBody.fromString('{}', 200));
      await session.close();
    },
  );
}
