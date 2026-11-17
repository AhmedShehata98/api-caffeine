import 'package:flutter/material.dart';

import '../services/mcp_uri_template.dart';

class McpUriTemplateForm extends StatelessWidget {
  const McpUriTemplateForm({
    required this.template,
    required this.values,
    required this.onChanged,
    required this.enabled,
    super.key,
  });
  final McpUriTemplate template;
  final Map<String, String> values;
  final ValueChanged<Map<String, String>> onChanged;
  final bool enabled;
  @override
  Widget build(BuildContext context) {
    final latest = Map<String, String>.of(values);
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
          'Include a variable to set its string value. An included blank value is empty; unchecked variables are omitted.',
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
                      latest[name] = '';
                    } else {
                      latest.remove(name);
                    }
                    onChanged(Map.of(latest));
                  },
          ),
          if (values.containsKey(name))
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: TextFormField(
                key: ValueKey((template.source, name)),
                initialValue: values[name],
                enabled: enabled,
                maxLength: 4096,
                decoration: InputDecoration(labelText: name),
                onChanged: (value) {
                  latest[name] = value;
                  onChanged(Map.of(latest));
                },
              ),
            ),
        ],
        const SizedBox(height: 16),
      ],
    );
  }
}
