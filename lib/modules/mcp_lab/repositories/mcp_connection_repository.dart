import 'package:test_point/core/error/result.dart';

import '../models/mcp_diagnostics.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';

/// Memory-only resolved target. Constructed by the connect/approval service.
class McpConnectTarget {
  McpConnectTarget({
    required this.context,
    required this.server,
    required this.timeout,
    this.launch,
    this.proxy,
  }) {
    if (server.workspaceId != context.workspaceId || timeout <= Duration.zero) {
      throw ArgumentError(
        'A current workspace and positive timeout are required.',
      );
    }
    if ((server.draft.transport == McpTransport.stdio) != (launch != null)) {
      throw ArgumentError(
        'Only stdio targets require an approved launch snapshot.',
      );
    }
  }
  final McpAccessContext context;
  final McpServer server;
  final Duration timeout;
  final McpLaunchSnapshot? launch;
  final Uri? proxy;
}

abstract interface class McpConnectionRepository {
  /// Establishes transport only; the service drives discovery/initialization.
  Future<Result<McpSession>> connect(McpConnectTarget target);
}

abstract interface class McpSession {
  /// Applied only after the connect service validates the negotiated version.
  /// Enables legacy version headers or modern request metadata/routing rules.
  Result<void> configureProtocol({
    required NegotiatedEra era,
    required String version,
  });

  /// IDs, when supplied, must be strings or integers. No automatic replay/MRTR.
  /// Returns the JSON-RPC result object; protocol errors return Err.
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  });
  Future<Result<void>> notify(String method, Map<String, dynamic> params);

  /// Diagnostic streams contain sanitized copies, never operation payloads.
  Stream<RpcFrame> get frames;
  Stream<NetworkEntry> get network;
  Stream<ConsoleLine> get console;
  Stream<ConnectionStatus> get status;

  /// Awaitable, bounded cleanup cancels pending calls and releases diagnostics.
  /// Cleanup errors remain visible through Result even when local close succeeds.
  Future<Result<void>> close();
}
