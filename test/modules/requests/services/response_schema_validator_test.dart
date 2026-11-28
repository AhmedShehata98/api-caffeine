import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';
import 'package:api_caffeine/modules/requests/services/response_schema_validator.dart';

void main() {
  final validator = ResponseSchemaValidator();
  SchemaTestResult check(
    String schema,
    String body, {
    int status = 200,
    bool validUtf8 = true,
  }) => validator.validate(
    schemaSource: schema,
    body: body,
    bodyBytes: body.length,
    validUtf8: validUtf8,
    method: 'GET',
    statusCode: status,
  );

  test('reports missing and mismatched properties with typed paths', () {
    final result = check(
      '{"properties":{"user":{"properties":{"id":{"type":"integer"}},"required":["name"]}}}',
      '{"user":{"id":"42"}}',
    );
    expect(result.status, SchemaTestStatus.failed);
    expect(
      result.issues.map((i) => i.path),
      containsAll([
        ['user', 'name'],
        ['user', 'id'],
      ]),
    );
    expect(result.issues.first.anchor, ['user']);
  });

  test(
    'preflights unused unsupported references and handles local references',
    () {
      expect(
        check(
          r'{"properties":{"absent":{"$ref":"https://example.com"}}}',
          '{}',
        ).status,
        SchemaTestStatus.invalidSchema,
      );
      expect(
        check(
          r'{"$defs":{"id":{"type":"integer"}},"$ref":"#/$defs/id"}',
          '2',
        ).status,
        SchemaTestStatus.passed,
      );
      expect(
        check(r'{"$defs":{"loop":{"$ref":"#/$defs/loop"}}}', '{}').status,
        SchemaTestStatus.invalidSchema,
      );
    },
  );

  test('handles empty bodies, malformed inputs, and error responses', () {
    expect(check('true', '', status: 205).status, SchemaTestStatus.skipped);
    expect(check('true', '').status, SchemaTestStatus.failed);
    expect(check('true', '{').status, SchemaTestStatus.invalidResponse);
    expect(
      check('true', 'x', validUtf8: false).status,
      SchemaTestStatus.invalidResponse,
    );
    expect(
      check('{"type":"object"}', '{}', status: 500).status,
      SchemaTestStatus.passed,
    );
  });

  test('caps dense diagnostics while retaining the failed verdict', () {
    final body = '[${List.filled(200, '"wrong"').join(',')}]';
    final result = check('{"items":{"type":"integer"}}', body);
    expect(result.status, SchemaTestStatus.failed);
    expect(result.issues, hasLength(50));
    expect(result.incomplete, isTrue);
  });

  test('resolves escaped names and rejects non-schema pointer targets', () {
    final escaped = check(
      r'{"$defs":{"a/b~c":{"type":"integer"}},"$ref":"#/$defs/a~1b~0c"}',
      '1',
    );
    expect(escaped.status, SchemaTestStatus.passed);
    final invalid = check(
      r'{"$defs":{"a":{"properties":{"type":{"type":"integer"}}}},"$ref":"#/$defs/a/properties"}',
      '{}',
    );
    expect(invalid.status, SchemaTestStatus.invalidSchema);
  });
}
