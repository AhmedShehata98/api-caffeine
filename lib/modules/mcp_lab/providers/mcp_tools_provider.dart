import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_protocol_models.dart';
import 'mcp_primitive_providers.dart';

final mcpToolsProvider = FutureProvider.autoDispose
    .family<List<McpTool>?, String>((ref, id) async {
      final services = ref.watch(mcpPrimitiveServicesProvider(id));
      if (services == null) return null;
      if (!services.supports('tools')) return const [];
      final result = await services.tools.list();
      return result.when(
        success: (tools) => tools,
        failure: (failure) => throw failure,
      );
    }, retry: (_, _) => null);
