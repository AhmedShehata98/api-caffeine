import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_protocol_models.dart';
import '../providers/mcp_prompts_provider.dart';
import '../providers/mcp_work_providers.dart';
import '../services/mcp_session_work.dart';
import 'mcp_json_result.dart';

class McpPromptsView extends ConsumerStatefulWidget {
  const McpPromptsView({required this.serverId, super.key});
  final String serverId;
  @override
  ConsumerState<McpPromptsView> createState() => _McpPromptsViewState();
}

class _McpPromptsViewState extends ConsumerState<McpPromptsView> {
  final _form = GlobalKey<FormState>();
  McpPrompt? _prompt;
  final _arguments = <String, String>{};
  int _revision = 0;

  @override
  void initState() {
    super.initState();
    final draft = ref
        .read(mcpSessionWorkProvider(widget.serverId))
        ?.prompts
        .state
        .draft;
    _prompt = draft?.prompt;
    _arguments.addAll(draft?.arguments ?? {});
  }

  void _persist() => ref
      .read(mcpSessionWorkProvider(widget.serverId))
      ?.prompts
      .setDraft(McpPromptDraft(prompt: _prompt, arguments: _arguments));

  void _select(McpPrompt? prompt, {bool preserve = false}) {
    _prompt = prompt;
    if (preserve) {
      final names = prompt?.arguments.map((arg) => arg.name).toSet() ?? {};
      _arguments.removeWhere((name, _) => !names.contains(name));
    } else {
      _arguments.clear();
    }
    _revision++;
    _persist();
  }

  Future<void> _get() async {
    if (_prompt == null || !(_form.currentState?.validate() ?? false)) return;
    _persist();
    await ref.read(mcpWorkActionsProvider(widget.serverId))?.getPrompt();
  }

  @override
  Widget build(BuildContext context) {
    final prompts = ref.watch(mcpPromptsProvider(widget.serverId));
    ref.listen(mcpPromptsProvider(widget.serverId), (_, next) {
      // Reattaching providers briefly has no services while the session stream
      // emits its initial value. That is not a server list removing the draft.
      if (next.value == null &&
          ref.read(mcpSessionWorkProvider(widget.serverId)) != null) {
        return;
      }
      if (next case AsyncData(:final value) when _prompt != null) {
        final updated = value
            ?.where((p) => p.name == _prompt!.name)
            .firstOrNull;
        if (updated != _prompt) {
          setState(() => _select(updated, preserve: true));
        }
      }
    });
    final work = ref.watch(mcpPromptGetProvider(widget.serverId)).value;
    final running = work?.running ?? false;
    final ready =
        !prompts.isLoading &&
        !prompts.hasError &&
        (prompts.value?.any((p) => p.name == _prompt?.name) ?? false);
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!running && ready) _get();
        },
      },
      child: Focus(
        autofocus: true,
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'Prompts',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh prompts',
                  onPressed: () =>
                      ref.invalidate(mcpPromptsProvider(widget.serverId)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (prompts.isLoading)
              const LinearProgressIndicator()
            else if (prompts.hasError)
              Text(
                prompts.error is Failure
                    ? (prompts.error as Failure).message
                    : 'Could not load prompts.',
              )
            else if (prompts.value == null)
              const Text('Connect a server to view prompts.')
            else if (prompts.value!.isEmpty)
              const Text('This server has no prompts. Refresh to check again.')
            else
              DropdownButtonFormField<String>(
                key: ValueKey((prompts.value, _prompt?.name)),
                initialValue: ready ? _prompt?.name : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select prompt'),
                items: [
                  for (final prompt in prompts.value!)
                    DropdownMenuItem(
                      value: prompt.name,
                      child: Text(
                        prompt.title ?? prompt.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: running
                    ? null
                    : (name) => setState(
                        () => _select(
                          prompts.value!.firstWhere(
                            (prompt) => prompt.name == name,
                          ),
                        ),
                      ),
              ),
            if (_prompt case final prompt?) ...[
              const SizedBox(height: 16),
              Text(prompt.description ?? prompt.name),
              const SizedBox(height: 16),
              Form(
                key: _form,
                child: Column(
                  children: [
                    for (final argument in prompt.arguments)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          key: ValueKey((_revision, argument.name)),
                          initialValue: _arguments[argument.name] ?? '',
                          enabled: !running,
                          decoration: InputDecoration(
                            labelText:
                                '${argument.title ?? argument.name}${argument.required ? ' *' : ''}',
                            helperText: argument.description,
                          ),
                          validator: (value) =>
                              argument.required &&
                                  (value?.trim().isEmpty ?? true)
                              ? 'Enter ${argument.title ?? argument.name}.'
                              : null,
                          onChanged: (value) {
                            if (value.isEmpty && !argument.required) {
                              _arguments.remove(argument.name);
                            } else {
                              _arguments[argument.name] = value;
                            }
                            _persist();
                          },
                        ),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.icon(
                  onPressed: running || !ready ? null : _get,
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('Get prompt · Ctrl+Enter', maxLines: 1),
                ),
              ),
            ],
            if (running) ...[
              const SizedBox(height: 24),
              const LinearProgressIndicator(),
            ],
            if (work?.outcome case final outcome?) ...[
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Messages · ${work?.submitted?.prompt?.name ?? ''}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  Text(
                    '${work?.duration?.inMilliseconds ?? 0} ms',
                    maxLines: 1,
                  ),
                  IconButton(
                    tooltip: 'Clear prompt result',
                    onPressed: () => ref
                        .read(mcpSessionWorkProvider(widget.serverId))
                        ?.prompts
                        .clearResult(),
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
              if (outcome case Err(:final failure))
                Text(failure.message)
              else ...[
                if (outcome.valueOrNull!.description case final description?)
                  Text(description),
                for (final (index, message)
                    in outcome.valueOrNull!.messages.indexed)
                  Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(
                            '${index + 1}. ${message.role.name}',
                            maxLines: 1,
                            style: Theme.of(context).textTheme.labelLarge,
                          ),
                          const SizedBox(height: 8),
                          if (message.content case TextBlock(:final text))
                            SelectableText(
                              text.length <= 4096
                                  ? text
                                  : '${text.substring(0, 4096)}…',
                            )
                          else
                            Text(
                              'Content: ${message.content.toJson()['type']}. View the complete JSON below.',
                            ),
                        ],
                      ),
                    ),
                  ),
                if (outcome.valueOrNull!.messages.isEmpty)
                  const Text('This prompt returned no messages.'),
                const SizedBox(height: 16),
                McpJsonResult(
                  key: ObjectKey(outcome),
                  value: {
                    'description': outcome.valueOrNull!.description,
                    'messages': outcome.valueOrNull!.messages
                        .map((m) => m.toJson())
                        .toList(),
                  },
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
