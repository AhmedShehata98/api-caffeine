/// The result of checking one response against its captured schema.
enum SchemaTestStatus {
  checking,
  passed,
  failed,
  skipped,
  invalidSchema,
  invalidResponse,
  incomplete,
}

class SchemaIssue {
  const SchemaIssue({
    required this.path,
    required this.anchor,
    required this.condition,
  });

  /// Object keys are strings and array indices are integers.
  final List<Object> path;
  final List<Object> anchor;
  final String condition;
}

class SchemaTestResult {
  const SchemaTestResult({
    required this.status,
    required this.schemaSource,
    this.issues = const [],
    this.incomplete = false,
  });

  final SchemaTestStatus status;
  final String schemaSource;
  final List<SchemaIssue> issues;
  final bool incomplete;
}
