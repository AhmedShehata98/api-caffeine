import 'dart:convert';

import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_schema_form.dart';

class _Fallback implements Exception {
  const _Fallback(this.reason);
  final String reason;
}

/// Deliberately bounded JSON Schema subset. No external reference is fetched.
class SchemaFormBuilder {
  const SchemaFormBuilder();

  int? matchingVariant(FormSpec spec, Object? value) {
    final budget = _Budget();
    try {
      for (var index = 0; index < spec.variants.length; index++) {
        final errors = <String, String>{};
        _validate(spec.variants[index], value, r'$', 0, budget, errors, false);
        if (errors.isEmpty) return index;
      }
    } on _Fallback { return null; }
    return null;
  }

  SchemaFormPlan build(Map<String, dynamic> schema) {
    final budget = _Budget();
    try {
      return _build(schema, schema, 0, <String>{}, budget, rootNode: true);
    } on _Fallback catch (failure) {
      return RawJsonOnly(failure.reason);
    } on TypeError {
      return const RawJsonOnly('Malformed schema metadata');
    }
  }

  FormSpec _build(
    Object? value,
    Map<String, dynamic> root,
    int depth,
    Set<String> refs,
    _Budget budget, {
    bool rootNode = false,
  }) {
    budget.check(depth);
    if (value is! Map<String, dynamic>) {
      throw const _Fallback('Boolean or malformed schemas require raw JSON');
    }
    if (depth > 0 && value.containsKey(r'$id')) {
      throw const _Fallback('Nested schema identifiers require raw JSON');
    }
    if (value.containsKey(r'$schema') &&
        value[r'$schema'] != 'https://json-schema.org/draft/2020-12/schema') {
      throw const _Fallback('Unsupported schema dialect');
    }
    const supported = {
      'type',
      'properties',
      'required',
      'enum',
      'default',
      'items',
      r'$ref',
      r'$defs',
      'oneOf',
      'anyOf',
      'additionalProperties',
      'title',
      'description',
      r'$schema',
      r'$id',
      r'$comment',
      'examples',
      'deprecated',
      'readOnly',
      'writeOnly',
    };
    for (final key in value.keys) {
      budget.check(depth);
      if (!supported.contains(key)) {
        throw _Fallback('Unsupported schema keyword: $key');
      }
    }
    if (value.containsKey(r'$ref')) {
      final ref = value[r'$ref'];
      if (ref is! String || !ref.startsWith('#')) {
        throw const _Fallback('External \$ref not supported');
      }
      if (value.keys.any(
        (key) => !const {
          r'$ref',
          r'$defs',
          'title',
          'description',
          r'$schema',
          r'$id',
          r'$comment',
        }.contains(key),
      )) {
        throw const _Fallback('Reference siblings require raw JSON');
      }
      if (refs.contains(ref)) {
        throw const _Fallback('Recursive reference requires raw JSON');
      }
      Object? target = root;
      String pointer;
      try {
        pointer = Uri.decodeComponent(ref.substring(1));
      } on FormatException {
        throw const _Fallback('Invalid local reference');
      }
      if (pointer.isNotEmpty && !pointer.startsWith('/')) {
        throw const _Fallback('Local anchors require raw JSON');
      }
      for (final part
          in pointer.isEmpty ? <String>[] : pointer.substring(1).split('/')) {
        budget.check(depth);
        final key = part.replaceAll('~1', '/').replaceAll('~0', '~');
        if (target is! Map || !target.containsKey(key)) {
          throw const _Fallback('Local reference not found');
        }
        target = target[key];
      }
      return _build(
        target,
        root,
        depth + 1,
        {...refs, ref},
        budget,
        rootNode: rootNode,
      );
    }
    final alternatives = value['oneOf'] ?? value['anyOf'];
    if ((value.containsKey('oneOf') || value.containsKey('anyOf')) &&
        alternatives == null) {
      throw const _Fallback('Malformed variants');
    }
    if (alternatives != null) {
      if (alternatives is! List ||
          alternatives.isEmpty ||
          value.keys.any(
            (key) => !const {
              'oneOf',
              'anyOf',
              'type',
              'title',
              'description',
              r'$defs',
              r'$schema',
              r'$id',
              r'$comment',
            }.contains(key),
          ) ||
          (value.containsKey('oneOf') && value.containsKey('anyOf'))) {
        throw const _Fallback('Combined variant constraints require raw JSON');
      }
      final variants = alternatives
          .map((item) => _build(item, root, depth + 1, refs, budget))
          .toList();
      if (value.containsKey('type') &&
          (value['type'] != 'object' ||
              variants.any(
                (variant) => variant.type != SchemaFieldType.object,
              ))) {
        throw const _Fallback('Combined variant types require raw JSON');
      }
      return FormSpec(
        type: SchemaFieldType.variant,
        title: value['title'] as String?,
        description: value['description'] as String?,
        exclusive: value.containsKey('oneOf'),
        variants: variants,
      );
    }
    final rawType =
        value['type'] ??
        (value.containsKey('properties') || rootNode ? 'object' : null);
    if (value.containsKey('type') && value['type'] == null) {
      throw const _Fallback('Malformed schema type');
    }
    final type = switch (rawType) {
      'object' => SchemaFieldType.object,
      'array' => SchemaFieldType.array,
      'string' => SchemaFieldType.string,
      'integer' => SchemaFieldType.integer,
      'number' => SchemaFieldType.number,
      'boolean' => SchemaFieldType.boolean,
      'null' => SchemaFieldType.nullValue,
      _ => throw const _Fallback('Unsupported or missing schema type'),
    };
    final properties = <String, FormSpec>{};
    final required = <String>{};
    if (value['properties'] case final Object fields) {
      if (type != SchemaFieldType.object || fields is! Map<String, dynamic>) {
        throw const _Fallback('Invalid object properties');
      }
      for (final entry in fields.entries) {
        properties[entry.key] = _build(
          entry.value,
          root,
          depth + 1,
          refs,
          budget,
        );
      }
    }
    if (value['required'] case final Object fields) {
      if (type != SchemaFieldType.object ||
          fields is! List ||
          fields.any((item) => item is! String)) {
        throw const _Fallback('Invalid required fields');
      }
      required.addAll(fields.cast<String>());
      if (!properties.keys.toSet().containsAll(required)) {
        throw const _Fallback(
          'Required fields without properties require raw JSON',
        );
      }
    }
    if (value.containsKey('additionalProperties') &&
        value['additionalProperties'] == null) {
      throw const _Fallback('Malformed additional properties');
    }
    final additional = value['additionalProperties'] ?? true;
    if (additional is! bool) {
      throw const _Fallback('Additional property schemas require raw JSON');
    }
    final enums = value['enum'];
    if ((value.containsKey('enum') && enums == null) ||
        (value.containsKey('required') && value['required'] == null) ||
        (value.containsKey('properties') && value['properties'] == null)) {
      throw const _Fallback('Malformed schema constraints');
    }
    if (enums != null && (enums is! List || enums.isEmpty)) {
      throw const _Fallback('Invalid enum');
    }
    return FormSpec(
      type: type,
      title: value['title'] as String?,
      description: value['description'] as String?,
      properties: properties,
      required: required,
      additionalProperties: additional,
      items: type == SchemaFieldType.array
          ? _build(value['items'], root, depth + 1, refs, budget)
          : null,
      enumValues: enums == null
          ? null
          : (enums as List)
                .map((item) => _jsonCopy(item, depth + 1, budget))
                .toList(),
      hasDefault: value.containsKey('default'),
      defaultValue: _jsonCopy(value['default'], depth + 1, budget),
    );
  }

  Object? _jsonCopy(Object? value, int depth, _Budget budget) {
    budget.check(depth);
    if (value == null ||
        value is String ||
        value is bool ||
        (value is num && value.isFinite)) {
      return value;
    }
    if (value is List) {
      return List<Object?>.unmodifiable(
        value.map((item) => _jsonCopy(item, depth + 1, budget)),
      );
    }
    if (value is Map && value.keys.every((key) => key is String)) {
      return Map<String, Object?>.unmodifiable(
        Map<String, dynamic>.from(
          value,
        ).map((key, item) => MapEntry(key, _jsonCopy(item, depth + 1, budget))),
      );
    }
    throw const _Fallback('Schema values must be JSON');
  }

  Result<Map<String, dynamic>> arguments(
    FormSpec spec,
    Object? input, {
    bool coerce = false,
  }) {
    final budget = _Budget();
    final errors = <String, String>{};
    try {
      Object? value = input;
      if (value is String) {
        if (value.length > 256 * 1024) {
          throw const _Fallback('Large arguments require raw JSON mode');
        }
        value = jsonDecode(value);
      }
      final normalized = _validate(
        spec,
        value,
        r'$',
        0,
        budget,
        errors,
        coerce,
      );
      if (errors.isNotEmpty) {
        return Result.failure(SchemaArgumentFailure(errors));
      }
      if (normalized is! Map<String, dynamic>) {
        return const Result.failure(
          McpValidationFailure(
            'Tool arguments must be a JSON object.',
            code: McpErrorCode.invalidParams,
          ),
        );
      }
      return Result.success(normalized);
    } on FormatException {
      return Result.failure(SchemaArgumentFailure({r'$': 'Invalid JSON'}));
    } on _Fallback catch (failure) {
      return Result.failure(
        McpValidationFailure(
          failure.reason,
          code: McpErrorCode.schemaUnportable,
        ),
      );
    }
  }

  Object? _validate(
    FormSpec spec,
    Object? value,
    String path,
    int depth,
    _Budget budget,
    Map<String, String> errors,
    bool coerce,
  ) {
    budget.check(depth);
    if (spec.type == SchemaFieldType.variant) {
      final selected = value is SchemaVariantValue ? value : null;
      if (selected != null) {
        if (selected.index < 0 || selected.index >= spec.variants.length) {
          errors[path] = 'Choose a matching variant';
          return null;
        }
        final normalized = _validate(
          spec.variants[selected.index],
          selected.value,
          path,
          depth + 1,
          budget,
          errors,
          coerce,
        );
        if (errors.isNotEmpty) return null;
        return _validate(
          spec,
          normalized,
          path,
          depth + 1,
          budget,
          errors,
          false,
        );
      }
      final source = value;
      final matches = <Object?>[];
      for (var i = 0; i < spec.variants.length; i++) {
        final branchErrors = <String, String>{};
        final result = _validate(
          spec.variants[i],
          source,
          path,
          depth + 1,
          budget,
          branchErrors,
          coerce,
        );
        if (branchErrors.isEmpty) matches.add(result);
      }
      if (matches.isEmpty || (spec.exclusive && matches.length != 1)) {
        errors[path] = 'Choose a matching variant';
        return null;
      }
      return matches.first;
    }
    if (coerce && value is String && spec.type != SchemaFieldType.string) {
      try {
        value = jsonDecode(value);
      } on FormatException {
        /* Report a type error below. */
      }
    }
    final valid = switch (spec.type) {
      SchemaFieldType.object =>
        value is Map && value.keys.every((key) => key is String),
      SchemaFieldType.array => value is List,
      SchemaFieldType.string => value is String,
      SchemaFieldType.integer =>
        value is num && value.isFinite && value == value.truncateToDouble(),
      SchemaFieldType.number => value is num && value.isFinite,
      SchemaFieldType.boolean => value is bool,
      SchemaFieldType.nullValue => value == null,
      SchemaFieldType.variant => false,
    };
    if (!valid) {
      errors[path] = 'Expected ${spec.type.name}';
      return null;
    }
    if (value is Map) value = Map<String, dynamic>.from(value);
    if (value is Map<String, dynamic>) {
      final normalized = <String, dynamic>{};
      for (final key in spec.required) {
        if (!value.containsKey(key) || (coerce && value[key] == '')) {
          errors['$path.$key'] = 'Required';
        }
      }
      for (final entry in value.entries) {
        if (errors['$path.${entry.key}'] == 'Required') continue;
        final field = spec.properties[entry.key];
        if (field == null) {
          if (!spec.additionalProperties) {
            errors['$path.${entry.key}'] = 'Unknown property';
          } else {
            normalized[entry.key] = _jsonCopy(entry.value, depth + 1, budget);
          }
        } else {
          normalized[entry.key] = _validate(
            field,
            entry.value,
            '$path.${entry.key}',
            depth + 1,
            budget,
            errors,
            coerce,
          );
        }
      }
      _checkEnum(spec, normalized, path, depth, budget, errors);
      return normalized;
    }
    if (value is List) {
      final normalized = [
        for (var i = 0; i < value.length; i++)
          _validate(
            spec.items!,
            value[i],
            '$path[$i]',
            depth + 1,
            budget,
            errors,
            coerce,
          ),
      ];
      _checkEnum(spec, normalized, path, depth, budget, errors);
      return normalized;
    }
    _checkEnum(spec, value, path, depth, budget, errors);
    return value;
  }

  void _checkEnum(
    FormSpec spec,
    Object? value,
    String path,
    int depth,
    _Budget budget,
    Map<String, String> errors,
  ) {
    if (spec.enumValues != null &&
        !spec.enumValues!.any((item) => _equal(item, value, depth, budget))) {
      errors[path] = 'Choose an enum value';
    }
  }

  bool _equal(Object? left, Object? right, int depth, _Budget budget) {
    budget.check(depth);
    if (left is List && right is List) {
      return left.length == right.length &&
          [
            for (var i = 0; i < left.length; i++)
              _equal(left[i], right[i], depth + 1, budget),
          ].every((item) => item);
    }
    if (left is Map && right is Map) {
      return left.length == right.length &&
          left.keys.every(
            (key) =>
                right.containsKey(key) &&
                _equal(left[key], right[key], depth + 1, budget),
          );
    }
    return left == right;
  }
}

class _Budget {
  final _watch = Stopwatch()..start();
  var _nodes = 0;
  void check(int depth) {
    if (depth > 32) throw const _Fallback('Schema depth exceeds 32');
    if (++_nodes > 10000 || _watch.elapsedMilliseconds >= 100) {
      throw const _Fallback('Schema processing exceeded its budget');
    }
  }
}
