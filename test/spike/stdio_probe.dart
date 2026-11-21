import 'dart:async';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

/// Run directly with `dart test/spike/stdio_probe.dart` (no Flutter hooks).
Future<void> main() async {
  final transport = StdioClientTransport(
    StdioServerParameters(
      command: Platform.resolvedExecutable,
      args: ['test/fixtures/mcp/fixture_server.dart'],
      restartOnUnexpectedExit: false,
    ),
  );
  final responses = <Object, Completer<Map<String, dynamic>>>{};
  transport.onmessage = (message) {
    final json = message.toJson();
    responses.remove(json['id'])?.complete(json);
  };
  transport.onerror = (error) {
    for (final response in responses.values) {
      response.completeError(error);
    }
    responses.clear();
  };
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    responses[id] = response;
    await transport.send(
      JsonRpcRequest(id: id, method: method, params: params),
    );
    final result = await response.future.timeout(const Duration(seconds: 15));
    if (result['id'] != id || result.containsKey('error')) {
      throw StateError('Unexpected response for $method: $result');
    }
    return result;
  }

  try {
    await transport.start();
    await request(101, 'initialize', {
      'protocolVersion': '2025-11-25',
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'api-caffeine-spike', 'version': '1.0.0'},
    });
    await transport.send(
      const JsonRpcNotification(method: 'notifications/initialized'),
    );
    final result = await request(777, 'tools/call', {
      'name': 'echo',
      'arguments': {'text': 'fixture-response'},
    });
    if (result['result']['content'][0]['text'] != 'fixture-response') {
      throw StateError('Echo result mismatch');
    }
    stdout.writeln('PASS: legacy initialization and manual tools/call ID 777');
  } finally {
    await transport.close().timeout(const Duration(seconds: 5));
  }
}
