import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/ui/theme/http_colors.dart';

import '../models/mcp_diagnostics.dart';
import '../providers/mcp_diagnostic_providers.dart';
import '../providers/mcp_connection_status_provider.dart';
import '../services/mcp_diagnostic_buffer.dart';
import '../services/mcp_monitor_presentation.dart';
import 'mcp_monitor_detail.dart';

class McpMonitorView extends ConsumerStatefulWidget {
  const McpMonitorView({required this.serverId, required this.kind, super.key});
  final String serverId;
  final McpMonitorKind kind;
  @override
  ConsumerState<McpMonitorView> createState() => _McpMonitorViewState();
}

class _McpMonitorViewState extends ConsumerState<McpMonitorView> {
  final _filter = TextEditingController();
  final _focus = FocusNode();
  int? _selected;
  RpcDirection? _direction;
  RpcFrameKind? _frameKind;
  @override
  void dispose() {
    _filter.dispose();
    _focus.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final diagnostic = ref.watch(mcpDiagnosticsProvider(widget.serverId));
    final snapshot = ref.watch(mcpCurrentDiagnosticsProvider(widget.serverId));
    final actions = ref.watch(mcpMonitorActionsProvider(widget.serverId));
    final status = ref
        .watch(mcpConnectionStatusProvider(widget.serverId))
        .value;
    final rows = ref.watch(
      mcpMonitorRowsProvider((
        id: widget.serverId,
        kind: widget.kind,
        text: _filter.text,
        direction: _direction,
        frameKind: _frameKind,
      )),
    );
    final all =
        switch (widget.kind) {
          McpMonitorKind.protocol => snapshot?.protocol,
          McpMonitorKind.network => snapshot?.network,
          McpMonitorKind.console => snapshot?.console,
        } ??
        const <McpMonitorEntry>[];
    final dropped =
        switch (widget.kind) {
          McpMonitorKind.protocol => snapshot?.protocolDropped,
          McpMonitorKind.network => snapshot?.networkDropped,
          McpMonitorKind.console => snapshot?.consoleDropped,
        } ??
        0;
    final selected = all
        .where((entry) => entry.sequence == _selected)
        .firstOrNull;
    final title = switch (widget.kind) {
      McpMonitorKind.protocol => 'Protocol',
      McpMonitorKind.network => 'Network',
      McpMonitorKind.console => 'Console',
    };
    final list = rows.isEmpty
        ? Center(
            child: Text(
              all.isEmpty
                  ? 'No captures yet. Run an operation to see diagnostics.'
                  : 'No captures match this filter.',
            ),
          )
        : ListView.builder(
            key: ValueKey(widget.kind),
            itemCount: rows.length,
            itemExtent: 76,
            itemBuilder: (context, index) {
              final entry = rows[index];
              final frame = entry.frame;
              final timestamp = frame?.timestamp ?? entry.console?.timestamp;
              return ListTile(
                key: ValueKey(entry.sequence),
                selected: _selected == entry.sequence,
                leading: frame?.kind == RpcFrameKind.warning
                    ? Icon(
                        Icons.warning_amber,
                        color:
                            Theme.of(context)
                                .extension<HttpColors>()
                                ?.status4xx ??
                            Theme.of(context).colorScheme.tertiary,
                      )
                    : Icon(
                        widget.kind == McpMonitorKind.console
                            ? Icons.terminal
                            : Icons.swap_horiz,
                      ),
                title: Text(
                  mcpMonitorTitle(entry),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                subtitle: Text(
                  [
                    '#${entry.sequence}',
                    if (timestamp != null)
                      timestamp.toLocal().toIso8601String(),
                    if (frame != null) frame.kind.name,
                    if (entry.network case final network?)
                      '${network.status ?? 'No status'} · ${network.duration.inMilliseconds} ms',
                    if (entry.duration case final duration?)
                      '${duration.inMilliseconds} ms',
                    if (entry.pairedSequence case final pair?) 'paired #$pair',
                  ].join(' · '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                onTap: () => setState(() => _selected = entry.sequence),
              );
            },
          );
    final detail = selected == null
        ? const Center(child: Text('Select a capture to inspect it.'))
        : McpMonitorDetail(
            key: ValueKey((widget.kind, selected.sequence)),
            kind: widget.kind,
            entry: selected,
            actions: actions,
            onPair: (sequence) => setState(() => _selected = sequence),
          );
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyF, control: true): () =>
            _focus.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 16,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleLarge),
                  Text('${rows.length} / ${all.length} captures', maxLines: 1),
                  if (status case ConnectionConnected(:final era))
                    Chip(label: Text('${era.name} era', maxLines: 1)),
                  TextButton.icon(
                    onPressed: snapshot == null
                        ? null
                        : () {
                            actions.clear(widget.kind);
                            setState(() => _selected = null);
                          },
                    icon: const Icon(Icons.clear_all),
                    label: const Text('Clear captures'),
                  ),
                ],
              ),
              if (diagnostic.hasError)
                const Text('Could not observe diagnostic updates.'),
              if (snapshot == null)
                const Text('No diagnostics are retained for this session.'),
              if (dropped > 0)
                Text('$dropped older entries dropped', maxLines: 1),
              if ((snapshot?.streamErrors ?? 0) > 0)
                Text(
                  '${snapshot!.streamErrors} diagnostic stream errors',
                  maxLines: 1,
                ),
              TextField(
                controller: _filter,
                focusNode: _focus,
                maxLength: 256,
                decoration: const InputDecoration(
                  labelText: 'Filter captures',
                  hintText: 'Method, id, URL or console line · Ctrl+F',
                  counterText: '',
                ),
                onChanged: (_) => setState(() {}),
              ),
              if (widget.kind == McpMonitorKind.protocol)
                Wrap(
                  spacing: 16,
                  children: [
                    DropdownButton<RpcDirection>(
                      value: _direction,
                      hint: const Text('All directions'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All directions'),
                        ),
                        for (final direction in RpcDirection.values)
                          DropdownMenuItem(
                            value: direction,
                            child: Text(direction.name),
                          ),
                      ],
                      onChanged: (value) => setState(() => _direction = value),
                    ),
                    DropdownButton<RpcFrameKind>(
                      value: _frameKind,
                      hint: const Text('All frame kinds'),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All frame kinds'),
                        ),
                        for (final kind in RpcFrameKind.values)
                          DropdownMenuItem(value: kind, child: Text(kind.name)),
                      ],
                      onChanged: (value) => setState(() => _frameKind = value),
                    ),
                  ],
                ),
              const SizedBox(height: 12),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) =>
                      constraints.maxWidth >= 1000
                      ? Row(
                          children: [
                            Expanded(child: list),
                            const VerticalDivider(width: 24),
                            Expanded(child: detail),
                          ],
                        )
                      : Column(
                          children: [
                            SizedBox(
                              height: constraints.maxHeight * 0.35,
                              child: list,
                            ),
                            const Divider(height: 24),
                            Expanded(child: detail),
                          ],
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
