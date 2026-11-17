import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:re_editor/re_editor.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/ui/widgets/code_view.dart';
import 'package:test_point/core/ui/widgets/confirm_dialog.dart';

import '../models/mcp_schema_form.dart';
import '../models/mcp_protocol_models.dart';
import '../providers/mcp_tools_provider.dart';
import '../providers/mcp_work_providers.dart';
import '../services/mcp_session_work.dart';
import '../services/schema_form_builder.dart';
import '../services/schema_form_values.dart';
import 'mcp_schema_form.dart';
import 'mcp_json_result.dart';

class McpToolsView extends ConsumerStatefulWidget {
  const McpToolsView({required this.serverId, super.key});
  final String serverId;
  @override
  ConsumerState<McpToolsView> createState() => _McpToolsViewState();
}

class _McpToolsViewState extends ConsumerState<McpToolsView> {
  final _json = CodeLineEditingController();
  final _form = GlobalKey<FormState>();
  SchemaFormPlan? _plan;
  McpTool? _tool;
  Object? _value;
  bool _raw = false;
  int _formRevision = 0;
  Map<String, String> _errors = {};
  String? _error;
  @override
  void initState() {
    super.initState();
    final draft = ref
        .read(mcpSessionWorkProvider(widget.serverId))
        ?.tools
        .state
        .draft;
    if (draft?.tool != null) {
      _select(
        draft!.tool!,
        existing: draft.arguments,
        preferRaw: draft.rawEditor,
      );
    }
    _json.addListener(_changedJson);
  }

  void _changedJson() {
    if (_raw) _persist();
  }

  void _persist() {
    final text = _raw
        ? _json.text
        : jsonEncode(const SchemaFormValues().jsonValue(_value));
    ref
        .read(mcpSessionWorkProvider(widget.serverId))
        ?.tools
        .setDraft(
          McpToolDraft(
            tool: _tool,
            arguments: text,
            validateSchema: _plan is FormSpec,
            rawEditor: _raw,
          ),
        );
  }

  void _select(McpTool tool, {String? existing, bool preferRaw = false}) {
    _tool = tool;
    _plan = const SchemaFormBuilder().build(tool.inputSchema);
    _raw = _plan is RawJsonOnly || preferRaw;
    _errors = {};
    _error = null;
    _formRevision++;
    if (_plan case final FormSpec spec) {
      try {
        _value = existing == null
            ? const SchemaFormValues().initial(spec)
            : const SchemaFormValues().restore(spec, jsonDecode(existing));
      } on FormatException {
        _value = const SchemaFormValues().initial(spec);
        _raw = true;
      }
    } else {
      _value = <String, dynamic>{};
    }
    _json.text =
        existing ?? jsonEncode(const SchemaFormValues().jsonValue(_value));
    _persist();
  }

  void _switch(bool raw) {
    if (!raw && _plan is! FormSpec) return;
    if (!raw) {
      final result = const SchemaFormBuilder().arguments(
        _plan as FormSpec,
        _json.text,
      );
      if (result case Err(:final failure)) {
        setState(() => _error = failure.message);
        return;
      }
      _value = const SchemaFormValues().restore(
        _plan as FormSpec,
        result.valueOrNull,
      );
      _formRevision++;
    } else if (_plan is FormSpec) {
      final normalized = const SchemaFormBuilder().arguments(
        _plan as FormSpec,
        _value,
        coerce: true,
      );
      _json.text = jsonEncode(
        normalized.valueOrNull ?? const SchemaFormValues().jsonValue(_value),
      );
    }
    setState(() {
      _raw = raw;
      _error = null;
      _errors = {};
    });
    _persist();
  }

  Future<void> _call() async {
    final tool = _tool;
    if (tool == null) return;
    _errors = {};
    _error = null;
    if (_plan case final FormSpec spec when !_raw) {
      final result = const SchemaFormBuilder().arguments(
        spec,
        _value,
        coerce: true,
      );
      if (result case Err(:final failure)) {
        setState(() {
          _errors = failure is SchemaArgumentFailure ? failure.fields : {};
          _error = failure.message;
        });
        return;
      }
      _json.text = jsonEncode(result.valueOrNull);
      ref
          .read(mcpSessionWorkProvider(widget.serverId))
          ?.tools
          .setDraft(McpToolDraft(tool: tool, arguments: _json.text));
    } else {
      try {
        if (jsonDecode(_json.text) is! Map<String, dynamic>) {
          setState(() => _error = 'Arguments must be a JSON object.');
          return;
        }
      } on FormatException catch (failure) {
        setState(
          () => _error = 'Invalid JSON at offset ${failure.offset ?? 0}.',
        );
        return;
      }
      _persist();
    }
    final submitted = ref
        .read(mcpSessionWorkProvider(widget.serverId))
        ?.tools
        .state
        .draft;
    if (tool.annotations?.destructiveHint == true) {
      final allowed = await showConfirmDialog(
        context,
        title: 'Call destructive tool?',
        message:
            '"${tool.name}" is marked destructive by the server. Annotations are hints, not guarantees.',
        confirmLabel: 'Call tool',
        destructive: true,
      );
      if (!allowed || !mounted) return;
      if (!identical(
        submitted,
        ref.read(mcpSessionWorkProvider(widget.serverId))?.tools.state.draft,
      )) {
        setState(() => _error = 'Arguments changed. Review and call again.');
        return;
      }
    }
    if (!mounted) return;
    setState(() {});
    await ref.read(mcpWorkActionsProvider(widget.serverId))?.callTool();
  }

  @override
  void dispose() {
    _json.removeListener(_changedJson);
    _json.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final tools = ref.watch(mcpToolsProvider(widget.serverId));
    ref.listen(mcpToolsProvider(widget.serverId), (_, next) {
      if (next.value == null &&
          ref.read(mcpSessionWorkProvider(widget.serverId)) != null) {
        return;
      }
      if (next case AsyncData(:final value) when _tool != null) {
        final updated = value
            ?.where((tool) => tool.name == _tool!.name)
            .firstOrNull;
        if (updated == null) {
          setState(() {
            _tool = null;
            _plan = null;
            _value = <String, dynamic>{};
            _raw = false;
            _json.text = '{}';
            _persist();
          });
        } else if (updated != _tool) {
          setState(
            () => _select(updated, existing: _json.text, preferRaw: _raw),
          );
        }
      }
    });
    final work = ref.watch(mcpToolCallProvider(widget.serverId)).value;
    final running = work?.running ?? false;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (!running) _call();
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
                    'Tools',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh tools',
                  onPressed: () =>
                      ref.invalidate(mcpToolsProvider(widget.serverId)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            if (tools.isLoading)
              const LinearProgressIndicator()
            else if (tools.hasError)
              Text(
                tools.error is Failure
                    ? (tools.error as Failure).message
                    : 'Could not load tools.',
              )
            else if (tools.value == null)
              const Text('Connect a server to view tools.')
            else
              DropdownButtonFormField<String>(
                key: ValueKey(tools.value),
                initialValue:
                    tools.value!.any((tool) => tool.name == _tool?.name)
                    ? _tool?.name
                    : null,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Select tool'),
                items: [
                  for (final tool in tools.value!)
                    DropdownMenuItem(
                      value: tool.name,
                      child: Text(
                        tool.title ?? tool.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: running
                    ? null
                    : (name) => setState(
                        () => _select(
                          tools.value!.firstWhere((tool) => tool.name == name),
                        ),
                      ),
              ),
            if (_tool != null) ...[
              const SizedBox(height: 16),
              Text(_tool!.description ?? _tool!.name),
              Wrap(
                spacing: 8,
                children: [
                  if (_tool!.annotations?.readOnlyHint == true)
                    const Chip(label: Text('Read-only hint', maxLines: 1)),
                  if (_tool!.annotations?.destructiveHint == true)
                    const Chip(label: Text('Destructive hint', maxLines: 1)),
                  if (_tool!.annotations?.idempotentHint == true)
                    const Chip(label: Text('Idempotent hint', maxLines: 1)),
                ],
              ),
              const SizedBox(height: 16),
              SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: const Text('Form'),
                    enabled: _plan is FormSpec,
                  ),
                  const ButtonSegment(value: true, label: Text('JSON')),
                ],
                selected: {_raw},
                onSelectionChanged: running
                    ? null
                    : (selection) => _switch(selection.single),
              ),
              if (_plan case RawJsonOnly(:final reason))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(reason),
                ),
              const SizedBox(height: 16),
              if (_raw)
                SizedBox(
                  height: 220,
                  child: CodeView(
                    controller: _json,
                    highlightJson: true,
                    readOnly: running,
                  ),
                )
              else
                Form(
                  key: _form,
                  child: McpSchemaForm(
                    key: ValueKey(_formRevision),
                    spec: _plan as FormSpec,
                    value: _value,
                    errors: _errors,
                    enabled: !running,
                    onChanged: (value) {
                      setState(() {
                        _value = value;
                        _errors = {};
                        _error = null;
                      });
                      _persist();
                    },
                  ),
                ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Text(
                    _error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  FilledButton.icon(
                    onPressed: running ? null : _call,
                    icon: const Icon(Icons.play_arrow),
                    label: Text(
                      running ? 'Calling…' : 'Call tool · Ctrl+Enter',
                      maxLines: 1,
                    ),
                  ),
                  TextButton.icon(
                    onPressed: () => Clipboard.setData(
                      ClipboardData(
                        text: _raw
                            ? _json.text
                            : jsonEncode(
                                const SchemaFormValues().jsonValue(_value),
                              ),
                      ),
                    ),
                    icon: const Icon(Icons.copy),
                    label: const Text('Copy arguments JSON', maxLines: 1),
                  ),
                ],
              ),
            ],
            if (work?.outcome case final Result outcome) ...[
              const Divider(height: 32),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      'Result · ${work?.submitted?.tool?.name ?? ''}',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  Text(
                    '${work!.duration?.inMilliseconds ?? 0} ms',
                    maxLines: 1,
                  ),
                  TextButton(
                    onPressed: () => ref
                        .read(mcpSessionWorkProvider(widget.serverId))
                        ?.tools
                        .clearResult(),
                    child: const Text('Clear result'),
                  ),
                ],
              ),
              if (outcome case Err(:final failure))
                Text(
                  failure.message,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              if (work.outcome?.valueOrNull case final call?) ...[
                Text(
                  call.notice ??
                      (call.result.isError ? 'Tool error' : 'Success'),
                  style: TextStyle(
                    color: call.result.isError
                        ? Theme.of(context).colorScheme.error
                        : Theme.of(context).colorScheme.primary,
                  ),
                ),
                for (final content in call.result.content)
                  if (content is TextBlock)
                    SelectableText(
                      content.text.length > 4096
                          ? '${content.text.substring(0, 4096)}…'
                          : content.text,
                    ),
                McpJsonResult(value: call.raw),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
