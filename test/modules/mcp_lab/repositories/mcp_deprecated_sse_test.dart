import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';

class _Adapter implements HttpClientAdapter {
  final stream = StreamController<Uint8List>();
  final requests = <RequestOptions>[];
  final messages = <Map>[];
  final replyArrived = Completer<Map>();
  String endpoint = '/messages?sessionId=endpoint-private';
  String firstType = 'endpoint';
  bool announce = true;
  bool autoReply = true;
  Completer<ResponseBody>? heldAck;
  void event(String type, String data) =>
      stream.add(utf8.encode('event: $type\ndata: $data\n\n'));
  void message(Map value) => event('message', jsonEncode(value));
  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requests.add(options);
    if (options.method == 'GET') {
      if (announce) event(firstType, endpoint);
      return ResponseBody(
        stream.stream,
        200,
        headers: {
          'content-type': ['text/event-stream'],
        },
      );
    }
    final bytes = BytesBuilder();
    if (requestStream != null) {
      await for (final chunk in requestStream) {
        bytes.add(chunk);
      }
    }
    final request = jsonDecode(utf8.decode(bytes.takeBytes())) as Map;
    messages.add(request);
    if (request['error'] != null) {
      if (!replyArrived.isCompleted) replyArrived.complete(request);
    } else if (request['id'] != null &&
        (request['method'] == 'initialize' || autoReply)) {
      message({
        'jsonrpc': '2.0',
        'id': request['id'],
        'result': request['method'] == 'initialize'
            ? {
                'protocolVersion': '2024-11-05',
                'capabilities': {},
                'serverInfo': {'name': 'old-server', 'version': '1'},
              }
            : {
                'id': request['id'],
                'text': 'header-canary',
                'endpointEcho': 'endpoint-private',
              },
      });
    }
    if (request['method'] == 'tools/call' && heldAck != null) {
      return heldAck!.future;
    }
    return ResponseBody.fromString('', 202);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Future<Result<McpSession>> connect(
    _Adapter adapter, {
    Duration timeout = const Duration(seconds: 1),
    bool Function()? authorized,
  }) =>
      McpHttpConnectionRepository(
        isAuthorized: (_, _) => authorized?.call() ?? true,
        clientVersion: 'test',
        createClient: (_, _) => Dio()..httpClientAdapter = adapter,
      ).connect(
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
              name: 'Old',
              transport: McpTransport.sse,
              url: 'https://example.test/sse',
              headers: {'authorization': 'Bearer header-canary'},
              secretKeys: ['header.authorization'],
            ),
            secretStates: {'header.authorization': SecretValueState.present},
          ),
          timeout: timeout,
        ),
      );
  Future<McpSession> ready(
    _Adapter adapter, {
    Duration timeout = const Duration(seconds: 1),
    bool Function()? authorized,
  }) async {
    final opened = await connect(
      adapter,
      timeout: timeout,
      authorized: authorized,
    );
    expect(opened.isSuccess, isTrue);
    final session = opened.valueOrNull!;
    expect(
      (await const McpNegotiationService(clientVersion: 'test')
              .negotiate(session))
          .isSuccess,
      isTrue,
    );
    return session;
  }

  test('deprecated SSE negotiates, posts to its endpoint and sanitizes credentials', () async {
    final adapter = _Adapter();
    final session = await ready(adapter);
    final captures = <NetworkEntry>[];
    final captured = Completer<void>();
    final subscription = session.network.listen((entry) {
      captures.add(entry);
      if (entry.requestBody?.contains('tools/call') == true &&
          !captured.isCompleted) {
        captured.complete();
      }
    });
    final result = await session.request('tools/call', {'name': 'echo'});
    expect(result.valueOrNull!['text'], 'header-canary');
    expect(result.valueOrNull!['endpointEcho'], 'endpoint-private');
    await captured.future;
    expect(
      adapter.requests.where((request) => request.method == 'GET'),
      hasLength(1),
    );
    expect(
      adapter.requests
          .where((request) => request.method == 'POST')
          .every(
            (request) =>
                request.uri.path == '/messages' &&
                request.uri.queryParameters['sessionId'] == 'endpoint-private',
          ),
      isTrue,
    );
    final diagnostic = jsonEncode(
      captures.map((entry) => entry.toJson()).toList(),
    );
    expect(diagnostic, isNot(contains('header-canary')));
    expect(diagnostic, isNot(contains('endpoint-private')));
    expect(captures.last.url, contains('/messages?sessionId=[REDACTED]'));
    expect((await session.close()).isSuccess, isTrue);
    expect(
      adapter.requests.any((request) => request.method == 'DELETE'),
      isFalse,
    );
    expect(adapter.stream.hasListener, isFalse);
    await subscription.cancel();
    await adapter.stream.close();
  });
  for (final endpoint in [
    'https://evil.test/post',
    '//evil.test/post',
    'http://example.test/post',
    'https://example.test:444/post',
    'https://@example.test/post',
    '/post#fragment',
    '/post\\bad',
    '/post bad',
    '',
  ]) {
    test('untrusted endpoint is rejected before POST ($endpoint)', () async {
      final adapter = _Adapter()..endpoint = endpoint;
      expect((await connect(adapter)).isSuccess, isFalse);
      expect(
        adapter.requests.every((request) => request.method == 'GET'),
        isTrue,
      );
      expect(adapter.stream.hasListener, isFalse);
      await adapter.stream.close();
    });
  }
  test(
    'endpoint announcement must arrive before a finite connect deadline',
    () async {
      final adapter = _Adapter()..announce = false;
      final watch = Stopwatch()..start();
      expect(
        (await connect(
          adapter,
          timeout: const Duration(milliseconds: 40),
        )).isSuccess,
        isFalse,
      );
      expect(watch.elapsedMilliseconds, lessThan(1000));
      expect(adapter.stream.hasListener, isFalse);
      await adapter.stream.close();
    },
  );
  test('the first data event must announce an endpoint', () async {
    final adapter = _Adapter()..firstType = 'message';
    expect((await connect(adapter)).isSuccess, isFalse);
    expect(adapter.messages, isEmpty);
    await adapter.stream.close();
  });
  test('an endpoint cannot change during a live session', () async {
    final adapter = _Adapter();
    final session = await ready(adapter);
    final disconnected = session.status.firstWhere(
      (status) => status is ConnectionDisconnected,
    );
    adapter.event('endpoint', '/other');
    await disconnected;
    expect((await session.request('tools/call', {})).isSuccess, isFalse);
    expect(
      adapter.requests.any((request) => request.uri.path == '/other'),
      isFalse,
    );
    await session.close();
    await adapter.stream.close();
  });
  test(
    'integer and string IDs remain distinct across concurrent calls',
    () async {
      final adapter = _Adapter();
      final session = await ready(adapter);
      final results = await Future.wait([
        session.request('tools/call', {'name': 'first'}, id: 7),
        session.request('tools/call', {'name': 'second'}, id: '7'),
      ]);
      expect(results[0].valueOrNull!['id'], 7);
      expect(results[1].valueOrNull!['id'], '7');
      await session.close();
      await adapter.stream.close();
    },
  );
  test(
    'an SSE result cannot hide a later rejected POST acknowledgement',
    () async {
      final adapter = _Adapter();
      final session = await ready(adapter);
      adapter.heldAck = Completer<ResponseBody>();
      final response = session.frames.firstWhere(
        (frame) => frame.kind == RpcFrameKind.response && frame.id == 2,
      );
      var finished = false;
      final pending = session.request('tools/call', {}).then((result) {
        finished = true;
        return result;
      });
      await response;
      expect(finished, isFalse);
      adapter.heldAck!.complete(ResponseBody.fromString('', 500));
      expect((await pending).isSuccess, isFalse);
      await session.close();
      await adapter.stream.close();
    },
  );
  test('a timed out call does not close the shared event stream', () async {
    final adapter = _Adapter();
    final session = await ready(adapter);
    adapter.autoReply = false;
    expect(
      (await session.request(
        'tools/call',
        {},
        timeout: const Duration(milliseconds: 40),
      )).isSuccess,
      isFalse,
    );
    expect(adapter.stream.hasListener, isTrue);
    adapter.autoReply = true;
    expect((await session.request('tools/call', {})).isSuccess, isTrue);
    await session.close();
    await adapter.stream.close();
  });
  test(
    'stream EOF fails pending calls without reconnecting or replaying',
    () async {
      final adapter = _Adapter();
      final session = await ready(adapter);
      adapter.autoReply = false;
      final posted = session.frames.firstWhere(
        (frame) => frame.method == 'tools/call',
      );
      final pending = session.request('tools/call', {});
      await posted;
      await adapter.stream.close();
      expect((await pending).isSuccess, isFalse);
      expect((await session.request('tools/call', {})).isSuccess, isFalse);
      expect(
        adapter.requests.where((request) => request.method == 'GET'),
        hasLength(1),
      );
      await session.close();
    },
  );
  test(
    'unsupported server requests receive a method-not-found POST reply',
    () async {
      final adapter = _Adapter();
      final session = await ready(adapter);
      adapter.message({
        'jsonrpc': '2.0',
        'id': 'ask',
        'method': 'sampling/createMessage',
        'params': {},
      });
      expect((await adapter.replyArrived.future)['error']['code'], -32601);
      await session.close();
      await adapter.stream.close();
    },
  );
  test(
    'modern discovery is refused without sending it to an old endpoint',
    () async {
      final adapter = _Adapter();
      final opened = await connect(adapter);
      final session = opened.valueOrNull!;
      expect(
        (await const McpNegotiationService(
          clientVersion: 'test',
        ).negotiate(session, era: McpProtocolEra.modern)).isSuccess,
        isFalse,
      );
      expect(adapter.messages, isEmpty);
      await session.close();
      await adapter.stream.close();
    },
  );
  test('revoked access rejects late messages before retention', () async {
    var authorized = true;
    final adapter = _Adapter();
    final session = await ready(adapter, authorized: () => authorized);
    final frames = <RpcFrame>[];
    final subscription = session.frames.listen(frames.add);
    final disconnected = session.status.firstWhere(
      (status) => status is ConnectionDisconnected,
    );
    authorized = false;
    adapter.message({
      'jsonrpc': '2.0',
      'method': 'notifications/private',
      'params': {'data': 'late-canary'},
    });
    await disconnected;
    expect(
      frames.any((frame) => frame.rawJson.contains('late-canary')),
      isFalse,
    );
    await session.close();
    await subscription.cancel();
    await adapter.stream.close();
  });
}
