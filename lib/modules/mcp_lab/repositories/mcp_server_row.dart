import '../models/mcp_server.dart';

/// Database rows are flat snake_case; domain drafts are nested camelCase.
McpServer mcpServerFromRow(Map<String, dynamic> row) {
  final secretKeys = (row['secret_keys'] as List).cast<String>();
  return McpServer(
    id: row['id'] as String,
    workspaceId: row['workspace_id'] as String,
    position: row['position'] as int?,
    draft: McpServerDraft.fromJson({
      'name': row['name'],
      'transport': row['transport'],
      'command': row['command'],
      'url': row['url'],
      'args': row['args'],
      'cwd': row['cwd'],
      'env': row['env'],
      'headers': row['headers'],
      'secretKeys': secretKeys,
      'settings': row['settings'],
    }),
    // A synced placeholder is never proof that a credential exists locally.
    secretStates: {
      for (final key in secretKeys) key: SecretValueState.missingOnDevice,
    },
  );
}

Map<String, dynamic> mcpServerValues(McpServerDraft draft) => {
  'name': draft.name,
  'transport': draft.transport.name,
  'command': draft.command,
  'url': draft.url,
  'args': draft.args,
  'cwd': draft.cwd,
  // Defence in depth: secret values cannot be written even if a caller passes
  // a hydrated draft directly instead of using the catalog service.
  'env': {
    for (final entry in draft.env.entries)
      entry.key: draft.secretKeys.contains('env.${entry.key}')
          ? ''
          : entry.value,
  },
  'headers': {
    for (final entry in draft.headers.entries)
      entry.key: draft.secretKeys.contains('header.${entry.key}')
          ? ''
          : entry.value,
  },
  'secret_keys': draft.secretKeys,
  'settings': draft.settings.toJson(),
};
