import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_protocol_models.dart';
import '../repositories/mcp_resource_export_repository.dart';
import '../repositories/mcp_resource_export_repository_impl.dart';
import '../services/mcp_resource_export_service.dart';
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
  Future<Result<bool>> save(ResourceContents contents) async {
    final owner = ref.read(mcpSessionOwnerProvider);
    final work = owner.workFor(id);
    final outcome = work?.resources.state.outcome;
    if (work == null || outcome == null) {
      return const Result.failure(
        ValidationFailure('Read a resource before saving.'),
      );
    }
    bool current() =>
        ref.mounted &&
        identical(owner.workFor(id), work) &&
        identical(work.resources.state.outcome, outcome) &&
        (outcome.valueOrNull?.any((item) => identical(item, contents)) ??
            false);
    return McpResourceExportService(
      ref.read(mcpResourceExportRepositoryProvider),
    ).save(contents, isCurrent: current);
  }
}
