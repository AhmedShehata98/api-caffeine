import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_protocol_models.dart';
import '../services/mcp_primitive_services.dart';
import 'mcp_primitive_providers.dart';

final mcpPromptCompletionProvider = Provider.autoDispose
    .family<McpPromptCompletionActions?, String>((ref, id) {
      final services = ref.watch(mcpPrimitiveServicesProvider(id));
      return services == null || !services.supports('completions')
          ? null
          : McpPromptCompletionActions(services);
    });

class McpPromptCompletionActions {
  const McpPromptCompletionActions(this._services);
  final McpPrimitiveServices _services;

  Future<Result<McpCompletion>> complete(
    McpPrompt prompt,
    String name,
    Map<String, String> arguments,
  ) async {
    try {
      return await _services.prompts.complete(prompt, name, arguments);
    } on Object {
      return const Result.failure(
        UnexpectedFailure('Could not load suggestions. Try again.'),
      );
    }
  }
}
