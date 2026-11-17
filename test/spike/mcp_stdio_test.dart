import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';
import 'package:mcp_dart/mcp_dart.dart';

void main() {
  test(
    'SDK stdio preserves manual IDs and exposes both frame directions',
    () async {
      final flutterLibrary = await Isolate.resolvePackageUri(
        Uri.parse('package:flutter/widgets.dart'),
      );
      final flutterRoot = File.fromUri(flutterLibrary!)
          .parent
          .parent
          .parent
          .parent;
      final dart =
          '${flutterRoot.path}/bin/cache/dart-sdk/bin/'
          '${Platform.isWindows ? 'dart.exe' : 'dart'}';
      final transport = StdioClientTransport(
        StdioServerParameters(
          command: Platform.environment['DART_EXECUTABLE'] ?? dart,
          args: ['test/fixtures/mcp/fixture_server.dart'],
          restartOnUnexpectedExit: false,
        ),
      );
      addTearDown(transport.close);
      final sent = <Map<String, dynamic>>[];
      final received = <Map<String, dynamic>>[];
      final pending = <Object, Completer<Map<String, dynamic>>>{};
      transport.onmessage = (message) {
        final json = message.toJson();
        received.add(json);
        pending.remove(json['id'])?.complete(json);
      };
      transport.onerror = (error) {
        for (final waiter in pending.values) {
          waiter.completeError(error);
        }
        pending.clear();
      };
      Future<Map<String, dynamic>> request(
        int id,
        String method,
        Map<String, dynamic> params,
      ) async {
        final waiter = Completer<Map<String, dynamic>>();
        pending[id] = waiter;
        final message = JsonRpcRequest(id: id, method: method, params: params);
        sent.add(message.toJson());
        await transport.send(message);
        return waiter.future.timeout(const Duration(seconds: 15));
      }

      await transport.start();
      final initialized = await request(101, 'initialize', {
        'protocolVersion': '2025-11-25',
        'capabilities': <String, dynamic>{},
        'clientInfo': {'name': 'test-point-spike', 'version': '1.0.0'},
      });
      expect(initialized['error'], isNull);
      const notification = JsonRpcNotification(
        method: 'notifications/initialized',
      );
      sent.add(notification.toJson());
      await transport.send(notification);
      final result = await request(777, 'tools/call', {
        'name': 'echo',
        'arguments': {'text': 'fixture-response'},
      });
      expect(result['id'], 777);
      expect(result['result']['content'][0]['text'], 'fixture-response');
      expect(sent.map((frame) => frame['method']), [
        'initialize',
        'notifications/initialized',
        'tools/call',
      ]);
      expect(received.map((frame) => frame['id']), containsAll([101, 777]));
    },
  );
}
