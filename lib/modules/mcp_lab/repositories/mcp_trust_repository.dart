import 'package:test_point/core/error/result.dart';

import '../models/mcp_launch_trust.dart';

abstract interface class McpTrustRepository {
  Future<Result<McpTrustCheck>> check(
    McpAccessContext context,
    String serverId,
    McpLaunchSnapshot snapshot,
  );
  Future<Result<void>> approve(
    McpAccessContext context,
    String serverId,
    McpLaunchSnapshot snapshot,
  );
  Future<Result<void>> clear(McpAccessContext context, String serverId);
}
