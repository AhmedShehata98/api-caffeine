import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_output_diagnostics.dart';

void main() {
  const schema = {
    'type': 'object',
    'required': ['n'],
    'additionalProperties': false,
    'properties': {
      'n': {'type': 'integer'},
    },
  };
  test('valid structured output is checked without coercion', () async {
    expect(
      (await diagnoseMcpOutput(schema, {'n': 3}, present: true)).status,
      McpOutputStatus.valid,
    );
    final invalid = await diagnoseMcpOutput(schema, {'n': '3'}, present: true);
    expect(invalid.status, McpOutputStatus.invalid);
    expect(invalid.fields.keys, contains(r'$.n'));
  });
  test(
    'missing is distinct from null and stringified JSON is not accepted',
    () async {
      expect(
        (await diagnoseMcpOutput(schema, null, present: false)).status,
        McpOutputStatus.missing,
      );
      expect(
        (await diagnoseMcpOutput(schema, null, present: true)).status,
        McpOutputStatus.invalid,
      );
      expect(
        (await diagnoseMcpOutput(schema, '{"n":3}', present: true)).status,
        McpOutputStatus.invalid,
      );
    },
  );
  test(
    'required and unexpected properties produce field diagnostics',
    () async {
      final result = await diagnoseMcpOutput(schema, {
        'other': 1,
      }, present: true);
      expect(result.status, McpOutputStatus.invalid);
      expect(result.fields, isNotEmpty);
    },
  );
  test('unsupported and external schemas are explicitly unchecked', () async {
    expect(
      (await diagnoseMcpOutput(
        {'type': 'object', 'patternProperties': {}},
        {},
        present: true,
      )).status,
      McpOutputStatus.unchecked,
    );
    final external = await diagnoseMcpOutput(
      {r'$ref': 'https://invalid.test/schema'},
      {},
      present: true,
    );
    expect(external.status, McpOutputStatus.unchecked);
    expect(external.message, contains('External'));
  });
  test(
    'local references are validated within the bounded schema subset',
    () async {
      final result = await diagnoseMcpOutput(
        {
          'type': 'object',
          'required': ['n'],
          r'$defs': {
            'count': {'type': 'integer'},
          },
          'properties': {
            'n': {r'$ref': r'#/$defs/count'},
          },
        },
        {'n': 3},
        present: true,
      );
      expect(result.status, McpOutputStatus.valid);
    },
  );
  test(
    'no-schema and intermediate results are not falsely reported as invalid',
    () async {
      expect(
        (await diagnoseMcpOutput(null, null, present: false)).status,
        McpOutputStatus.noSchema,
      );
      expect(
        (await diagnoseMcpOutput(
          schema,
          null,
          present: false,
          complete: false,
        )).status,
        McpOutputStatus.intermediate,
      );
    },
  );
}
