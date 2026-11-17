import 'dart:isolate';

import '../models/mcp_schema_form.dart';
import 'schema_form_builder.dart';

enum McpOutputStatus {
  noSchema,
  valid,
  missing,
  invalid,
  unchecked,
  intermediate,
}

class McpOutputDiagnostics {
  const McpOutputDiagnostics(
    this.status,
    this.message, [
    this.fields = const {},
  ]);
  final McpOutputStatus status;
  final String message;
  final Map<String, String> fields;
}

Future<McpOutputDiagnostics> diagnoseMcpOutput(
  Map<String, dynamic>? schema,
  Object? structured, {
  required bool present,
  bool complete = true,
}) => Isolate.run(() {
  if (schema == null) {
    return const McpOutputDiagnostics(
      McpOutputStatus.noSchema,
      'No output schema declared.',
    );
  }
  if (!complete) {
    return const McpOutputDiagnostics(
      McpOutputStatus.intermediate,
      'Output schema not checked for an intermediate result.',
    );
  }
  if (!present) {
    return const McpOutputDiagnostics(
      McpOutputStatus.missing,
      'Output schema diagnostic: structuredContent is missing.',
    );
  }
  if (structured is! Map || structured.keys.any((key) => key is! String)) {
    return const McpOutputDiagnostics(
      McpOutputStatus.invalid,
      'Output schema diagnostic: structuredContent must be a JSON object.',
    );
  }
  const builder = SchemaFormBuilder();
  final plan = builder.build(schema);
  if (plan is RawJsonOnly) {
    return McpOutputDiagnostics(
      McpOutputStatus.unchecked,
      'Output schema not checked: ${plan.reason}.',
    );
  }
  final checked = builder.arguments(
    plan as FormSpec,
    Map<String, dynamic>.from(structured),
  );
  if (checked.isSuccess) {
    return const McpOutputDiagnostics(
      McpOutputStatus.valid,
      'Output schema: valid within the supported subset.',
    );
  }
  final failure = checked.failureOrNull!;
  return failure is SchemaArgumentFailure
      ? McpOutputDiagnostics(
          McpOutputStatus.invalid,
          'Output schema diagnostic: structuredContent does not match.',
          failure.fields,
        )
      : McpOutputDiagnostics(
          McpOutputStatus.unchecked,
          'Output schema not checked: ${failure.message}',
        );
});
