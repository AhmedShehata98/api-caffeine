import 'dart:convert';

import 'package:flutter/material.dart';

import '../models/mcp_schema_form.dart';
import '../services/schema_form_values.dart';

class McpSchemaForm extends StatelessWidget {
  const McpSchemaForm({
    required this.spec,
    required this.value,
    required this.onChanged,
    this.errors = const {},
    this.enabled = true,
    super.key,
  });
  final FormSpec spec;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final Map<String, String> errors;
  final bool enabled;
  @override
  Widget build(BuildContext context) => _Field(
    spec: spec,
    value: value,
    onChanged: onChanged,
    path: r'$',
    label: 'Arguments',
    errors: errors,
    enabled: enabled,
  );
}

class _Field extends StatelessWidget {
  const _Field({
    required this.spec,
    required this.value,
    required this.onChanged,
    required this.path,
    required this.label,
    required this.errors,
    required this.enabled,
    super.key,
  });
  final FormSpec spec;
  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String path;
  final String label;
  final Map<String, String> errors;
  final bool enabled;
  Widget field(
    FormSpec child,
    Object? value,
    ValueChanged<Object?> changed,
    String path,
    String label,
  ) => _Field(
    key: ValueKey(path),
    spec: child,
    value: value,
    onChanged: changed,
    path: path,
    label: label,
    errors: errors,
    enabled: enabled,
  );

  @override
  Widget build(BuildContext context) {
    final decoration = InputDecoration(
      labelText: label,
      errorText: errors[path],
      helperText: spec.description,
    );
    if (spec.type == SchemaFieldType.variant) {
      final selected = value is SchemaVariantValue
          ? value as SchemaVariantValue
          : SchemaVariantValue(0, value);
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          DropdownButtonFormField<int>(
            initialValue: selected.index,
            isExpanded: true,
            decoration: decoration,
            items: [
              for (var index = 0; index < spec.variants.length; index++)
                DropdownMenuItem(
                  value: index,
                  child: Text(
                    spec.variants[index].title ?? 'Variant ${index + 1}',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
            ],
            onChanged: enabled
                ? (index) => onChanged(
                    SchemaVariantValue(
                      index!,
                      const SchemaFormValues().initial(spec.variants[index]),
                    ),
                  )
                : null,
          ),
          const SizedBox(height: 12),
          _Field(
            key: ValueKey('$path.variant${selected.index}'),
            spec: spec.variants[selected.index],
            value: selected.value,
            onChanged: (next) =>
                onChanged(SchemaVariantValue(selected.index, next)),
            path: path,
            label: label,
            errors: errors,
            enabled: enabled,
          ),
        ],
      );
    }
    if (spec.type == SchemaFieldType.object) {
      final values = value is Map
          ? Map<String, dynamic>.from(value as Map)
          : <String, dynamic>{};
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (path != r'$')
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Text(label, style: Theme.of(context).textTheme.titleSmall),
            ),
          for (final entry in spec.properties.entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (!spec.required.contains(entry.key))
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        'Include ${entry.key}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      value: values.containsKey(entry.key),
                      onChanged: enabled
                          ? (include) {
                              if (include == true) {
                                values[entry.key] = const SchemaFormValues()
                                    .initial(entry.value);
                              } else {
                                values.remove(entry.key);
                              }
                              onChanged(Map<String, dynamic>.of(values));
                            }
                          : null,
                    ),
                  if (spec.required.contains(entry.key) ||
                      values.containsKey(entry.key))
                    field(
                      entry.value,
                      values[entry.key],
                      (next) {
                        values[entry.key] = next;
                        onChanged(Map<String, dynamic>.of(values));
                      },
                      '$path.${entry.key}',
                      '${entry.key}${spec.required.contains(entry.key) ? ' *' : ''}',
                    ),
                ],
              ),
            ),
          if (errors[path] != null)
            Text(
              errors[path]!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      );
    }
    if (spec.type == SchemaFieldType.array) {
      final values = value is List
          ? List<Object?>.of(value as List)
          : <Object?>[];
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
          for (var index = 0; index < values.length; index++)
            Padding(
              padding: const EdgeInsets.only(top: 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: field(
                      spec.items!,
                      values[index],
                      (next) {
                        if (index >= values.length) return;
                        values[index] = next;
                        onChanged(List<Object?>.of(values));
                      },
                      '$path[$index]',
                      'Item ${index + 1}',
                    ),
                  ),
                  IconButton(
                    tooltip: 'Remove item ${index + 1}',
                    onPressed: enabled
                        ? () {
                            if (index >= values.length) return;
                            values.removeAt(index);
                            onChanged(List<Object?>.of(values));
                          }
                        : null,
                    icon: const Icon(Icons.remove_circle_outline),
                  ),
                ],
              ),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: enabled
                  ? () {
                      values.add(const SchemaFormValues().initial(spec.items!));
                      onChanged(List<Object?>.of(values));
                    }
                  : null,
              icon: const Icon(Icons.add),
              label: const Text('Add item'),
            ),
          ),
          if (errors[path] != null)
            Text(
              errors[path]!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
        ],
      );
    }
    if (spec.enumValues != null) {
      final index = spec.enumValues!.indexWhere(
        (item) => jsonEncode(item) == jsonEncode(value),
      );
      return DropdownButtonFormField<int>(
        initialValue: index < 0 ? null : index,
        isExpanded: true,
        decoration: decoration,
        items: [
          for (var i = 0; i < spec.enumValues!.length; i++)
            DropdownMenuItem(
              value: i,
              child: Text(
                '${spec.enumValues![i]}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
        ],
        onChanged: enabled
            ? (index) => onChanged(spec.enumValues![index!])
            : null,
      );
    }
    if (spec.type == SchemaFieldType.boolean) {
      return SwitchListTile(
        contentPadding: EdgeInsets.zero,
        title: Text(label, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: errors[path] == null ? null : Text(errors[path]!),
        value: value == true,
        onChanged: enabled ? onChanged : null,
      );
    }
    if (spec.type == SchemaFieldType.nullValue) {
      return InputDecorator(decoration: decoration, child: const Text('null'));
    }
    return _TextInput(
      value: value?.toString() ?? '',
      enabled: enabled,
      decoration: decoration,
      keyboardType: spec.type == SchemaFieldType.string
          ? TextInputType.text
          : const TextInputType.numberWithOptions(signed: true, decimal: true),
      onChanged: onChanged,
    );
  }
}

class _TextInput extends StatefulWidget {
  const _TextInput({
    required this.value,
    required this.enabled,
    required this.decoration,
    required this.keyboardType,
    required this.onChanged,
  });
  final String value;
  final bool enabled;
  final InputDecoration decoration;
  final TextInputType keyboardType;
  final ValueChanged<String> onChanged;
  @override
  State<_TextInput> createState() => _TextInputState();
}

class _TextInputState extends State<_TextInput> {
  late final _controller = TextEditingController(text: widget.value);
  @override
  void didUpdateWidget(covariant _TextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_controller.text != widget.value) {
      // Updating a Form field's controller during build notifies its ancestor
      // Form. Apply restored values after the current build has finished.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _controller.text != widget.value) {
          _controller.text = widget.value;
        }
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => TextFormField(
    controller: _controller,
    enabled: widget.enabled,
    decoration: widget.decoration,
    keyboardType: widget.keyboardType,
    onChanged: widget.onChanged,
  );
}
