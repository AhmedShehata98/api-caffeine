import 'dart:convert';

import '../models/mcp_diagnostics.dart';
import 'mcp_diagnostic_sanitizer.dart';
import 'mcp_diagnostic_stream.dart';

/// Shared frame construction ensures metadata never bypasses sanitization.
class McpRpcDiagnostics {
  McpRpcDiagnostics(this._sanitizer);
  final McpDiagnosticSanitizer _sanitizer;
  final _events = McpDiagnosticStream<RpcFrame>(
    (count) => RpcFrame(
      direction: RpcDirection.incoming,
      timestamp: DateTime.now().toUtc(),
      kind: RpcFrameKind.warning,
      rawJson: '$count startup protocol entries dropped (buffer limit).',
      size: 0,
    ),
  );
  Stream<RpcFrame> get stream => _events.stream;
  String record(String wire, RpcDirection direction, {bool warning = false}) {
    final sanitized = _sanitizer.frame(wire);
    final value = warning
        ? <String, dynamic>{}
        : jsonDecode(sanitized.text) as Map<String, dynamic>;
    final id = value['id'];
    final method = value['method'] as String?;
    final kind = warning
        ? RpcFrameKind.warning
        : method != null
        ? id == null
              ? RpcFrameKind.notification
              : RpcFrameKind.request
        : RpcFrameKind.response;
    final payload = value['params'] ?? value['result'];
    final meta = payload is Map && payload['_meta'] is Map
        ? Map<String, dynamic>.from(payload['_meta'] as Map)
        : <String, dynamic>{};
    final size = utf8.encode(sanitized.text).length;
    _events.add(
      RpcFrame(
        direction: direction,
        timestamp: DateTime.now().toUtc(),
        kind: kind,
        id: id,
        method: method,
        pairedId: kind == RpcFrameKind.response ? id : null,
        rawJson: sanitized.text,
        size: size,
        meta: meta,
        redacted: sanitized.redacted,
      ),
      size,
    );
    return sanitized.text;
  }

  Future<void> close() => _events.close();
}
