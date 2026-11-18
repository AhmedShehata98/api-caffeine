import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mcp_connect_service.dart';
import '../services/mcp_primitive_services.dart';
import 'mcp_session_providers.dart';

/// Session-bound services hold no result cache or automatic request triggers.
final mcpPrimitiveServicesProvider = Provider.autoDispose
    .family<McpPrimitiveServices?, String>((ref, id) {
      final owner = ref.watch(mcpSessionOwnerProvider);
      final connected = ref.watch(
        mcpSessionsProvider.select((state) => state.value?.sessions[id]),
      );
      final context = owner.context;
      if (connected is! McpConnected || context == null) return null;
      return McpPrimitiveServices(
        connected.session,
        connected.negotiation,
        isAuthorized: () =>
            owner.isAuthorized(context, id) &&
            identical(owner.state.sessions[id], connected),
      );
    });
