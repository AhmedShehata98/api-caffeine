import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_uri_template_input.dart';
import '../providers/mcp_resource_completion_provider.dart';
import '../services/mcp_primitive_services.dart';
import '../services/mcp_uri_template.dart';

/// Field-local, memory-only suggestions. Editing any template argument or
/// changing the session invalidates both visible and pending results.
class McpTemplateTextInput extends ConsumerStatefulWidget {
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
  ConsumerState<McpTemplateTextInput> createState() =>
      _McpTemplateTextInputState();
}

class _McpTemplateTextInputState extends ConsumerState<McpTemplateTextInput> {
  late final _text = TextEditingController(
    text: widget.inputs[widget.name]!.text,
  );
  Result<McpCompletion>? _result;
  bool _loading = false;
  int _revision = 0;

  void _clear() {
    _revision++;
    _loading = false;
    _result = null;
  }

  @override
  void didUpdateWidget(McpTemplateTextInput oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!identical(oldWidget.inputs, widget.inputs) ||
        oldWidget.enabled != widget.enabled ||
        oldWidget.template != widget.template ||
        oldWidget.serverId != widget.serverId ||
        oldWidget.name != widget.name) {
      _clear();
      final text = widget.inputs[widget.name]!.text;
      if (_text.text != text) {
        _text.value = TextEditingValue(
          text: text,
          selection: TextSelection.collapsed(offset: text.length),
        );
      }
    }
  }

  Future<void> _load(McpResourceCompletionActions actions) async {
    final revision = ++_revision;
    setState(() {
      _loading = true;
      _result = null;
    });
    final result = await actions.complete(
      widget.template,
      widget.name,
      widget.inputs,
    );
    if (!mounted ||
        revision != _revision ||
        !widget.enabled ||
        !identical(
          ref.read(mcpResourceCompletionProvider(widget.serverId)),
          actions,
        )) {
      return;
    }
    setState(() {
      _loading = false;
      _result = result;
    });
  }

  @override
  void dispose() {
    _text.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = mcpResourceCompletionProvider(widget.serverId);
    final actions = ref.watch(provider);
    ref.listen(provider, (_, _) => setState(_clear));
    final completion = _result?.valueOrNull;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextFormField(
          controller: _text,
          enabled: widget.enabled,
          maxLength: 4096,
          decoration: InputDecoration(
            labelText: widget.name,
            errorText: McpUriTemplate.parseInput(widget.inputs[widget.name]!)
                .failureOrNull
                ?.message,
          ),
          onChanged: (value) {
            setState(_clear);
            widget.onChanged(value);
          },
        ),
        if (actions != null) ...[
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: !widget.enabled || _loading
                  ? null
                  : () => _load(actions),
              icon: const Icon(Icons.auto_awesome_outlined),
              label: Text(
                _loading ? 'Loading suggestions…' : 'Suggest ${widget.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ),
          if (_loading) const LinearProgressIndicator(),
          if (_result?.failureOrNull case final failure?) Text(failure.message),
          if (completion != null) ...[
            Text(
              completion.values.isEmpty
                  ? 'No suggestions returned.'
                  : '${completion.values.length} suggestions${completion.total == null ? '' : ' of ${completion.total}'}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (completion.values.isNotEmpty)
              SizedBox(
                height: (completion.values.length * 48.0).clamp(0, 192),
                child: ListView.builder(
                  itemCount: completion.values.length,
                  itemBuilder: (context, index) {
                    final value = completion.values[index];
                    return ListTile(
                      dense: true,
                      title: Text(
                        value.isEmpty ? '(empty text)' : value,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      onTap: !widget.enabled
                          ? null
                          : () {
                              setState(_clear);
                              widget.onChanged(value);
                            },
                    );
                  },
                ),
              ),
            if (completion.hasMore)
              const Text(
                'More matches are available. Refine the text and request suggestions again.',
              ),
          ],
        ],
      ],
    );
  }
}
