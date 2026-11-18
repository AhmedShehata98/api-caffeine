import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/ui/theme/app_fonts.dart';
import 'package:test_point/core/ui/theme/http_colors.dart';
import 'package:test_point/core/ui/widgets/confirm_dialog.dart';
import 'package:test_point/core/ui/widgets/failure_snackbar.dart';
import 'package:test_point/core/ui/widgets/resizable_split_pane.dart';

import '../models/mcp_server.dart';
import '../models/mcp_diagnostics.dart';
import '../models/mcp_failure.dart';
import '../providers/mcp_catalog_providers.dart';
import '../providers/mcp_session_providers.dart';
import '../providers/mcp_connection_status_provider.dart';
import '../providers/mcp_primitive_providers.dart';
import '../widgets/mcp_tools_view.dart';
import '../widgets/mcp_prompts_view.dart';
import '../widgets/mcp_resources_view.dart';
import '../widgets/mcp_monitor_view.dart';
import '../services/mcp_diagnostic_buffer.dart';
import '../services/mcp_connect_service.dart';
import '../services/mcp_approval_summary.dart';
import '../widgets/mcp_approval_dialog.dart';
import '../widgets/mcp_server_dialog.dart';

class McpLabScreen extends ConsumerStatefulWidget {
  const McpLabScreen({super.key});
  @override
  ConsumerState<McpLabScreen> createState() => _McpLabScreenState();
}

class _McpLabScreenState extends ConsumerState<McpLabScreen> {
  final _filter = TextEditingController();
  final _filterFocus = FocusNode();
  final _busy = <String>{};
  String _view = 'settings';
  @override
  void dispose() {
    _filter.dispose();
    _filterFocus.dispose();
    super.dispose();
  }

  Future<void> _edit([McpServer? server]) async {
    final saved = await showMcpServerDialog(context, server: server);
    if (mounted && saved != null) {
      ref.read(mcpSelectedServerProvider.notifier).select(saved.id);
    }
  }

  Future<void> _delete(McpServer server) async {
    final scope = ref.read(mcpSessionOwnerProvider).context;
    final confirmed = await showConfirmDialog(
      context,
      title: 'Delete MCP server',
      message:
          'Disconnect and delete "${server.draft.name}" from this workspace?',
      confirmLabel: 'Delete',
      destructive: true,
    );
    if (!confirmed ||
        !mounted ||
        scope == null ||
        !ref.read(mcpSessionOwnerProvider).isAuthorized(scope, server.id)) {
      return;
    }
    final result = await ref
        .read(mcpCatalogProvider.notifier)
        .delete(server.id);
    if (result case Err(:final failure) when mounted) {
      showFailureSnackBar(context, failure);
    }
  }

  Future<void> _connect(McpServer server) async {
    final owner = ref.read(mcpSessionOwnerProvider);
    final scope = owner.context;
    if (scope == null) return;
    setState(() => _busy.add(server.id));
    try {
      final current = owner.state.sessions[server.id];
      if (current is McpConnected) {
        final stopped = await owner.disconnect(server.id);
        if (stopped case Err(:final failure)) {
          if (mounted) showFailureSnackBar(context, failure);
          return;
        }
      }
      if (!mounted || !owner.isAuthorized(scope, server.id)) return;
      final result = current is McpNeedsApproval
          ? Result<McpConnectOutcome>.success(current)
          : await ref.read(mcpSessionActionsProvider).connect(server.id);
      if (!mounted || !owner.isAuthorized(scope, server.id)) return;
      if (result case Err(:final failure)) {
        showFailureSnackBar(context, failure);
        return;
      }
      if (result.valueOrNull case final McpNeedsApproval ticket) {
        final remember = await showMcpApprovalDialog(context, ticket);
        if (!mounted || !owner.isAuthorized(scope, server.id)) return;
        if (remember == null) {
          await owner.disconnect(server.id);
          return;
        }
        final approved = await ref
            .read(mcpSessionActionsProvider)
            .approve(server.id, remember: remember);
        if (approved case Err(:final failure) when mounted) {
          showFailureSnackBar(context, failure);
        }
        if (approved.valueOrNull case McpConnected(:final rememberFailure)
            when mounted && rememberFailure != null) {
          showFailureSnackBar(context, rememberFailure);
        }
      }
    } finally {
      if (mounted) setState(() => _busy.remove(server.id));
    }
  }

  Future<void> _disconnect(String id) async {
    setState(() => _busy.add(id));
    final result = await ref.read(mcpSessionOwnerProvider).disconnect(id);
    if (!mounted) return;
    setState(() => _busy.remove(id));
    if (result case Err(:final failure)) showFailureSnackBar(context, failure);
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(mcpLifecycleProvider);
    final catalog = ref.watch(mcpCatalogProvider);
    final selected = ref.watch(mcpSelectedServerProvider);
    final rows = catalog.value ?? const <McpServer>[];
    final server = rows.where((row) => row.id == selected).firstOrNull;
    final scheme = Theme.of(context).colorScheme;
    final query = _filter.text.toLowerCase();
    final filtered = rows
        .where((row) => row.draft.name.toLowerCase().contains(query))
        .toList();
    final ready = ref.watch(mcpAccessContextProvider) != null;
    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            _filterFocus.requestFocus(),
      },
      child: Focus(
        autofocus: true,
        child: ResizableSplitPane(
          axis: Axis.horizontal,
          initialRatio: 0.25,
          minFirstSize: 240,
          minSecondSize: 400,
          first: Material(
            color: scheme.surfaceContainer,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'MCP servers',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh servers',
                        onPressed: catalog.isLoading
                            ? null
                            : () => ref
                                  .read(mcpCatalogProvider.notifier)
                                  .reload(),
                        icon: const Icon(Icons.refresh),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _filter,
                    focusNode: _filterFocus,
                    onChanged: (_) => setState(() {}),
                    decoration: const InputDecoration(
                      labelText: 'Filter servers',
                      hintText: 'Ctrl+K',
                      prefixIcon: Icon(Icons.search),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: ready && !catalog.isLoading
                        ? () => _edit()
                        : null,
                    icon: const Icon(Icons.add),
                    label: const Text('Add server', maxLines: 1),
                  ),
                  const SizedBox(height: 16),
                  if (catalog.isLoading) const LinearProgressIndicator(),
                  if (catalog.hasError)
                    Padding(
                      padding: const EdgeInsets.all(8),
                      child: Column(
                        children: [
                          const Text('Could not load servers.'),
                          TextButton(
                            onPressed: () =>
                                ref.read(mcpCatalogProvider.notifier).reload(),
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  Expanded(
                    child:
                        filtered.isEmpty &&
                            !catalog.isLoading &&
                            !catalog.hasError
                        ? Center(
                            child: Text(
                              query.isEmpty
                                  ? 'No servers yet'
                                  : 'No matching servers',
                            ),
                          )
                        : ListView.builder(
                            itemCount: filtered.length,
                            itemBuilder: (context, index) {
                              final row = filtered[index];
                              final status = ref
                                  .watch(mcpConnectionStatusProvider(row.id))
                                  .value;
                              final connected = status is ConnectionConnected;
                              final authNeeded =
                                  status is ConnectionDisconnected &&
                                  status.failure?.code ==
                                      McpErrorCode.authRequired;
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: ListTile(
                                  minLeadingWidth: 12,
                                  horizontalTitleGap: 8,
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 12,
                                  ),
                                  selected: row.id == selected,
                                  selectedTileColor: scheme.primary.withValues(
                                    alpha: 0.12,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  leading: Icon(
                                    Icons.circle,
                                    size: 8,
                                    semanticLabel: connected
                                        ? 'Connected'
                                        : authNeeded
                                        ? 'Auth needed'
                                        : 'Idle',
                                    color: connected
                                        ? context.httpColors.status2xx
                                        : authNeeded
                                        ? context.httpColors.status4xx
                                        : scheme.onSurfaceVariant,
                                  ),
                                  title: Text(
                                    row.draft.name,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  trailing: SizedBox(
                                    width: 52,
                                    child: Text(
                                      row.draft.transport.name.toUpperCase(),
                                      maxLines: 1,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: AppFonts.mono,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                  onTap: () => ref
                                      .read(mcpSelectedServerProvider.notifier)
                                      .select(row.id),
                                ),
                              );
                            },
                          ),
                  ),
                  Text(
                    '${rows.length} ${rows.length == 1 ? 'server' : 'servers'}',
                    maxLines: 1,
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
          ),
          second: server == null
              ? Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.hub_outlined, size: 48, color: scheme.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Your MCP workspace',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Add a server or select one to review its connection settings.',
                      ),
                    ],
                  ),
                )
              : _details(server),
        ),
      ),
    );
  }

  Widget _details(McpServer server) {
    final services = ref.watch(mcpPrimitiveServicesProvider(server.id));
    final monitor = ref
        .watch(mcpSessionsProvider)
        .value
        ?.diagnostics[server.id];
    if (monitor == null &&
        (services == null ||
            (!services.supports('tools') &&
                !services.supports('prompts') &&
                !services.supports('resources')))) {
      return _settingsDetails(server);
    }
    final transportView = server.draft.transport == McpTransport.stdio
        ? 'console'
        : 'network';
    final view =
        _view == 'settings' ||
            (services?.supports(_view) ?? false) ||
            (monitor != null && (_view == 'protocol' || _view == transportView))
        ? _view
        : 'settings';
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
          child: Row(
            children: [
              if (view != 'settings')
                Expanded(
                  child: Text(
                    server.draft.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                ),
              Flexible(
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: SegmentedButton<String>(
                    segments: [
                      const ButtonSegment(
                        value: 'settings',
                        label: Text('Settings'),
                      ),
                      if (services?.supports('tools') ?? false)
                        const ButtonSegment(
                          value: 'tools',
                          label: Text('Tools'),
                        ),
                      if (services?.supports('prompts') ?? false)
                        const ButtonSegment(
                          value: 'prompts',
                          label: Text('Prompts'),
                        ),
                      if (services?.supports('resources') ?? false)
                        const ButtonSegment(
                          value: 'resources',
                          label: Text('Resources'),
                        ),
                      if (monitor != null) ...[
                        const ButtonSegment(
                          value: 'protocol',
                          label: Text('Protocol'),
                        ),
                        ButtonSegment(
                          value: transportView,
                          label: Text(
                            transportView == 'console' ? 'Console' : 'Network',
                          ),
                        ),
                      ],
                    ],
                    selected: {view},
                    onSelectionChanged: (selection) =>
                        setState(() => _view = selection.single),
                  ),
                ),
              ),
              if (view != 'settings')
                IconButton(
                  tooltip: 'Disconnect',
                  onPressed: _busy.contains(server.id)
                      ? null
                      : () => _disconnect(server.id),
                  icon: const Icon(Icons.link_off),
                ),
            ],
          ),
        ),
        Expanded(
          child: switch (view) {
            'tools' => McpToolsView(
              key: ObjectKey(services),
              serverId: server.id,
              onOpenResources: () => setState(() => _view = 'resources'),
            ),
            'prompts' => McpPromptsView(
              key: ObjectKey(services),
              serverId: server.id,
              onOpenResources: () => setState(() => _view = 'resources'),
            ),
            'resources' => McpResourcesView(
              key: ObjectKey(services),
              serverId: server.id,
            ),
            'protocol' || 'network' || 'console' => McpMonitorView(
              key: ValueKey((monitor, view)),
              serverId: server.id,
              kind: view == 'protocol'
                  ? McpMonitorKind.protocol
                  : view == 'network'
                  ? McpMonitorKind.network
                  : McpMonitorKind.console,
            ),
            _ => _settingsDetails(server),
          },
        ),
      ],
    );
  }

  Widget _settingsDetails(McpServer server) {
    final status = ref.watch(mcpConnectionStatusProvider(server.id)).value;
    final active = status is ConnectionConnected;
    final authNeeded =
        status is ConnectionDisconnected &&
        status.failure?.code == McpErrorCode.authRequired;
    final busy = _busy.contains(server.id);
    final draft = server.draft;
    final scheme = Theme.of(context).colorScheme;
    Widget section(String title, List<(String, String)> fields) => Card(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 20),
            for (final field in fields)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      field.$1,
                      maxLines: 1,
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(height: 4),
                    SelectableText(
                      maskMcpServerText(server, field.$2),
                      style: const TextStyle(fontFamily: AppFonts.mono),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
    return ListView(
      padding: const EdgeInsets.all(24),
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                draft.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
            ),
            const SizedBox(width: 16),
            FilledButton.icon(
              onPressed: busy
                  ? null
                  : () => active ? _disconnect(server.id) : _connect(server),
              icon: Icon(active ? Icons.link_off : Icons.link),
              label: Text(
                busy
                    ? 'Working…'
                    : active
                    ? 'Disconnect'
                    : 'Connect',
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Chip(
              avatar: Icon(
                active ? Icons.check_circle_outline : Icons.circle_outlined,
                size: 16,
              ),
              label: Text(
                active
                    ? 'Connected'
                    : authNeeded
                    ? 'Auth needed'
                    : status is ConnectionDisconnected
                    ? 'Disconnected'
                    : 'Idle',
                maxLines: 1,
              ),
            ),
            Chip(
              label: Text(
                'Era: ${active ? status.era.name : draft.settings.protocolEra.name}',
                maxLines: 1,
              ),
            ),
            TextButton.icon(
              onPressed: busy ? null : () => _edit(server),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit server'),
            ),
            TextButton.icon(
              onPressed: busy ? null : () => _delete(server),
              icon: Icon(Icons.delete_outline, color: scheme.error),
              label: const Text('Delete'),
            ),
          ],
        ),
        const SizedBox(height: 24),
        Text('Settings', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        section('Connection', [
          (
            'Transport',
            draft.transport == McpTransport.stdio
                ? 'STDIO'
                : draft.transport == McpTransport.http
                ? 'Streamable HTTP'
                : 'SSE · Deprecated',
          ),
          if (draft.command != null) ('Command', draft.command!),
          if (draft.url != null) ('URL', draft.url!),
          if (draft.args.isNotEmpty) ('Arguments', jsonEncode(draft.args)),
          if (draft.cwd != null) ('Working directory', draft.cwd!),
        ]),
        section('Protocol', [
          ('Protocol era', draft.settings.protocolEra.name),
          (
            'Timeout',
            draft.settings.timeoutSeconds == null
                ? 'App setting'
                : '${draft.settings.timeoutSeconds} seconds',
          ),
        ]),
        section('Device secrets', [
          ('Environment keys', draft.env.keys.join(', ')),
          ('Header keys', draft.headers.keys.join(', ')),
          (
            'Secret storage',
            'Values stay on this device. ${server.secretStates.values.where((state) => state == SecretValueState.missingOnDevice).length} missing on this device.',
          ),
        ]),
        if (active)
          section('Connection info', [
            ('Server', '${status.serverInfo['name'] ?? draft.name}'),
            ('Version', '${status.serverInfo['version'] ?? 'Not provided'}'),
          ]),
      ],
    );
  }
}
