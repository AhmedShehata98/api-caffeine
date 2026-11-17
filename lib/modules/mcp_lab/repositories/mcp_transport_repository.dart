import 'package:test_point/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_server.dart';
import 'mcp_connection_repository.dart';

/// Selects a transport without probing, fallback or automatic call replay.
class McpTransportRepository implements McpConnectionRepository {
  const McpTransportRepository({required this.stdio, required this.http});
  final McpConnectionRepository stdio;
  final McpConnectionRepository http;

  @override
  Future<Result<McpSession>> connect(McpConnectTarget target) =>
      switch (target.server.draft.transport) {
        McpTransport.stdio => stdio.connect(target),
        McpTransport.http => http.connect(target),
        McpTransport.sse => Future.value(
          const Result.failure(
            McpValidationFailure(
              'Deprecated HTTP+SSE transport is not implemented yet.',
              code: McpErrorCode.invalidParams,
            ),
          ),
        ),
      };
}
