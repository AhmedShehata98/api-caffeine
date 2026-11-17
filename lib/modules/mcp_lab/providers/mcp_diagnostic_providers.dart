import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/mcp_diagnostic_buffer.dart';
import '../services/mcp_session_diagnostics.dart';
import 'mcp_session_providers.dart';

class McpMonitorSnapshot {
  McpMonitorSnapshot(McpSessionDiagnostics monitor)
    : protocol = monitor.protocol.entries,
      network = monitor.network.entries,
      console = monitor.console.entries,
      protocolDropped = monitor.protocol.dropped,
      networkDropped = monitor.network.dropped,
      consoleDropped = monitor.console.dropped,
      streamErrors = monitor.streamErrors;
  final List<McpMonitorEntry> protocol;
  final List<McpMonitorEntry> network;
  final List<McpMonitorEntry> console;
  final int protocolDropped;
  final int networkDropped;
  final int consoleDropped;
  final int streamErrors;
}

final mcpDiagnosticsProvider = StreamProvider.autoDispose
    .family<McpMonitorSnapshot?, String>((ref, id) {
      final monitor = ref.watch(
        mcpSessionsProvider.select((state) => state.value?.diagnostics[id]),
      );
      if (monitor == null) return Stream.value(null);
      return Stream.multi((sink) {
        final subscription = monitor.changes.listen(
          (_) => sink.add(McpMonitorSnapshot(monitor)),
          onError: sink.addError,
          onDone: sink.close,
        );
        sink.add(McpMonitorSnapshot(monitor));
        sink.onCancel = subscription.cancel;
      });
    });
