import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_target_settings.dart';

import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import 'mcp_connection_repository.dart';

abstract interface class McpTargetRepository {
  /// Resolves paths/environment/proxy only. Never starts a server or connects.
  Future<Result<McpConnectTarget>> resolve(
    McpAccessContext context,
    McpServer server,
    McpTargetSettings settings,
  );
}
