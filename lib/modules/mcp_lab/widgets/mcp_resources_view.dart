import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/result.dart';

import '../providers/mcp_resources_provider.dart';
import '../providers/mcp_work_providers.dart';
import '../services/mcp_uri_template.dart';
import '../models/mcp_uri_template_input.dart';
import '../services/mcp_session_work.dart';
import 'mcp_uri_template_form.dart';
import 'mcp_json_result.dart';
import 'mcp_resource_content_view.dart';

class McpResourcesView extends ConsumerStatefulWidget {
  const McpResourcesView({required this.serverId, super.key});
  final String serverId;
  @override
  ConsumerState<McpResourcesView> createState() => _McpResourcesViewState();
}

class _McpResourcesViewState extends ConsumerState<McpResourcesView> {
  late final _uri = TextEditingController(
    text:
        ref
            .read(mcpSessionWorkProvider(widget.serverId))
            ?.resources
            .state
            .draft ??
        '',
  );
  bool _templates = false;
  McpUriTemplate? _template;
  Map<String, McpUriTemplateInput> _templateValues = {};
  String? _templateError;
  @override
  void initState() {
    super.initState();
    final draft = ref
        .read(mcpSessionWorkProvider(widget.serverId))
        ?.resourceTemplate
        .state
        .draft;
    if (draft?.template case final source?) {
      _templates = true;
      _selectTemplate(source, values: draft!.values);
    }
    _uri.addListener(_persist);
  }

  void _selectTemplate(
    String source, {
    Map<String, McpUriTemplateInput> values = const {},
  }) {
    final parsed = McpUriTemplate.parse(source);
    _template = parsed.valueOrNull;
    _templateError = parsed.failureOrNull?.message;
    _templateValues = Map.of(values);
    if (_template == null) {
      _uri.text = source;
      ref
          .read(mcpSessionWorkProvider(widget.serverId))
          ?.resourceTemplate
          .setDraft(McpResourceTemplateDraft());
    } else {
      _expand(values);
    }
  }

  void _expand(Map<String, McpUriTemplateInput> values) {
    _templateValues = Map.of(values);
    ref
        .read(mcpSessionWorkProvider(widget.serverId))
        ?.resourceTemplate
        .setDraft(
          McpResourceTemplateDraft(template: _template!.source, values: values),
        );
    final expanded = _template!.expandInputs(values);
    _templateError = expanded.failureOrNull?.message;
    _uri.text = expanded.valueOrNull ?? '';
    _persist();
  }

  void _manualUri() {
    _template = null;
    _templateValues = {};
    _templateError = null;
    ref
        .read(mcpSessionWorkProvider(widget.serverId))
        ?.resourceTemplate
        .setDraft(McpResourceTemplateDraft());
  }

  void _persist() => ref
      .read(mcpSessionWorkProvider(widget.serverId))
      ?.resources
      .setDraft(_uri.text);
  Future<void> _read() async {
    if (_templateError != null) return;
    _persist();
    await ref.read(mcpWorkActionsProvider(widget.serverId))?.readResource();
  }

  @override
  void dispose() {
    _uri.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final resources = ref.watch(mcpResourcesProvider((widget.serverId, false)));
    final templates = ref.watch(mcpResourcesProvider((widget.serverId, true)));
    final listing = _templates ? templates : resources;
    final target = (widget.serverId, _templates);
    final work = ref.watch(mcpResourceReadProvider(widget.serverId)).value;
    final running = work?.running ?? false;
    final active = ref.watch(mcpSessionWorkProvider(widget.serverId)) != null;
    ref.listen(mcpSessionWorkProvider(widget.serverId), (_, next) {
      if (next == null) {
        setState(() {
          _uri.clear();
          _template = null;
          _templateValues = {};
          _templateError = null;
        });
      }
    });
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.enter, control: true): () {
          if (active && !running) _read();
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
                    'Resources',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
                IconButton(
                  tooltip: 'Refresh resource list',
                  onPressed: () => ref.invalidate(mcpResourcesProvider(target)),
                  icon: const Icon(Icons.refresh),
                ),
              ],
            ),
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<bool>(
                segments: [
                  ButtonSegment(
                    value: false,
                    label: Text(
                      'Resources (${resources.items.length})',
                      maxLines: 1,
                    ),
                  ),
                  ButtonSegment(
                    value: true,
                    label: Text(
                      'Templates (${templates.items.length})',
                      maxLines: 1,
                    ),
                  ),
                ],
                selected: {_templates},
                onSelectionChanged: (value) =>
                    setState(() => _templates = value.single),
              ),
            ),
            const SizedBox(height: 16),
            if (listing.loading) const LinearProgressIndicator(),
            if (!listing.available)
              const Text('Connect a server to browse resources.')
            else if (!listing.loading &&
                listing.items.isEmpty &&
                listing.failure == null)
              Text(
                _templates ? 'This server has no templates.' : 'This server has no resources. Enter a URI below or refresh.',
              ),
            if (listing.items.isNotEmpty)
              SizedBox(
                height: (listing.items.length * 112.0).clamp(0, 240),
                child: ListView.builder(
                  itemCount: listing.items.length,
                  itemBuilder: (context, index) {
                    final item = listing.items[index];
                    return ListTile(
                      key: ValueKey((item.uri, index)),
                      selected: _uri.text == item.uri,
                      title: Text(
                        item.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.uri,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          if (item.description != null)
                            Text(
                              item.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          Text(
                            item.mimeType ?? 'Unknown MIME type',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                      onTap: running
                          ? null
                          : () => setState(() {
                              if (_templates) {
                                _selectTemplate(item.uri);
                              } else {
                                _manualUri();
                                _uri.text = item.uri;
                              }
                            }),
                    );
                  },
                ),
              ),
            if (listing.failure case final failure?) ...[
              Text(failure.message),
              if (listing.nextCursor != null || listing.items.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton(
                    onPressed: listing.loading
                        ? null
                        : () => ref
                              .read(mcpResourcesProvider(target).notifier)
                              .loadNext(),
                    child: const Text('Retry resource list'),
                  ),
                ),
            ] else if (listing.nextCursor != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: listing.loading
                      ? null
                      : () => ref
                            .read(mcpResourcesProvider(target).notifier)
                            .loadNext(),
                  icon: const Icon(Icons.expand_more),
                  label: const Text('Load next page'),
                ),
              ),
            const SizedBox(height: 24),
            if (_template case final template?)
              McpUriTemplateForm(
                template: template,
                values: _templateValues,
                enabled: active && !running,
                onChanged: (values) => setState(() => _expand(values)),
              ),
            if (_templateError case final error?)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(error),
              ),
            TextField(
              controller: _uri,
              enabled: active && !running,
              onChanged: (_) => setState(_manualUri),
              decoration: const InputDecoration(
                labelText: 'Resource URI',
                helperText: 'Review before reading. Editing this URI switches to manual input.',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: !active || running || _templateError != null
                    ? null
                    : _read,
                icon: const Icon(Icons.visibility_outlined),
                label: const Text('Read resource · Ctrl+Enter', maxLines: 1),
              ),
            ),
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
                      'Read result · ${work?.submitted ?? ''}',
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
                    tooltip: 'Clear resource result',
                    onPressed: () => ref
                        .read(mcpSessionWorkProvider(widget.serverId))
                        ?.resources
                        .clearResult(),
                    icon: const Icon(Icons.clear),
                  ),
                ],
              ),
              if (outcome case Err(:final failure))
                Text(failure.message)
              else ...[
                if (outcome.valueOrNull!.isEmpty)
                  const Text('This resource returned no content.'),
                for (final (index, contents) in outcome.valueOrNull!.indexed)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: McpResourceContentView(
                      key: ValueKey((outcome, index)),
                      contents: contents,
                      serverId: widget.serverId,
                    ),
                  ),
                McpJsonResult(
                  key: ObjectKey(outcome),
                  value: {
                    'contents': outcome.valueOrNull!
                        .map((item) => item.toJson())
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
