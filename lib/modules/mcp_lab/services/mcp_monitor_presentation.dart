import 'dart:convert';

import '../models/mcp_diagnostics.dart';
import 'mcp_diagnostic_buffer.dart';

String mcpMonitorTitle(McpMonitorEntry entry) {
  final frame = entry.frame;
  if (frame != null) {
    if (frame.kind == RpcFrameKind.warning) {
      return 'Protocol warning: non-JSON or malformed stdout';
    }
    return '${frame.direction == RpcDirection.outgoing ? '→' : '←'} ${frame.method ?? frame.kind.name}${frame.id == null ? '' : ' · id ${jsonEncode(frame.id)}'}';
  }
  final network = entry.network;
  if (network != null) return '${network.method} ${network.url}';
  final preview = entry.text.substring(0, entry.text.length.clamp(0, 1024));
  return preview.split('\n').first;
}

List<McpMonitorEntry> filterMcpMonitorEntries(
  List<McpMonitorEntry> entries, {
  String query = '',
  RpcDirection? direction,
  RpcFrameKind? kind,
}) {
  if (query.isEmpty && direction == null && kind == null) return entries;
  final search = query.toLowerCase();
  return entries
      .where((entry) {
        if (direction != null && entry.frame?.direction != direction) {
          return false;
        }
        if (kind != null && entry.frame?.kind != kind) return false;
        final title = mcpMonitorTitle(entry);
        // Search metadata and a bounded console prefix, never every retained body.
        return search.isEmpty ||
            title
                .substring(0, title.length.clamp(0, 1024))
                .toLowerCase()
                .contains(search);
      })
      .toList(growable: false);
}

/// Input must be a header from the already sanitized diagnostic contract.
String mcpDiagnosticHeaderDisplay(String value) {
  if (value.startsWith('=?base64?') && value.endsWith('?=')) {
    try {
      return utf8.decode(base64Decode(value.substring(9, value.length - 2)));
    } on FormatException {
      return value;
    }
  }
  return value;
}
