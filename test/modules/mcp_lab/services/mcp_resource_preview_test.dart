import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/services/mcp_resource_preview.dart';

void main() {
  test(
    'JSON MIME content is formatted without changing the original',
    () async {
      const content = ResourceContents(
        uri: 'data://json',
        mimeType: 'application/problem+json; charset=utf-8',
        text: '{"ok":true}',
      );
      final preview = await prepareMcpResourcePreview(content);
      expect(preview.json, isTrue);
      expect(preview.text, '{\n  "ok": true\n}');
      expect(content.text, '{"ok":true}');
    },
  );
  test('invalid JSON and plain text are retained verbatim', () async {
    final invalid = await prepareMcpResourcePreview(
      const ResourceContents(
        uri: 'data://bad',
        mimeType: 'application/json',
        text: '{invalid',
      ),
    );
    expect(invalid.text, '{invalid');
    expect(invalid.notice, contains('Invalid JSON'));
    final plain = await prepareMcpResourcePreview(
      const ResourceContents(
        uri: 'data://plain',
        mimeType: 'text/plain',
        text: '{"ok":true}',
      ),
    );
    expect(plain.text, '{"ok":true}');
    expect(plain.json, isFalse);
  });
  test(
    'binary metadata uses decoded size and invalid base64 is explicit',
    () async {
      final binary = await prepareMcpResourcePreview(
        ResourceContents(
          uri: 'data://bytes',
          blob: base64Encode([0, 128, 255, 0]),
        ),
      );
      expect(binary.byteLength, 4);
      expect(binary.text, isNull);
      final invalid = await prepareMcpResourcePreview(
        const ResourceContents(uri: 'data://bad', blob: '***'),
      );
      expect(invalid.byteLength, isNull);
      expect(invalid.notice, contains('invalid base64'));
    },
  );
}
