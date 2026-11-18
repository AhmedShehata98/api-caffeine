import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

/// Scripted HTTP peer deliberately controls status codes and session expiry.
Future<void> main() async {
  final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  final methods = <String>[];
  final headers = <Map<String, String>>[];
  var expired = false;
  var deletes = 0;
  var modern = false;
  final subscription = server.listen((request) async {
    request.response.headers.contentType = ContentType.json;
    if (request.method == 'GET' || request.method == 'DELETE') {
      if (request.method == 'DELETE') deletes++;
      request.response.statusCode = HttpStatus.methodNotAllowed;
      await request.response.close();
      return;
    }
    final body = jsonDecode(
      await utf8.decoder.bind(request).join(),
    ) as Map<String, dynamic>;
    methods.add(body['method'] as String);
    headers.add({
      'session': request.headers.value('mcp-session-id') ?? '',
      'version': request.headers.value('mcp-protocol-version') ?? '',
    });
    if (expired) {
      request.response.statusCode = HttpStatus.notFound;
    } else if (body['method'] == 'server/discover') {
      request.response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': {
            'capabilities': {},
            'serverInfo': {'name': 'modern-peer', 'version': '1.0.0'},
          },
        }),
      );
    } else if (body['method'] == 'initialize') {
      request.response.headers.set('mcp-session-id', 'fixture-session');
      request.response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': {
            'protocolVersion': '2025-11-25',
            'capabilities': {},
            'serverInfo': {'name': 'scripted-http', 'version': '1.0.0'},
          },
        }),
      );
    } else if (body.containsKey('id')) {
      request.response.write(
        jsonEncode({
          'jsonrpc': '2.0',
          'id': body['id'],
          'result': {
            if (modern) 'resultType': 'input_required',
            'content': [
              {'type': 'text', 'text': 'echo'},
            ],
          },
        }),
      );
    } else {
      request.response.statusCode = HttpStatus.accepted;
    }
    await request.response.close();
  });
  var transport = StreamableHttpClientTransport(
    Uri.parse('http://127.0.0.1:${server.port}/mcp'),
  );
  final responses = <Object, Completer<Map<String, dynamic>>>{};
  transport.onmessage = (message) {
    final json = message.toJson();
    responses.remove(json['id'])?.complete(json);
  };
  // send() reports HTTP errors directly; retain no raw error diagnostics.
  transport.onerror = (_) {};
  Future<void> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    responses[id] = response;
    await transport.send(
      JsonRpcRequest(id: id, method: method, params: params),
    );
    final json = await response.future.timeout(const Duration(seconds: 5));
    if (json['id'] != id || json.containsKey('error')) {
      throw StateError('Unexpected $method response');
    }
  }

  void check(bool condition, String description) {
    if (!condition) throw StateError(description);
  }

  try {
    await transport.start();
    await request(101, 'initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': {},
      'clientInfo': {'name': 'test-point-spike', 'version': '1.0.0'},
    });
    // The raw transport does not negotiate; its caller validates and sets this.
    transport.protocolVersion = '2025-11-25';
    await transport.send(
      const JsonRpcNotification(method: 'notifications/initialized'),
    );
    await request(777, 'tools/call', {'name': 'echo', 'arguments': {}});
    check(
      headers.last['session'] == 'fixture-session',
      'Missing session header',
    );
    check(headers.last['version'] == '2025-11-25', 'Missing version header');
    await transport.terminateSession().timeout(const Duration(seconds: 5));
    check(deletes == 1, 'DELETE 405 cleanup not attempted');
    stdout.writeln('PASS: HTTP manual ID, session/version headers, DELETE 405');

    await request(102, 'initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': {},
      'clientInfo': {'name': 'test-point-spike', 'version': '1.0.0'},
    });
    expired = true;
    final before = methods.length;
    Object? failure;
    try {
      await request(778, 'tools/call', {'name': 'echo', 'arguments': {}});
    } on Object catch (error) {
      failure = error;
    }
    check(failure != null, 'Expired session did not fail');
    check(methods.length == before + 1, 'Expired call replayed automatically');
    check(transport.sessionId == null, 'Expired session ID retained');
    stdout.writeln('PASS: HTTP 404 invalidates session without replay');
    expired = false;
    modern = true;
    await transport.close();
    transport = StreamableHttpClientTransport(
      Uri.parse('http://127.0.0.1:${server.port}/mcp'),
    );
    transport.onmessage = (message) {
      final json = message.toJson();
      responses.remove(json['id'])?.complete(json);
    };
    transport.onerror = (_) {};
    await transport.start();
    transport.protocolVersion = '2026-07-28';
    const meta = {
      McpMetaKey.protocolVersion: '2026-07-28',
      McpMetaKey.clientCapabilities: <String, dynamic>{},
      McpMetaKey.clientInfo: {'name': 'API Caffeine', 'version': '1.0.0'},
    };
    final discover = Completer<Map<String, dynamic>>();
    responses[201] = discover;
    await transport.send(
      const JsonRpcRequest(id: 201, method: 'server/discover', meta: meta),
    );
    check(
      !(await discover.future.timeout(const Duration(seconds: 5)))
          .containsKey('error'),
      'Modern discovery failed',
    );
    final call = Completer<Map<String, dynamic>>();
    responses[202] = call;
    final callCount = methods.length;
    await transport.send(
      const JsonRpcRequest(
        id: 202,
        method: 'tools/call',
        params: {'name': 'echo', 'arguments': <String, dynamic>{}},
        meta: meta,
      ),
    );
    final intermediate = await call.future.timeout(const Duration(seconds: 5));
    check(
      intermediate['result']['resultType'] == 'input_required',
      'Intermediate result was consumed',
    );
    check(
      methods.length == callCount + 1,
      'Transport sent an unsolicited MRTR round',
    );
    stdout.writeln(
      'PASS: modern HTTP discovery; input_required delivered to caller',
    );
  } finally {
    await transport.close().timeout(const Duration(seconds: 5));
    await server.close(force: true);
    await subscription.cancel();
  }
}
