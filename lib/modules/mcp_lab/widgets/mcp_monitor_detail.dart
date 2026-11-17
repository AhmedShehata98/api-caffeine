import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:re_editor/re_editor.dart';
import 'package:test_point/core/ui/widgets/code_view.dart';

import '../providers/mcp_diagnostic_providers.dart';
import '../services/mcp_diagnostic_buffer.dart';
import '../services/mcp_monitor_presentation.dart';

class McpMonitorDetail extends StatefulWidget {
  const McpMonitorDetail({
    required this.kind,
    required this.entry,
    required this.actions,
    required this.onPair,
    super.key,
  });
  final McpMonitorKind kind;
  final McpMonitorEntry entry;
  final McpMonitorActions actions;
  final ValueChanged<int> onPair;
  @override
  State<McpMonitorDetail> createState() => _McpMonitorDetailState();
}

class _McpMonitorDetailState extends State<McpMonitorDetail> {
  late final _editor = CodeLineEditingController.fromText(widget.entry.text);
  bool _loading = false;
  bool _full = false;
  String _pane = 'body';
  String? _message;
  Future<void> _copy() async {
    final result = widget.actions.copy(widget.kind, widget.entry.sequence);
    if (!result.isSuccess) {
      setState(() => _message = result.failureOrNull!.message);
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: result.valueOrNull!));
      if (mounted) setState(() => _message = 'Copied sanitized capture.');
    } on Object {
      if (mounted) setState(() => _message = 'Could not copy this capture.');
    }
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _message = null;
    });
    final result = await widget.actions.loadFull(widget.kind, widget.entry);
    if (!mounted) return;
    setState(() {
      _loading = false;
      if (result.isSuccess) {
        _editor.text = result.valueOrNull!;
        _full = true;
      } else {
        _message = result.failureOrNull!.message;
      }
    });
  }

  @override
  void dispose() {
    _editor.dispose();
    super.dispose();
  }

  Widget _headers(Map<String, List<String>> headers) {
    final entries = headers.entries.toList();
    if (entries.isEmpty) {
      return const Center(child: Text('No headers captured.'));
    }
    return ListView.builder(
      itemCount: entries.length,
      itemBuilder: (context, index) {
        final header = entries[index];
        final value = header.value.map(mcpDiagnosticHeaderDisplay).join('\n');
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                header.key,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: header.key.toLowerCase().startsWith('mcp-')
                      ? Theme.of(context).colorScheme.primary
                      : null,
                ),
              ),
              SelectableText(
                value.length > 4096 ? '${value.substring(0, 4096)}…' : value,
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final entry = widget.entry;
    final network = entry.network;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Capture #${entry.sequence}',
          style: Theme.of(context).textTheme.titleMedium,
          maxLines: 1,
        ),
        Wrap(
          spacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            const Text('Sanitized capture', maxLines: 1),
            Text('${entry.size} bytes', maxLines: 1),
            if (entry.frame?.redacted == true)
              const Chip(label: Text('Redacted', maxLines: 1)),
            if (entry.duration != null || network != null)
              Text(
                '${(entry.duration ?? network!.duration).inMilliseconds} ms',
                maxLines: 1,
              ),
            TextButton.icon(
              onPressed: _copy,
              icon: const Icon(Icons.copy, size: 16),
              label: Text(
                entry.fullAvailable ? 'Copy capture' : 'Copy retained body',
                maxLines: 1,
              ),
            ),
            if (entry.truncated && entry.fullAvailable && !_full)
              TextButton(
                onPressed: _loading ? null : _load,
                child: const Text('Load full', maxLines: 1),
              ),
            if (entry.pairedSequence case final pair?)
              TextButton(
                onPressed: () => widget.onPair(pair),
                child: Text('View paired frame #$pair', maxLines: 1),
              ),
          ],
        ),
        if (entry.truncated)
          Text(
            entry.fullAvailable
                ? (_full
                      ? 'Full retained capture loaded.'
                      : 'Truncated preview · ${entry.size} bytes retained')
                : 'Partial transport body · the complete body was not retained.',
          ),
        if (_message != null) Text(_message!),
        if (_loading) const LinearProgressIndicator(),
        if (network != null) ...[
          Text(
            '${network.method} · ${network.status ?? 'No status'} · ${network.url}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 8),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'body', label: Text('Body')),
                ButtonSegment(value: 'request', label: Text('Request headers')),
                ButtonSegment(
                  value: 'response',
                  label: Text('Response headers'),
                ),
              ],
              selected: {_pane},
              onSelectionChanged: (value) =>
                  setState(() => _pane = value.single),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: network != null && _pane != 'body'
              ? _headers(
                  _pane == 'request'
                      ? network.requestHeaders
                      : network.responseHeaders,
                )
              : CodeView(
                  controller: _editor,
                  readOnly: true,
                  highlightJson: widget.kind != McpMonitorKind.console,
                ),
        ),
      ],
    );
  }
}
