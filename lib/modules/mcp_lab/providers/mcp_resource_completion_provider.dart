import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_uri_template_input.dart';
import '../services/mcp_primitive_services.dart';
import 'mcp_primitive_providers.dart';

/// No automatic requests or cached suggestions; rebuilt for each live session.
final mcpResourceCompletionProvider = Provider.autoDispose
    .family<McpResourceCompletionActions?, String>((ref, id) {
      final services = ref.watch(mcpPrimitiveServicesProvider(id));
      return services == null || !services.supports('completions')
          ? null
          : McpResourceCompletionActions(services);
    });

class McpResourceCompletionActions {
  const McpResourceCompletionActions(this._services);
  final McpPrimitiveServices _services;

  Future<Result<McpCompletion>> complete(
    String template,
    String name,
    Map<String, McpUriTemplateInput> inputs,
  ) async {
    try {
      return await _services.resources.completeTemplate(template, name, inputs);
    } on Object {
      return const Result.failure(
        UnexpectedFailure('Could not load suggestions. Try again.'),
      );
    }
  }
}
