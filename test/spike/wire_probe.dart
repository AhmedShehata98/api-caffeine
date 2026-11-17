import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:mcp_dart/mcp_dart.dart';

/// Thin stdio boundary feasibility probe, not the production process launcher.
Future<void> main() async {
  final process = await Process.start(Platform.resolvedExecutable, [
    'test/fixtures/mcp/fixture_server.dart',
  ]);
  final pending = <Object, Completer<Map<String, dynamic>>>{};
  final captured = <String>[];
  // The only retained representation is sanitized before insertion.
  const canary = 'wire-canary+credential';
  String sanitize(String text) => text
      .replaceAll(canary, '[REDACTED]')
      .replaceAll(Uri.encodeComponent(canary), '[REDACTED]');
  final stdoutSubscription = process.stdout
      .transform(utf8.decoder)
      .transform(const LineSplitter())
      .listen((line) {
        captured.add(sanitize(line));
        final message = jsonDecode(line) as Map<String, dynamic>;
        pending.remove(message['id'])?.complete(message);
      });
  final stderrSubscription = process.stderr.transform(utf8.decoder).listen((
    text,
  ) {
    captured.add(sanitize(text));
  });
  Future<Map<String, dynamic>> request(
    int id,
    String method,
    Map<String, dynamic> params,
  ) async {
    final response = Completer<Map<String, dynamic>>();
    pending[id] = response;
    final wire = jsonEncode({
      'jsonrpc': '2.0',
      'id': id,
      'method': method,
      'params': {
        ...params,
        '_meta': {
          McpMetaKey.protocolVersion: '2026-07-28',
          McpMetaKey.clientCapabilities: <String, dynamic>{},
          McpMetaKey.clientInfo: {'name': 'Test Point', 'version': '1.0.0'},
        },
      },
    });
    captured.add(sanitize(wire));
    process.stdin.writeln(wire);
    await process.stdin.flush();
    return response.future.timeout(const Duration(seconds: 10));
  }

  try {
    final discovery = await request(1, 'server/discover', {});
    if (discovery.containsKey('error')) throw StateError('Discovery failed');
    final result = await request(2, 'tools/call', {
      'name': 'echo',
      'arguments': {'text': canary},
    });
    if (result['result']['content'][0]['text'] != canary) {
      throw StateError('Operation result was changed by diagnostic redaction');
    }
    final diagnostics = captured.join('\n');
    if (diagnostics.contains(canary) || !diagnostics.contains('[REDACTED]')) {
      throw StateError('Canary leaked into retained diagnostics');
    }
    // Demonstrate why SDK message callbacks cannot supply exact wire capture.
    const original = '{ "jsonrpc":"2.0", "id":9, "result":{}, "x-extra":1 }';
    final reconstructed = jsonEncode(
      JsonRpcMessage.fromJson(jsonDecode(original) as Map<String, dynamic>)
          .toJson(),
    );
    if (reconstructed == original || reconstructed.contains('x-extra')) {
      throw StateError('Revisit SDK wire-fidelity assessment');
    }
    stdout.writeln('PASS: raw stdio modern discovery and manual tool call');
    stdout.writeln(
      'PASS: canary redacted before retention; result remains intact',
    );
    stdout.writeln(
      'CONFIRMED: parsed SDK callbacks lose wire formatting/extensions',
    );
  } finally {
    await process.stdin.close();
    try {
      await process.exitCode.timeout(const Duration(seconds: 5));
    } on TimeoutException {
      process.kill();
      await process.exitCode.timeout(const Duration(seconds: 5));
    }
    await stdoutSubscription.cancel();
    await stderrSubscription.cancel();
  }
}
