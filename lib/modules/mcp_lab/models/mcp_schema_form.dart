import 'mcp_failure.dart';

sealed class SchemaFormPlan {
  const SchemaFormPlan();
}

class RawJsonOnly extends SchemaFormPlan {
  const RawJsonOnly(this.reason);
  final String reason;
}

enum SchemaFieldType {
  object,
  array,
  string,
  integer,
  number,
  boolean,
  nullValue,
  variant,
}

class FormSpec extends SchemaFormPlan {
  FormSpec({
    required this.type,
    this.title,
    this.description,
    Map<String, FormSpec> properties = const {},
    Set<String> required = const {},
    this.items,
    List<Object?>? enumValues,
    this.hasDefault = false,
    this.defaultValue,
    this.additionalProperties = true,
    List<FormSpec> variants = const [],
    this.exclusive = false,
  }) : properties = Map.unmodifiable(properties),
       required = Set.unmodifiable(required),
       enumValues = enumValues == null ? null : List.unmodifiable(enumValues),
       variants = List.unmodifiable(variants);
  final SchemaFieldType type;
  final String? title;
  final String? description;
  final Map<String, FormSpec> properties;
  final Set<String> required;
  final FormSpec? items;
  final List<Object?>? enumValues;
  final bool hasDefault;
  final Object? defaultValue;
  final bool additionalProperties;
  final List<FormSpec> variants;
  final bool exclusive;
}

/// Explicit picker input: only this branch's value enters the arguments.
class SchemaVariantValue {
  const SchemaVariantValue(this.index, this.value);
  final int index;
  final Object? value;
}

class SchemaArgumentFailure extends McpValidationFailure {
  SchemaArgumentFailure(Map<String, String> fields)
    : fields = Map.unmodifiable(fields),
      super(
        'Fix the invalid tool arguments.',
        code: McpErrorCode.invalidParams,
      );
  final Map<String, String> fields;
}
