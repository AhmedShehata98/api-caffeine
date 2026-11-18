import 'package:flutter/material.dart';
import 'package:test_point/core/ui/theme/app_fonts.dart';

import '../services/mcp_uri_template.dart';
import '../models/mcp_uri_template_input.dart';
import 'mcp_template_text_input.dart';

class McpUriTemplateForm extends StatelessWidget {
  const McpUriTemplateForm({
    required this.template,
    required this.values,
    required this.onChanged,
    required this.enabled,
    required this.serverId,
    super.key,
  });
  final McpUriTemplate template;
  final Map<String, McpUriTemplateInput> values;
  final ValueChanged<Map<String, McpUriTemplateInput>> onChanged;
  final bool enabled;
  final String serverId;
  @override
  Widget build(BuildContext context) {
    final latest = Map<String, McpUriTemplateInput>.of(values);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Template arguments',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        Text(template.source, maxLines: 1, overflow: TextOverflow.ellipsis),
        const SizedBox(height: 8),
        const Text(
          'Choose Text, List or Object. Lists and objects use JSON with string values. Unchecked variables and empty collections are omitted; included blank text is empty.',
        ),
        for (final name in template.variables) ...[
          CheckboxListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(
              'Include $name',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            value: values.containsKey(name),
            onChanged: !enabled
                ? null
                : (include) {
                    if (include == true) {
                      latest[name] = const McpUriTemplateInput('');
                    } else {
                      latest.remove(name);
                    }
                    onChanged(Map.of(latest));
                  },
          ),
          if (values.containsKey(name))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _input(name, values[name]!, (value) {
                latest[name] = value;
                onChanged(Map.of(latest));
              }),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _input(
    String name,
    McpUriTemplateInput input,
    ValueChanged<McpUriTemplateInput> changed,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        DropdownButtonFormField<McpUriTemplateInputKind>(
          key: ValueKey((template.source, name, 'kind', input.kind)),
          initialValue: input.kind,
          isExpanded: true,
          decoration: InputDecoration(labelText: '$name type'),
          items: const [
            DropdownMenuItem(
              value: McpUriTemplateInputKind.text,
              child: Text('Text', maxLines: 1),
            ),
            DropdownMenuItem(
              value: McpUriTemplateInputKind.list,
              child: Text('List', maxLines: 1),
            ),
            DropdownMenuItem(
              value: McpUriTemplateInputKind.object,
              child: Text('Object', maxLines: 1),
            ),
          ],
          onChanged: !enabled
              ? null
              : (kind) {
                  if (kind == null || kind == input.kind) return;
                  changed(
                    McpUriTemplateInput(switch (kind) {
                      McpUriTemplateInputKind.text => '',
                      McpUriTemplateInputKind.list => '[]',
                      McpUriTemplateInputKind.object => '{}',
                    }, kind: kind),
                  );
                },
        ),
        const SizedBox(height: 8),
        if (input.kind == McpUriTemplateInputKind.text)
          McpTemplateTextInput(
            key: ValueKey((serverId, template.source, name)),
            serverId: serverId,
            template: template.source,
            name: name,
            inputs: values,
            enabled: enabled,
            onChanged: (text) => changed(McpUriTemplateInput(text)),
          )
        else
          TextFormField(
            key: ValueKey((template.source, name, input.kind)),
            initialValue: input.text,
            enabled: enabled,
            maxLength: 4096,
            style: const TextStyle(fontFamily: AppFonts.mono),
            minLines: 2,
            maxLines: 4,
            decoration: InputDecoration(
              labelText: name,
              helperText: switch (input.kind) {
                McpUriTemplateInputKind.text => null,
                McpUriTemplateInputKind.list =>
                  'JSON list, for example ["a", "b"].',
                McpUriTemplateInputKind.object =>
                  'JSON object, for example {"key": "value"}.',
              },
              errorText: McpUriTemplate.parseInput(input)
                  .failureOrNull
                  ?.message,
            ),
            onChanged: (value) =>
                changed(McpUriTemplateInput(value, kind: input.kind)),
          ),
      ],
    );
  }
}
