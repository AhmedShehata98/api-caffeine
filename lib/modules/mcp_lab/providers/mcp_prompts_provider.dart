import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_protocol_models.dart';
import 'mcp_primitive_providers.dart';

final mcpPromptsProvider = FutureProvider.autoDispose
    .family<List<McpPrompt>?, String>((ref, id) async {
      final services = ref.watch(mcpPrimitiveServicesProvider(id));
      if (services == null) return null;
      if (!services.supports('prompts')) return const [];
      final result = await services.prompts.list();
      return result.when(
        success: (prompts) => prompts,
        failure: (failure) => throw failure,
      );
    }, retry: (_, _) => null);
