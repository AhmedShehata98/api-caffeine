import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';

class _Adapter implements HttpClientAdapter {
  final requests = <RequestOptions>[];
  Future<ResponseBody> Function()? getResponse;
  Completer<ResponseBody>? callResponse;
  Completer<ResponseBody>? replyResponse;
  final replyArrived = Completer<Map>();
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'GET') {
      return getResponse == null
          ? ResponseBody.fromString('', 405)
          : getResponse!();
    }
    if (options.method == 'DELETE') return ResponseBody.fromString('', 405);
    final bytes = BytesBuilder();
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
    }
    final request = jsonDecode(utf8.decode(bytes.takeBytes())) as Map;
    if (request['error'] != null) {
      if (!replyArrived.isCompleted) replyArrived.complete(request);
      return replyResponse?.future ?? ResponseBody.fromString('', 202);
    }
    if (request['id'] == null) return ResponseBody.fromString('', 202);
    if (request['method'] == 'tools/call' && callResponse != null) {
      return callResponse!.future;
    }
    final result = switch (request['method']) {
      'initialize' => {
        'protocolVersion': '2025-11-25',
        'capabilities': {},
        'serverInfo': {'name': 'test', 'version': '1'},
      },
      'server/discover' => {
        'supportedVersions': ['2026-07-28'],
        'capabilities': {},
        'serverInfo': {'name': 'test', 'version': '1'},
      },
      _ => {'real': true},
    };
    return ResponseBody.fromString(
      jsonEncode({'jsonrpc': '2.0', 'id': request['id'], 'result': result}),
      200,
      headers: {
        'content-type': ['application/json'],
        if (request['method'] == 'initialize')
          'mcp-session-id': ['session-private'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<McpSession> connect(
    _Adapter adapter, {
    Duration timeout = const Duration(seconds: 1),
    bool Function()? authorized,
  }) async {
    final repository = McpHttpConnectionRepository(
      isAuthorized: (_, _) => authorized?.call() ?? true,
      clientVersion: 'test',
      createClient: (_, _) => Dio()..httpClientAdapter = adapter,
    );
    return (await repository.connect(
      McpConnectTarget(
        context: const McpAccessContext(
          userId: 'u',
          workspaceId: 'w',
          generation: 1,
        ),
        server: const McpServer(
          id: 's',
          workspaceId: 'w',
          draft: McpServerDraft(
            name: 'HTTP',
            transport: McpTransport.http,
            url: 'https://example.test/mcp',
            headers: {
              'authorization': 'Bearer secret-canary',
              'last-event-id': 'must-not-forward',
            },
            secretKeys: ['header.authorization'],
          ),
          secretStates: {'header.authorization': SecretValueState.present},
        ),
        timeout: timeout,
      ),
    )).valueOrNull!;
  }

  Future<void> ready(McpSession session) async {
    expect(
      (await const McpNegotiationService(clientVersion: 'test')
              .negotiate(session))
          .isSuccess,
      isTrue,
    );
  }

  ResponseBody streamBody(StreamController<Uint8List> stream) => ResponseBody(
    stream.stream,
    200,
    headers: {
      'content-type': ['text/event-stream'],
    },
  );

  test(
    'optional GET 405 is tolerated with session headers and no cursor',
    () async {
      final adapter = _Adapter();
      final session = await connect(adapter);
      final captured = session.network.firstWhere(
        (entry) => entry.method == 'GET',
      );
      await ready(session);
      final get = adapter.requests.singleWhere(
        (request) => request.method == 'GET',
      );
      expect(get.headers['accept'], 'text/event-stream');
      expect(get.headers['mcp-session-id'], 'session-private');
      expect(get.headers['mcp-protocol-version'], '2025-11-25');
      expect(get.headers.containsKey('last-event-id'), isFalse);
      expect((await captured).status, 405);
      expect(
        (await session.request('tools/call', {'name': 'test'})).isSuccess,
        isTrue,
      );
      await session.notify('notifications/initialized', {});
      expect(
        adapter.requests.where((request) => request.method == 'GET'),
        hasLength(1),
      );
      expect((await session.close()).isSuccess, isTrue);
    },
  );

  test('modern negotiation does not open a notification GET', () async {
    final adapter = _Adapter();
    final session = await connect(adapter);
    expect(
      (await const McpNegotiationService(
        clientVersion: 'test',
      ).negotiate(session, era: McpProtocolEra.modern)).isSuccess,
      isTrue,
    );
    expect(
      adapter.requests.where((request) => request.method == 'GET'),
      isEmpty,
    );
    await session.close();
  });

  test(
    'live notifications are sanitized, and idle GET closes with the session',
    () async {
      final stream = StreamController<Uint8List>();
      final adapter = _Adapter()..getResponse = () async => streamBody(stream);
      final session = await connect(
        adapter,
        timeout: const Duration(milliseconds: 80),
      );
      await ready(session);
      final frame = session.frames.firstWhere(
        (frame) => frame.method == 'notifications/message',
      );
      stream.add(
        utf8.encode(
          'data: {"jsonrpc":"2.0","method":"notifications/message","params":{"text":"secret-canary"}}\n\n',
        ),
      );
      expect((await frame).rawJson, contains('[REDACTED]'));
      await Future<void>.delayed(const Duration(milliseconds: 100));
      expect(
        (await session.request('tools/call', {
          'name': 'still-active',
        })).isSuccess,
        isTrue,
      );
      final watch = Stopwatch()..start();
      expect((await session.close()).isSuccess, isTrue);
      expect(watch.elapsedMilliseconds, lessThan(1000));
      expect(stream.hasListener, isFalse);
      await stream.close();
    },
  );

  test(
    'unsupported server requests receive method-not-found on POST',
    () async {
      final stream = StreamController<Uint8List>();
      final adapter = _Adapter()..getResponse = () async => streamBody(stream);
      final session = await connect(adapter);
      await ready(session);
      stream.add(
        utf8.encode(
          'data: {"jsonrpc":"2.0","id":"ask","method":"sampling/createMessage","params":{}}\n\n',
        ),
      );
      final reply = await adapter.replyArrived.future;
      expect(reply['id'], 'ask');
      expect(reply['error']['code'], -32601);
      expect(
        (await session.request('tools/call', {
          'name': 'still-active',
        })).isSuccess,
        isTrue,
      );
      await session.close();
      await stream.close();
    },
  );

  test(
    'an unsolicited GET response cannot complete a concurrent POST call',
    () async {
      final stream = StreamController<Uint8List>();
      final adapter = _Adapter()..getResponse = () async => streamBody(stream);
      final session = await connect(adapter);
      await ready(session);
      adapter.callResponse = Completer<ResponseBody>();
      var completed = false;
      final pending = session.request('tools/call', {'name': 'held'}).then((
        value,
      ) {
        completed = true;
        return value;
      });
      final warning = session.frames.firstWhere(
        (frame) => frame.kind == RpcFrameKind.warning,
      );
      stream.add(
        utf8.encode(
          'data: {"jsonrpc":"2.0","id":2,"result":{"fake":true}}\n\n',
        ),
      );
      expect((await warning).rawJson, contains('Ignored a response'));
      expect(completed, isFalse);
      adapter.callResponse!.complete(
        ResponseBody.fromString(
          '{"jsonrpc":"2.0","id":2,"result":{"real":true}}',
          200,
          headers: {
            'content-type': ['application/json'],
          },
        ),
      );
      expect((await pending).valueOrNull, {'real': true});
      await session.close();
      await stream.close();
    },
  );

  for (final status in [401, 403, 404]) {
    test(
      'optional GET $status invalidates the session during negotiation',
      () async {
        final adapter = _Adapter()
          ..getResponse = () async => ResponseBody.fromString('', status);
        final session = await connect(adapter);
        expect(
          (await const McpNegotiationService(clientVersion: 'test')
                  .negotiate(session))
              .isSuccess,
          isFalse,
        );
        expect((await session.request('tools/call', {})).isSuccess, isFalse);
        await session.close();
      },
    );
  }
  for (final status in [200, 503]) {
    test(
      'unsupported optional GET $status does not disable ordinary calls',
      () async {
        final adapter = _Adapter()
          ..getResponse = () async => ResponseBody.fromString(
            '{}',
            status,
            headers: {
              'content-type': ['application/json'],
            },
          );
        final session = await connect(adapter);
        final warning = session.console.first;
        await ready(session);
        expect(
          (await warning).text,
          contains('Request calls remain available'),
        );
        expect((await session.request('tools/call', {})).isSuccess, isTrue);
        await session.close();
      },
    );
  }
  test('GET header timeout is bounded and leaves calls usable', () async {
    final held = Completer<ResponseBody>();
    final adapter = _Adapter()..getResponse = () => held.future;
    final session = await connect(
      adapter,
      timeout: const Duration(milliseconds: 40),
    );
    final warning = session.console.first;
    await ready(session);
    expect((await warning).text, contains('opening timed out'));
    expect((await session.request('tools/call', {})).isSuccess, isTrue);
    held.complete(ResponseBody.fromString('', 405));
    await session.close();
  });
  test('revocation while GET headers are pending cannot report successful negotiation', () async {
    var authorized = true;
    final held = Completer<ResponseBody>();
    final arrived = Completer<void>();
    final adapter = _Adapter()
      ..getResponse = () {
        arrived.complete();
        return held.future;
      };
    final session = await connect(
      adapter,
      authorized: () => authorized,
      timeout: const Duration(milliseconds: 40),
    );
    final pending = const McpNegotiationService(clientVersion: 'test')
        .negotiate(session);
    await arrived.future;
    authorized = false;
    expect((await pending).failureOrNull, isA<McpAuthFailure>());
    held.complete(ResponseBody.fromString('', 405));
    await session.close();
  });
  for (final fail in [false, true]) {
    test(
      'optional stream ${fail ? 'error' : 'EOF'} is visible without disabling calls',
      () async {
        final stream = StreamController<Uint8List>();
        final adapter = _Adapter()
          ..getResponse = () async => streamBody(stream);
        final session = await connect(adapter);
        final captured = session.network.firstWhere(
          (entry) => entry.method == 'GET',
        );
        final warning = session.console.first;
        await ready(session);
        if (fail) {
          stream.addError(StateError('raw-secret-exception'));
        } else {
          await stream.close();
        }
        expect((await warning).text, contains(fail ? 'failed' : 'ended'));
        expect((await captured).truncated, fail);
        expect((await session.request('tools/call', {})).isSuccess, isTrue);
        await session.close();
        if (fail) await stream.close();
      },
    );
  }
  test(
    'a hanging unsupported-request reply is bounded without disabling calls',
    () async {
      final stream = StreamController<Uint8List>();
      final adapter = _Adapter();
      adapter.getResponse = () async => streamBody(stream);
      adapter.replyResponse = Completer<ResponseBody>();
      final session = await connect(
        adapter,
        timeout: const Duration(milliseconds: 80),
      );
      await ready(session);
      final warning = session.console.first;
      stream.add(
        utf8.encode(
          'data: {"jsonrpc":"2.0","id":"hang","method":"sampling/createMessage","params":{}}\n\n',
        ),
      );
      await adapter.replyArrived.future;
      expect((await warning).text, contains('Could not answer'));
      adapter.replyResponse!.complete(ResponseBody.fromString('', 202));
      expect((await session.request('tools/call', {})).isSuccess, isTrue);
      await session.close();
      await stream.close();
    },
  );
  test(
    'switching to modern cancels the old listener before late frames',
    () async {
      final stream = StreamController<Uint8List>();
      final adapter = _Adapter()..getResponse = () async => streamBody(stream);
      final session = await connect(adapter);
      await ready(session);
      final frames = <RpcFrame>[];
      final subscription = session.frames.listen(frames.add);
      session.configureProtocol(
        era: NegotiatedEra.modern,
        version: '2026-07-28',
      );
      stream.add(
        utf8.encode(
          'data: {"jsonrpc":"2.0","method":"notifications/late-modern"}\n\n',
        ),
      );
      expect((await session.request('tools/call', {})).isSuccess, isTrue);
      expect(
        frames.any((frame) => frame.method == 'notifications/late-modern'),
        isFalse,
      );
      expect(stream.hasListener, isFalse);
      await session.close();
      await subscription.cancel();
      await stream.close();
    },
  );
  test(
    'access revocation rejects a late notification before retention',
    () async {
      var authorized = true;
      final stream = StreamController<Uint8List>();
      final adapter = _Adapter()..getResponse = () async => streamBody(stream);
      final session = await connect(adapter, authorized: () => authorized);
      await ready(session);
      final frames = <RpcFrame>[];
      final subscription = session.frames.listen(frames.add);
      final disconnected = session.status.firstWhere(
        (status) => status is ConnectionDisconnected,
      );
      authorized = false;
      stream.add(
        utf8.encode(
          'data: {"jsonrpc":"2.0","method":"notifications/private","params":{"value":"late-payload"}}\n\n',
        ),
      );
      await disconnected;
      expect(
        frames.any((frame) => frame.rawJson.contains('late-payload')),
        isFalse,
      );
      await session.close();
      await subscription.cancel();
      await stream.close();
    },
  );
}
