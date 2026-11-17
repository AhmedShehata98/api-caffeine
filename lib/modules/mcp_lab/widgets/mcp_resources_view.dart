import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/result.dart';

import '../providers/mcp_resources_provider.dart';
import '../providers/mcp_work_providers.dart';
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
  @override
  void initState() {
    super.initState();
    _uri.addListener(_persist);
  }

  void _persist() => ref
      .read(mcpSessionWorkProvider(widget.serverId))
      ?.resources
      .setDraft(_uri.text);
  Future<void> _read() async {
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
      if (next == null) _uri.clear();
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
                          : () => setState(() => _uri.text = item.uri),
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
            TextField(
              controller: _uri,
              enabled: active && !running,
              decoration: const InputDecoration(
                labelText: 'Resource URI',
                helperText: 'For templates, replace expressions with a resolved URI before reading.',
              ),
            ),
            const SizedBox(height: 16),
            Align(
              alignment: Alignment.centerLeft,
              child: FilledButton.icon(
                onPressed: !active || running ? null : _read,
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
