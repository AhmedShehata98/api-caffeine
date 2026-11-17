import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/mcp_diagnostics.dart';
import '../services/mcp_connect_service.dart';
import 'mcp_session_providers.dart';

final mcpConnectionStatusProvider = StreamProvider.autoDispose
    .family<ConnectionStatus, String>((ref, id) {
      final entry = ref.watch(
        mcpSessionsProvider.select((state) => state.value?.sessions[id]),
      );
      return entry is McpConnected
          ? entry.session.status
          : Stream.value(const ConnectionStatus.idle());
    });
