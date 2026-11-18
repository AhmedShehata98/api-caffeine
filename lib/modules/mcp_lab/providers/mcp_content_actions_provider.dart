import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_content_presentation.dart';
import '../services/mcp_session_work.dart';
import 'mcp_session_providers.dart';
import 'mcp_primitive_providers.dart';

final mcpCanOpenResourceProvider = Provider.autoDispose.family<bool, String>(
  (ref, id) =>
      ref.watch(mcpPrimitiveServicesProvider(id))?.supports('resources') ??
      false,
);

final mcpContentActionsProvider = Provider.autoDispose
    .family<McpContentActions, String>((ref, id) => McpContentActions(ref, id));

class McpContentActions {
  const McpContentActions(this.ref, this.id);
  final Ref ref;
  final String id;
  Result<void> openResource(ResourceLinkBlock block, McpContentOrigin origin) {
    final work = ref.read(mcpSessionOwnerProvider).workFor(id);
    if (work == null || !ownsMcpContent(work, origin, block)) {
      return const Result.failure(
        ValidationFailure('This content result is no longer active.'),
      );
    }
    if (!ref.read(mcpCanOpenResourceProvider(id))) {
      return const Result.failure(
        ValidationFailure('This server does not advertise resource reads.'),
      );
    }
    final uri = Uri.tryParse(block.uri);
    if (uri == null ||
        !uri.hasScheme ||
        block.uri.contains('{') ||
        block.uri.contains('}')) {
      return const Result.failure(
        ValidationFailure(
          'This resource link is not an absolute resolved URI.',
        ),
      );
    }
    work.resourceTemplate.setDraft(McpResourceTemplateDraft());
    return work.resources.setDraft(block.uri);
  }
}
