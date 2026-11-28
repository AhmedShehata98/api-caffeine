import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/ui/widgets/failure_snackbar.dart';

import '../models/mcp_server.dart';
import '../models/mcp_launch_trust.dart';
import '../providers/mcp_catalog_providers.dart';
import '../providers/mcp_session_providers.dart';

Future<McpServer?> showMcpServerDialog(
  BuildContext context, {
  McpServer? server,
}) => showDialog<McpServer>(
  context: context,
  builder: (_) => _ServerDialog(server),
);

class _ValueRow {
  _ValueRow(String key, String value, this.secret)
    : key = TextEditingController(text: key),
      value = TextEditingController(text: value);
  final TextEditingController key;
  final TextEditingController value;
  bool secret;
  void dispose() {
    key.dispose();
    value.dispose();
  }
}

class _ServerDialog extends ConsumerStatefulWidget {
  const _ServerDialog(this.server);
  final McpServer? server;
  @override
  ConsumerState<_ServerDialog> createState() => _ServerDialogState();
}

class _ServerDialogState extends ConsumerState<_ServerDialog> {
  final _form = GlobalKey<FormState>();
  late final McpAccessContext? _scope;
  @override
  void initState() {
    super.initState();
    _scope = ref.read(mcpSessionOwnerProvider).context;
  }
  late final _name = TextEditingController(text: widget.server?.draft.name);
  late final _command = TextEditingController(
    text: widget.server?.draft.command,
  );
  late final _url = TextEditingController(text: widget.server?.draft.url);
  late final _args = TextEditingController(
    text: jsonEncode(widget.server?.draft.args ?? []),
  );
  late final _cwd = TextEditingController(text: widget.server?.draft.cwd);
  late final _timeout = TextEditingController(
    text: widget.server?.draft.settings.timeoutSeconds?.toString(),
  );
  late McpTransport _transport =
      widget.server?.draft.transport ?? McpTransport.stdio;
  late McpProtocolEra _era =
      widget.server?.draft.settings.protocolEra ?? McpProtocolEra.legacy;
  late final _env = _rows(widget.server?.draft.env ?? {}, 'env.');
  late final _headers = _rows(widget.server?.draft.headers ?? {}, 'header.');
  bool _saving = false;
  List<_ValueRow> _rows(Map<String, String> values, String prefix) => [
    for (final entry in values.entries)
      _ValueRow(
        entry.key,
        entry.value,
        widget.server!.draft.secretKeys.contains('$prefix${entry.key}'),
      ),
  ];

  @override
  void dispose() {
    for (final controller in [_name, _command, _url, _args, _cwd, _timeout]) {
      controller.dispose();
    }
    for (final row in [..._env, ..._headers]) {
      row.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    final args = _transport == McpTransport.stdio
        ? jsonDecode(_args.text) as List
        : widget.server?.draft.args ?? <String>[];
    final draft = McpServerDraft(
      name: _name.text,
      transport: _transport,
      command: _transport == McpTransport.stdio ? _command.text : null,
      url: _transport == McpTransport.stdio ? null : _url.text,
      args: args.cast<String>(),
      cwd: _cwd.text,
      env: {for (final row in _env) row.key.text: row.value.text},
      headers: {for (final row in _headers) row.key.text: row.value.text},
      secretKeys: [
        for (final row in _env)
          if (row.secret) 'env.${row.key.text}',
        for (final row in _headers)
          if (row.secret) 'header.${row.key.text.toLowerCase()}',
      ],
      settings: McpServerSettings(
        protocolEra: _era,
        timeoutSeconds: int.tryParse(_timeout.text),
      ),
    );
    setState(() => _saving = true);
    final notifier = ref.read(mcpCatalogProvider.notifier);
    final overrides = {
      for (final row in _headers)
        if (!row.secret) row.key.text,
    };
    final result = widget.server == null
        ? await notifier.create(draft, confirmedPlaintextHeaders: overrides)
        : await notifier.save(
            widget.server!.copyWith(draft: draft),
            confirmedPlaintextHeaders: overrides,
          );
    if (!mounted) return;
    setState(() => _saving = false);
    switch (result) {
      case Success(:final value):
        Navigator.pop(context, value);
      case Err(:final failure):
        showFailureSnackBar(context, failure);
    }
  }

  Widget _values(
    String title,
    List<_ValueRow> rows, {
    required bool headers,
  }) => ExpansionTile(
    initiallyExpanded: headers
        ? _transport != McpTransport.stdio
        : _transport == McpTransport.stdio,
    tilePadding: EdgeInsets.zero,
    title: Text(title, maxLines: 1),
    children: [
      for (final row in rows)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: row.key,
                  enabled: !_saving,
                  decoration: const InputDecoration(labelText: 'Key'),
                  validator: (value) => value == null || value.trim().isEmpty
                      ? 'Required'
                      : rows
                                .where(
                                  (other) => headers
                                      ? other.key.text.trim().toLowerCase() ==
                                            value.trim().toLowerCase()
                                      : other.key.text == value,
                                )
                                .length >
                            1
                      ? 'Duplicate key'
                      : null,
                  onChanged: (value) {
                    if (headers && isMcpCredentialHeader(value)) {
                      setState(() => row.secret = true);
                    }
                  },
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: TextFormField(
                  controller: row.value,
                  enabled: !_saving,
                  obscureText: row.secret,
                  decoration: InputDecoration(
                    labelText: row.secret ? 'Secret value' : 'Value',
                    hintText:
                        widget
                                .server
                                ?.secretStates['${headers ? 'header.' : 'env.'}${row.key.text}'] ==
                            SecretValueState.missingOnDevice
                        ? 'Missing on this device'
                        : null,
                  ),
                ),
              ),
              IconButton(
                tooltip: row.secret
                    ? 'Stored on this device'
                    : 'Store as secret',
                onPressed:
                    _saving ||
                        (headers &&
                            row.secret &&
                            isMcpCredentialHeader(row.key.text))
                    ? null
                    : () => setState(() => row.secret = !row.secret),
                icon: Icon(row.secret ? Icons.lock_outline : Icons.lock_open),
              ),
              IconButton(
                tooltip: 'Remove value',
                onPressed: _saving
                    ? null
                    : () => setState(() {
                        rows.remove(row);
                        row.dispose();
                      }),
                icon: const Icon(Icons.close),
              ),
            ],
          ),
        ),
      Align(
        alignment: Alignment.centerLeft,
        child: TextButton.icon(
          onPressed: _saving
              ? null
              : () => setState(() => rows.add(_ValueRow('', '', true))),
          icon: const Icon(Icons.add),
          label: Text(headers ? 'Add header' : 'Add variable'),
        ),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    ref.listen(mcpSessionsProvider, (_, _) {
      if (_scope != null &&
          !ref.read(mcpSessionOwnerProvider).isAuthorized(_scope, '') &&
          mounted) {
        Navigator.pop(context);
      }
    });
    return AlertDialog(
      title: Text(widget.server == null ? 'Add MCP server' : 'Edit MCP server'),
      content: SizedBox(
        width: 640,
        child: Form(
          key: _form,
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextFormField(
                  controller: _name,
                  enabled: !_saving,
                  autofocus: true,
                  decoration: const InputDecoration(labelText: 'Server name'),
                  validator: (value) =>
                      value == null || value.trim().isEmpty ? 'Required' : null,
                ),
                const SizedBox(height: 16),
                DropdownButtonFormField<McpTransport>(
                  initialValue: _transport,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Transport'),
                  items: const [
                    DropdownMenuItem(
                      value: McpTransport.stdio,
                      child: Text('STDIO'),
                    ),
                    DropdownMenuItem(
                      value: McpTransport.http,
                      child: Text('Streamable HTTP'),
                    ),
                    DropdownMenuItem(
                      value: McpTransport.sse,
                      child: Text('SSE · Deprecated'),
                    ),
                  ],
                  onChanged: _saving
                      ? null
                      : (value) => setState(() => _transport = value!),
                ),
                const SizedBox(height: 16),
                if (_transport == McpTransport.stdio) ...[
                  TextFormField(
                    controller: _command,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Command',
                      hintText: 'dart',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _args,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Arguments (JSON array)',
                      hintText: '["server.dart"]',
                    ),
                    validator: (value) {
                      try {
                        final args = jsonDecode(value ?? '');
                        return args is List &&
                                args.every((arg) => arg is String)
                            ? null
                            : 'Use an array of strings';
                      } on FormatException {
                        return 'Invalid JSON';
                      }
                    },
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _cwd,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Working directory (optional)',
                    ),
                  ),
                ] else
                  TextFormField(
                    controller: _url,
                    enabled: !_saving,
                    decoration: const InputDecoration(
                      labelText: 'Server URL',
                      hintText: 'https://example.com/mcp',
                    ),
                    validator: (value) => value == null || value.trim().isEmpty
                        ? 'Required'
                        : null,
                  ),
                if (_transport == McpTransport.sse)
                  const Padding(
                    padding: EdgeInsets.only(top: 8),
                    child: Text(
                      'Deprecated HTTP+SSE transport. Use Legacy protocol mode.',
                    ),
                  ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<McpProtocolEra>(
                        initialValue: _era,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Protocol era',
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: McpProtocolEra.legacy,
                            child: Text('Legacy'),
                          ),
                          DropdownMenuItem(
                            value: McpProtocolEra.auto,
                            child: Text('Auto'),
                          ),
                          DropdownMenuItem(
                            value: McpProtocolEra.modern,
                            child: Text('Modern'),
                          ),
                        ],
                        onChanged: _saving
                            ? null
                            : (value) => setState(() => _era = value!),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: TextFormField(
                        controller: _timeout,
                        enabled: !_saving,
                        decoration: const InputDecoration(
                          labelText: 'Timeout (seconds)',
                          hintText: 'Use app setting',
                        ),
                        keyboardType: TextInputType.number,
                        validator: (value) =>
                            value == null ||
                                value.isEmpty ||
                                (int.tryParse(value) ?? 0) > 0
                            ? null
                            : 'Use a positive number',
                      ),
                    ),
                  ],
                ),
                _values('Environment variables', _env, headers: false),
                _values('Headers', _headers, headers: true),
                const SizedBox(height: 8),
                const Text(
                  'Secret values stay on this device. Saving never connects or launches a server.',
                ),
              ],
            ),
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _saving ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save server'),
        ),
      ],
    );
  }
}
