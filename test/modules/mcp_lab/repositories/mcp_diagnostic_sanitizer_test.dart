import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_diagnostic_sanitizer.dart';

void main() {
  test(
    'large base64 and plain tokens do not backtrack through header names',
    () {
      final sanitizer = McpDiagnosticSanitizer(secretValues: ['canary']);
      final value = 'A' * (1024 * 1024);
      expect(sanitizer.text(value), value);
      expect(sanitizer.text('$value: ordinary'), '$value: ordinary');
      final wire = jsonEncode({'blob': value, 'echo': 'canary'});
      final clean = jsonDecode(sanitizer.frame(wire).text) as Map;
      expect(clean['blob'], value);
      expect(clean['echo'], '[REDACTED]');
      sanitizer.dispose();
    },
  );

  test('long custom credential header names still redact their values', () {
    final sanitizer = McpDiagnosticSanitizer();
    final prefix = 'a' * (128 * 1024);
    expect(
      sanitizer.text('$prefix-token: private\nOK: safe'),
      '$prefix-token: [REDACTED]\nOK: safe',
    );
    expect(
      sanitizer.text('{"$prefix-secret":"private","ok":true}'),
      '{"$prefix-secret":"[REDACTED]","ok":true}',
    );
    sanitizer.dispose();
  });

  test(
    'large quoted credentials and escapes redact without recursive regex',
    () {
      final sanitizer = McpDiagnosticSanitizer();
      final value = '${'x' * (1024 * 1024)}"escaped\\end';
      expect(
        sanitizer.text('{"X-Token":${jsonEncode(value)},"ok":true}'),
        '{"X-Token":"[REDACTED]","ok":true}',
      );
      expect(
        sanitizer.text('{"Authorization":"unterminated\\"private'),
        '{"Authorization":"[REDACTED]"',
      );
      sanitizer.dispose();
    },
  );
}
