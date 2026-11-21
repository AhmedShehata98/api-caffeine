import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_protocol_models.dart';
import '../repositories/mcp_resource_export_repository.dart';
import '../repositories/mcp_resource_export_repository_impl.dart';
import '../services/mcp_resource_export_service.dart';
import '../services/mcp_content_presentation.dart';
import 'mcp_session_providers.dart';

final mcpResourceExportRepositoryProvider =
    Provider<McpResourceExportRepository>(
      (ref) => const McpResourceExportRepositoryImpl(),
    );
final mcpResourceExportProvider = Provider.autoDispose
    .family<McpResourceExportActions, String>(
      (ref, id) => McpResourceExportActions(ref, id),
    );

class McpResourceExportActions {
  const McpResourceExportActions(this.ref, this.id);
  final Ref ref;
  final String id;
  Future<Result<bool>> save(
    ResourceContents contents, {
    McpContentOrigin origin = McpContentOrigin.resource,
    ContentBlock? block,
  }) async {
    final owner = ref.read(mcpSessionOwnerProvider);
    final work = owner.workFor(id);
    final outcome = work == null ? null : mcpContentResult(work, origin);
    if (work == null || outcome == null) {
      return const Result.failure(
        ValidationFailure('Read a resource before saving.'),
      );
    }
    bool current() =>
        ref.mounted &&
        identical(owner.workFor(id), work) &&
        identical(mcpContentResult(work, origin), outcome) &&
        (origin == McpContentOrigin.resource
            ? (work.resources.state.outcome?.valueOrNull?.any(
                    (item) => identical(item, contents),
                  ) ??
                  false)
            : block != null &&
                  ownsMcpContent(work, origin, block) &&
                  resourceForMcpContent(block) == contents);
    return McpResourceExportService(
      ref.read(mcpResourceExportRepositoryProvider),
    ).save(contents, isCurrent: current);
  }
}
