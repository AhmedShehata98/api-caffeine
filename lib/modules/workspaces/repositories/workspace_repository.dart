import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/workspaces/models/workspace.dart';

abstract interface class WorkspaceRepository {
  /// The user's default workspace (the oldest one they can access).
  Future<Result<Workspace>> loadDefault();
}
