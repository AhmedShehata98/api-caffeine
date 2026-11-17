import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_primitive_services.dart';
import '../services/mcp_session_work.dart';
import 'mcp_session_providers.dart';
import 'mcp_primitive_providers.dart';

final mcpSessionWorkProvider = Provider.autoDispose
    .family<McpSessionWork?, String>((ref, id) {
      ref.watch(
        mcpSessionsProvider.select((state) => state.value?.sessions[id]),
      );
      return ref.watch(mcpSessionOwnerProvider).workFor(id);
    });

final mcpWorkActionsProvider = Provider.autoDispose
    .family<McpWorkActions?, String>((ref, id) {
      final work = ref.watch(mcpSessionWorkProvider(id));
      final services = ref.watch(mcpPrimitiveServicesProvider(id));
      return work == null || services == null
          ? null
          : McpWorkActions(work, services);
    });

Stream<McpOperationState<D, T>> _states<D, T>(
  McpOperationController<D, T>? controller,
) {
  if (controller == null) return Stream.value(const McpOperationState());
  return Stream.multi((sink) {
    final subscription = controller.changes.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    sink.add(controller.state);
    sink.onCancel = subscription.cancel;
  });
}

final mcpToolCallProvider = StreamProvider.autoDispose
    .family<McpOperationState<McpToolDraft, McpToolCall>, String>(
      (ref, id) => _states(ref.watch(mcpSessionWorkProvider(id))?.tools),
    );
final mcpResourceReadProvider = StreamProvider.autoDispose
    .family<McpOperationState<String, List<ResourceContents>>, String>(
      (ref, id) => _states(ref.watch(mcpSessionWorkProvider(id))?.resources),
    );
final mcpPromptGetProvider = StreamProvider.autoDispose
    .family<McpOperationState<McpPromptDraft, McpPromptResult>, String>(
      (ref, id) => _states(ref.watch(mcpSessionWorkProvider(id))?.prompts),
    );
