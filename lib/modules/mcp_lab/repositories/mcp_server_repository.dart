import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_server.dart';

abstract interface class McpServerRepository {
  Future<Result<List<McpServer>>> list(String workspaceId);
  Future<Result<McpServer>> create({
    required String workspaceId,
    required McpServerDraft draft,
    int? position,
  });
  Future<Result<McpServer>> update({
    required String workspaceId,
    required String id,
    required McpServerDraft draft,
    int? position,
  });
  Future<Result<void>> delete({
    required String workspaceId,
    required String id,
  });
}
