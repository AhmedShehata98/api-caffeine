import 'dart:convert';

import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';

/// Evaluates the supported JSON Schema subset with bounded traversal.
class ResponseSchemaValidator {
  static const maxSchemaBytes = 64 * 1024;
  static const maxBodyBytes = 1024 * 1024;
  static const maxDepth = 64;
  static const maxSteps = 100000;
  static const maxIssues = 50;
  static const maxPathUnits = 64 * 1024;

  SchemaTestResult validate({
    required String schemaSource,
    required String body,
    required int bodyBytes,
    required bool validUtf8,
    required String method,
    required int statusCode,
    void Function(SchemaIssue issue)? onMismatch,
  }) {
    SchemaTestResult result(
      SchemaTestStatus status, {
      List<SchemaIssue> issues = const [],
      bool incomplete = false,
    }) => SchemaTestResult(
      status: status,
      schemaSource: schemaSource,
      issues: issues,
      incomplete: incomplete,
    );
    if (utf8.encode(schemaSource).length > maxSchemaBytes ||
        !_withinDepth(schemaSource)) {
      return result(SchemaTestStatus.incomplete);
    }
    try {
      final schema = jsonDecode(schemaSource);
      final check = _Evaluation(schema, onMismatch);
      check.preflight(schema, <Object>{}, 0, true);
      if (bodyBytes == 0 &&
          (method == 'HEAD' ||
              statusCode == 204 ||
              statusCode == 205 ||
              statusCode == 304)) {
        return result(SchemaTestStatus.skipped);
      }
      if (bodyBytes == 0) {
        return result(
          SchemaTestStatus.failed,
          issues: [
            const SchemaIssue(
              path: [],
              anchor: [],
              condition: 'Expected JSON body',
            ),
          ],
        );
      }
      if (bodyBytes > maxBodyBytes || !_withinDepth(body)) {
        return result(SchemaTestStatus.incomplete);
      }
      if (!validUtf8) return result(SchemaTestStatus.invalidResponse);
      final Object? instance;
      try {
        instance = jsonDecode(body);
      } on FormatException {
        return result(SchemaTestStatus.invalidResponse);
      }
      try {
        check.evaluate(schema, instance, [], 0);
      } on _Limit {
        return result(
          check.mismatch
              ? SchemaTestStatus.failed
              : SchemaTestStatus.incomplete,
          issues: check.issues,
          incomplete: true,
        );
      }
      return result(
        check.mismatch ? SchemaTestStatus.failed : SchemaTestStatus.passed,
        issues: check.issues,
        incomplete: check.truncated,
      );
    } on _InvalidSchema {
      return result(SchemaTestStatus.invalidSchema);
    } on FormatException {
      return result(SchemaTestStatus.invalidSchema);
    } on _Limit {
      return result(SchemaTestStatus.incomplete);
    }
  }

  // Check nesting before jsonDecode so its recursive parser stays bounded.
  bool _withinDepth(String source) {
    var depth = 0;
    var quoted = false;
    var escaped = false;
    for (final c in source.codeUnits) {
      if (quoted) {
        if (escaped) {
          escaped = false;
        } else if (c == 92) {
          escaped = true;
        } else if (c == 34) {
          quoted = false;
        }
      } else if (c == 34) {
        quoted = true;
      } else if (c == 91 || c == 123) {
        if (++depth > maxDepth) return false;
      } else if (c == 93 || c == 125) {
        depth--;
      }
    }
    return true;
  }
}

class _InvalidSchema implements Exception {}

class _Limit implements Exception {}

class _Evaluation {
  _Evaluation(this.root, this.onMismatch);
  final Object? root;
  final void Function(SchemaIssue issue)? onMismatch;
  final issues = <SchemaIssue>[];
  int steps = 0;
  int pathUnits = 0;
  bool mismatch = false;
  bool truncated = false;

  void tick(int depth) {
    if (++steps > ResponseSchemaValidator.maxSteps ||
        depth > ResponseSchemaValidator.maxDepth) {
      throw _Limit();
    }
  }

  Object? resolve(String pointer) {
    if (!pointer.startsWith('#/\$defs/')) throw _InvalidSchema();
    Object? node = root;
    final segments = pointer.substring(2).split('/').map((raw) {
      if (RegExp(r'~(?![01])').hasMatch(raw)) throw _InvalidSchema();
      return raw.replaceAll('~1', '/').replaceAll('~0', '~');
    }).toList();
    for (var i = 0; i < segments.length; i++) {
      final key = segments[i];
      if (node is! Map<String, dynamic> ||
          !node.containsKey(key) ||
          !{
            '\$defs',
            'properties',
            'items',
            'additionalProperties',
          }.contains(key)) {
        throw _InvalidSchema();
      }
      node = node[key];
      if (key == '\$defs' || key == 'properties') {
        if (++i >= segments.length ||
            node is! Map<String, dynamic> ||
            !node.containsKey(segments[i])) {
          throw _InvalidSchema();
        }
        node = node[segments[i]];
      }
    }
    if (node is! bool && node is! Map<String, dynamic>) throw _InvalidSchema();
    return node;
  }

  void preflight(Object? schema, Set<Object> stack, int depth, bool isRoot) {
    tick(depth);
    if (schema is bool) return;
    if (schema is! Map<String, dynamic> || !stack.add(schema)) {
      throw _InvalidSchema();
    }
    const allowed = {
      '\$schema',
      '\$defs',
      '\$ref',
      'type',
      'properties',
      'required',
      'items',
      'additionalProperties',
    };
    for (final key in schema.keys) {
      if (!allowed.contains(key) || (key == '\$schema' && !isRoot)) {
        throw _InvalidSchema();
      }
    }
    if (schema.containsKey('\$schema') &&
        schema['\$schema'] != 'https://json-schema.org/draft/2020-12/schema') {
      throw _InvalidSchema();
    }
    if (schema.containsKey('type')) {
      final value = schema['type'];
      const types = {
        'null',
        'boolean',
        'object',
        'array',
        'number',
        'integer',
        'string',
      };
      final values = value is List ? value : [value];
      if (values.isEmpty ||
          values.any((v) => v is! String || !types.contains(v)) ||
          values.toSet().length != values.length) {
        throw _InvalidSchema();
      }
    }
    if (schema.containsKey('required')) {
      final value = schema['required'];
      if (value is! List ||
          value.any((v) => v is! String) ||
          value.toSet().length != value.length) {
        throw _InvalidSchema();
      }
    }
    for (final key in ['properties', '\$defs']) {
      if (schema.containsKey(key)) {
        final value = schema[key];
        if (value is! Map<String, dynamic>) throw _InvalidSchema();
        for (final child in value.values) {
          preflight(child, stack, depth + 1, false);
        }
      }
    }
    for (final key in ['items', 'additionalProperties']) {
      if (schema.containsKey(key)) {
        preflight(schema[key], stack, depth + 1, false);
      }
    }
    if (schema.containsKey('\$ref')) {
      final ref = schema['\$ref'];
      if (ref is! String) throw _InvalidSchema();
      preflight(resolve(ref), stack, depth + 1, false);
    }
    stack.remove(schema);
  }

  void issue(List<Object> path, List<Object> anchor, String condition) {
    mismatch = true;
    final units =
        path.fold<int>(0, (sum, segment) => sum + segment.toString().length) +
        anchor.fold<int>(0, (sum, segment) => sum + segment.toString().length);
    if (issues.length >= ResponseSchemaValidator.maxIssues ||
        pathUnits + units > ResponseSchemaValidator.maxPathUnits) {
      truncated = true;
      return;
    }
    pathUnits += units;
    final diagnostic = SchemaIssue(
      path: List.unmodifiable(path),
      anchor: List.unmodifiable(anchor),
      condition: condition,
    );
    issues.add(diagnostic);
    if (issues.length == 1) onMismatch?.call(diagnostic);
  }

  bool matches(String type, Object? value) => switch (type) {
    'null' => value == null,
    'boolean' => value is bool,
    'object' => value is Map,
    'array' => value is List,
    'number' => value is num,
    'integer' =>
      value is int ||
          (value is double &&
              value.isFinite &&
              value == value.truncateToDouble()),
    'string' => value is String,
    _ => false,
  };

  void evaluate(Object? schema, Object? value, List<Object> path, int depth) {
    tick(depth);
    if (schema == true) return;
    if (schema == false) {
      issue(path, path, 'Value is not allowed');
      return;
    }
    final rules = schema as Map<String, dynamic>;
    final reference = rules['\$ref'];
    if (reference is String) {
      evaluate(resolve(reference), value, path, depth + 1);
    }
    final type = rules['type'];
    if (type != null) {
      final types = type is List ? type.cast<String>() : [type as String];
      if (!types.any((t) => matches(t, value))) {
        issue(path, path, 'Expected ${types.join(' or ')}');
      }
    }
    if (value is Map<String, dynamic>) {
      final required = rules['required'] as List? ?? const [];
      for (final key in required.cast<String>()) {
        tick(depth);
        if (!value.containsKey(key)) {
          issue([...path, key], path, 'Required property is missing');
        }
      }
      final properties =
          rules['properties'] as Map<String, dynamic>? ?? const {};
      for (final entry in value.entries) {
        tick(depth);
        if (properties.containsKey(entry.key)) {
          evaluate(properties[entry.key], entry.value, [
            ...path,
            entry.key,
          ], depth + 1);
        } else if (rules.containsKey('additionalProperties')) {
          evaluate(rules['additionalProperties'], entry.value, [
            ...path,
            entry.key,
          ], depth + 1);
        }
      }
    }
    if (value is List && rules.containsKey('items')) {
      for (var i = 0; i < value.length; i++) {
        evaluate(rules['items'], value[i], [...path, i], depth + 1);
      }
    }
  }
}
