import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_resource_preview.dart';

void main() {
  test(
    'supported image MIME retains preview bytes and other binaries do not',
    () async {
      final image = await prepareMcpResourcePreview(
        const ResourceContents(
          uri: 'fixture://image',
          mimeType: 'image/png',
          blob: 'AID/AA==',
        ),
      );
      expect(image.imageBytes, [0, 128, 255, 0]);
      final other = await prepareMcpResourcePreview(
        const ResourceContents(
          uri: 'fixture://file',
          mimeType: 'application/octet-stream',
          blob: 'AID/AA==',
        ),
      );
      expect(other.imageBytes, isNull);
      expect(other.byteLength, 4);
    },
  );
  test(
    'large images retain size but require save instead of inline preview',
    () async {
      final image = await prepareMcpResourcePreview(
        ResourceContents(
          uri: 'fixture://large',
          mimeType: 'image/png',
          blob: base64Encode(List<int>.filled(8 * 1024 * 1024 + 1, 0)),
        ),
      );
      expect(image.byteLength, 8 * 1024 * 1024 + 1);
      expect(image.imageBytes, isNull);
      expect(image.notice, contains('Save the resource'));
    },
  );
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
