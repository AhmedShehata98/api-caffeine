import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/mcp_launch_trust.dart';

McpTrustRecord digestMcpLaunch({
  required List<int> deviceKey,
  required McpAccessContext context,
  required String serverId,
  required McpLaunchSnapshot snapshot,
}) {
  if (deviceKey.length != 32) {
    throw ArgumentError('Launch trust requires a 256-bit device key.');
  }
  final fields = <String, Object>{
    'command': snapshot.command,
    'executable': snapshot.executable,
    'cwd': snapshot.cwd,
    'args': snapshot.args,
    for (final entry in snapshot.environment.entries)
      'env.${entry.key}': entry.value,
  };
  final names = fields.keys.toList()..sort();
  final hmac = Hmac(sha256, deviceKey);
  return McpTrustRecord({
    for (final name in names)
      name: hmac
          .convert(
            utf8.encode(
              jsonEncode([
                1,
                context.userId,
                context.workspaceId,
                serverId,
                name,
                fields[name],
              ]),
            ),
          )
          .toString(),
  });
}

McpTrustCheck compareMcpTrust(McpTrustRecord? stored, McpTrustRecord current) {
  if (stored == null) return McpTrustCheck(approved: false);
  final names = {...stored.fields.keys, ...current.fields.keys}.toList()
    ..sort();
  final changed = names
      .where((name) => stored.fields[name] != current.fields[name])
      .toList();
  return McpTrustCheck(approved: changed.isEmpty, changedFields: changed);
}
