import 'dart:convert';

import 'mcp_connect_service.dart';
import '../models/mcp_server.dart';

String maskMcpServerText(McpServer server, String text) {
  final values = <String>{};
  for (final key in server.draft.secretKeys) {
    final value = key.startsWith('env.')
        ? server.draft.env[key.substring(4)]
        : server.draft.headers[key.substring(7)];
    if (value != null && value.isNotEmpty) {
      final escaped = jsonEncode(value);
      values.addAll([value, Uri.encodeComponent(value), escaped.substring(1, escaped.length - 1)]);
    }
  }
  final sorted = values.toList()..sort((a, b) => b.length.compareTo(a.length));
  for (final value in sorted) {
    text = text.replaceAll(value, '[REDACTED]');
  }
  return text.replaceAllMapped(
    RegExp(
      r'([?&](?:token|access_token|refresh_token|api_key|key|secret|password|code)=)[^&#\s]*',
      caseSensitive: false,
    ),
    (match) => '${match[1]}[REDACTED]',
  );
}

/// Display-only approval snapshot. Never includes environment/header values.
class McpApprovalSummary {
  McpApprovalSummary(McpNeedsApproval ticket) {
    final target = ticket.target;
    String mask(String text) => maskMcpServerText(target.server, text);

    final launch = target.launch!;
    executable = mask(launch.executable);
    directory = mask(launch.cwd);
    arguments = jsonEncode(launch.args.map(mask).toList());
    environmentKeys = List.unmodifiable(
      launch.environment.keys.toList()..sort(),
    );
  }
  late final String executable;
  late final String directory;
  late final String arguments;
  late final List<String> environmentKeys;
}
