import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_uri_template_input.dart';
import '../providers/mcp_resource_completion_provider.dart';
import '../services/mcp_uri_template.dart';
import 'mcp_completion_text_input.dart';

class McpTemplateTextInput extends ConsumerWidget {
  const McpTemplateTextInput({
    required this.serverId,
    required this.template,
    required this.name,
    required this.inputs,
    required this.enabled,
    required this.onChanged,
    super.key,
  });
  final String serverId;
  final String template;
  final String name;
  final Map<String, McpUriTemplateInput> inputs;
  final bool enabled;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = ref.watch(mcpResourceCompletionProvider(serverId));
    return McpCompletionTextInput(
      name: name,
      value: inputs[name]!.text,
      contextToken: (template, inputs),
      sessionToken: actions,
      enabled: enabled,
      onChanged: onChanged,
      errorText: McpUriTemplate.parseInput(inputs[name]!)
          .failureOrNull
          ?.message,
      complete: actions == null
          ? null
          : () => actions.complete(template, name, inputs),
    );
  }
}
