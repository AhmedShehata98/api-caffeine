import 'dart:convert';

import '../models/mcp_schema_form.dart';
import 'schema_form_builder.dart';

/// Draft transformations shared by the form and raw JSON editor.
class SchemaFormValues {
  const SchemaFormValues();
  Object? initial(FormSpec spec) {
    if (spec.hasDefault) {
      return restore(spec, jsonDecode(jsonEncode(spec.defaultValue)));
    }
    return switch (spec.type) {
      SchemaFieldType.object => <String, dynamic>{
        for (final entry in spec.properties.entries)
          if (spec.required.contains(entry.key) || entry.value.hasDefault)
            entry.key: initial(entry.value),
      },
      SchemaFieldType.array => <Object?>[],
      SchemaFieldType.boolean => false,
      SchemaFieldType.nullValue => null,
      SchemaFieldType.variant => SchemaVariantValue(
        0,
        initial(spec.variants.first),
      ),
      _ => '',
    };
  }

  Object? restore(FormSpec spec, Object? value) {
    if (spec.type == SchemaFieldType.variant) {
      final index = const SchemaFormBuilder().matchingVariant(spec, value) ?? 0;
      return SchemaVariantValue(index, restore(spec.variants[index], value));
    }
    if (value is Map && spec.type == SchemaFieldType.object) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key as String: spec.properties[entry.key] == null
              ? entry.value
              : restore(spec.properties[entry.key]!, entry.value),
      };
    }
    if (value is List && spec.type == SchemaFieldType.array) {
      return value.map((item) => restore(spec.items!, item)).toList();
    }
    return value;
  }

  Object? jsonValue(Object? value) {
    if (value is SchemaVariantValue) return jsonValue(value.value);
    if (value is Map) {
      return <String, dynamic>{
        for (final entry in value.entries)
          entry.key as String: jsonValue(entry.value),
      };
    }
    if (value is List) return value.map(jsonValue).toList();
    return value;
  }
}
