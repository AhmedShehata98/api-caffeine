import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_diagnostic_body.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';

void main() {
  test('full capture retains more than a monitor preview', () {
    final body = McpHttpDiagnosticBody();
    final text = '${'x' * (300 * 1024)}end';
    body.add(text);
    expect(body.limitBytes, 16 * 1024 * 1024);
    expect(body.text, '$text\n');
    expect(body.truncated, isFalse);
  });
  test('UTF-8 capture limit preserves a stable valid prefix', () {
    final body = McpHttpDiagnosticBody(limitBytes: 4);
    body.add('abc😀tail');
    expect(body.text, 'abc');
    expect(body.truncated, isTrue);
    body.add('x');
    expect(body.text, 'abc');
    expect(utf8.encode(body.text).length, lessThanOrEqualTo(4));
  });
  test('exact capacity remains complete until more data arrives', () {
    final body = McpHttpDiagnosticBody(limitBytes: 4);
    body.add('abc');
    expect(body.truncated, isFalse);
    body.add('next');
    expect(body.truncated, isTrue);
    expect(body.text, 'abc\n');
  });
  test('clear releases bytes and capture state', () {
    final body = McpHttpDiagnosticBody(limitBytes: 4)..add('overflow');
    body.clear();
    expect(body.text, isEmpty);
    expect(body.truncated, isFalse);
    body.add('ok');
    expect(body.text, 'ok\n');
  });
  test(
    'full SSE decoding handles pretty JSON and escaped braces and quotes',
    () async {
      final frames = [
        {
          'jsonrpc': '2.0',
          'method': 'notification',
          'params': {'text': 'brace } quote " slash \\'},
        },
        {
          'jsonrpc': '2.0',
          'id': 1,
          'result': {
            'items': [1, 2],
          },
        },
      ];
      final buffer = McpDiagnosticBuffer(previewBytes: 16);
      buffer.addNetwork(
        NetworkEntry(
          method: 'POST',
          url: 'http://localhost',
          duration: Duration.zero,
          responseHeaders: {
            'Content-Type': ['text/event-stream; charset=utf-8'],
          },
          body: frames
              .map(const JsonEncoder.withIndent('  ').convert)
              .join('\n'),
        ),
      );
      expect(buffer.entries.single.truncated, isTrue);
      expect(buffer.entries.single.fullAvailable, isTrue);
      expect((await buffer.loadFullJson(0)).valueOrNull, frames);
      buffer.dispose();
    },
  );
  test(
    'malformed full SSE frames fail instead of returning a partial parse',
    () async {
      final buffer = McpDiagnosticBuffer();
      buffer.addNetwork(
        const NetworkEntry(
          method: 'POST',
          url: 'http://localhost',
          duration: Duration.zero,
          responseHeaders: {
            'content-type': ['text/event-stream'],
          },
          body: '{"id":1}\n{"incomplete":',
        ),
      );
      expect((await buffer.loadFullJson(0)).isSuccess, isFalse);
      buffer.dispose();
    },
  );
}
