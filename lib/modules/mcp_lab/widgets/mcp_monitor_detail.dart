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
  late final _editors = {
    for (final side
        in widget.entry.network == null
            ? [McpNetworkBodySide.response]
            : McpNetworkBodySide.values)
      side: CodeLineEditingController.fromText(widget.entry.bodyFor(side).text),
  };
  final _loadingBodies = <McpNetworkBodySide>{};
  final _fullBodies = <McpNetworkBodySide>{};
  final _messages = <McpNetworkBodySide, String>{};
  McpNetworkBodySide _side = McpNetworkBodySide.response;
  String _pane = 'responseBody';
  bool get _loading => _loadingBodies.contains(_side);
  bool get _full => _fullBodies.contains(_side);
  String? get _message => _messages[_side];
  bool get _showBody => _pane.endsWith('Body');

  Future<void> _copy() async {
    final side = _side;
    final result = widget.actions.copy(
      widget.kind,
      widget.entry.sequence,
      side: side,
    );
    if (!result.isSuccess) {
      setState(() => _messages[side] = result.failureOrNull!.message);
      return;
    }
    try {
      await Clipboard.setData(ClipboardData(text: result.valueOrNull!));
      if (mounted) {
        setState(() => _messages[side] = 'Copied sanitized capture.');
      }
    } on Object {
      if (mounted) {
        setState(() => _messages[side] = 'Could not copy this capture.');
      }
    }
  }

  Future<void> _load() async {
    final side = _side;
    setState(() {
      _loadingBodies.add(side);
      _messages.remove(side);
    });
    final result = await widget.actions.loadFull(
      widget.kind,
      widget.entry,
      side: side,
    );
    if (!mounted) return;
    setState(() {
      _loadingBodies.remove(side);
      if (result.isSuccess) {
        _editors[side]!.text = result.valueOrNull!;
        _fullBodies.add(side);
      } else {
        _messages[side] = result.failureOrNull!.message;
      }
    });
  }

  @override
  void dispose() {
    for (final editor in _editors.values) {
      editor.dispose();
    }
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
    final body = entry.bodyFor(_side);
    final bodyName = _side == McpNetworkBodySide.request
        ? 'request'
        : 'response';
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
            if (_showBody) Text('${body.size} bytes', maxLines: 1),
            if (entry.frame?.redacted == true)
              const Chip(label: Text('Redacted', maxLines: 1)),
            if (entry.duration != null || network != null)
              Text(
                '${(entry.duration ?? network!.duration).inMilliseconds} ms',
                maxLines: 1,
              ),
            if (_showBody)
              TextButton.icon(
                onPressed: _copy,
                icon: const Icon(Icons.copy, size: 16),
                label: Text(
                  network == null
                      ? (body.fullAvailable
                            ? 'Copy capture'
                            : 'Copy retained body')
                      : (body.fullAvailable
                            ? 'Copy $bodyName body'
                            : 'Copy retained $bodyName body'),
                  maxLines: 1,
                ),
              ),
            if (_showBody && body.truncated && body.fullAvailable && !_full)
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
        if (_showBody && body.truncated)
          Text(
            body.fullAvailable
                ? (_full
                      ? 'Full retained capture loaded.'
                      : 'Truncated preview · ${body.size} bytes retained')
                : 'Partial transport body · the complete body was not retained.',
          ),
        if (_showBody && _message != null) Text(_message!),
        if (_showBody && _loading) const LinearProgressIndicator(),
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
                ButtonSegment(
                  value: 'requestBody',
                  label: Text('Request body'),
                ),
                ButtonSegment(
                  value: 'responseBody',
                  label: Text('Response body'),
                ),
                ButtonSegment(value: 'request', label: Text('Request headers')),
                ButtonSegment(
                  value: 'response',
                  label: Text('Response headers'),
                ),
              ],
              selected: {_pane},
              onSelectionChanged: (value) => setState(() {
                _pane = value.single;
                if (_pane == 'requestBody') _side = McpNetworkBodySide.request;
                if (_pane == 'responseBody') {
                  _side = McpNetworkBodySide.response;
                }
              }),
            ),
          ),
          const SizedBox(height: 8),
        ],
        Expanded(
          child: network != null && !_showBody
              ? _headers(
                  _pane == 'request'
                      ? network.requestHeaders
                      : network.responseHeaders,
                )
              : network != null && body.size == 0
              ? Center(child: Text('No $bodyName body captured.'))
              : CodeView(
                  controller: _editors[_side]!,
                  readOnly: true,
                  highlightJson: widget.kind != McpMonitorKind.console,
                ),
        ),
      ],
    );
  }
}
