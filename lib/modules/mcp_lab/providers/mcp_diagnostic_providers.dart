import 'dart:async';
import 'dart:convert';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../services/mcp_diagnostic_buffer.dart';
import '../services/mcp_session_diagnostics.dart';
import '../models/mcp_diagnostics.dart';
import '../services/mcp_monitor_presentation.dart';
import 'mcp_session_providers.dart';

class McpMonitorSnapshot {
  McpMonitorSnapshot(McpSessionDiagnostics monitor)
    : source = monitor,
      protocol = monitor.protocol.entries,
      network = monitor.network.entries,
      console = monitor.console.entries,
      protocolDropped = monitor.protocol.dropped,
      networkDropped = monitor.network.dropped,
      consoleDropped = monitor.console.dropped,
      streamErrors = monitor.streamErrors;
  final List<McpMonitorEntry> protocol;
  final McpSessionDiagnostics source;
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

typedef McpMonitorQuery = ({
  String id,
  McpMonitorKind kind,
  String text,
  RpcDirection? direction,
  RpcFrameKind? frameKind,
});

/// StreamProvider may retain its previous value while attaching a new stream.
/// Never expose that previous session's payload during a replacement.
final mcpCurrentDiagnosticsProvider = Provider.autoDispose
    .family<McpMonitorSnapshot?, String>((ref, id) {
      final current = ref.watch(mcpSessionsProvider).value?.diagnostics[id];
      final snapshot = ref.watch(mcpDiagnosticsProvider(id)).value;
      return snapshot != null &&
              identical(snapshot.source, current) &&
              identical(
                ref.read(mcpSessionOwnerProvider).state.diagnostics[id],
                current,
              )
          ? snapshot
          : null;
    });

final mcpMonitorRowsProvider = Provider.autoDispose
    .family<List<McpMonitorEntry>, McpMonitorQuery>((ref, query) {
      final snapshot = ref.watch(mcpCurrentDiagnosticsProvider(query.id));
      final entries =
          switch (query.kind) {
            McpMonitorKind.protocol => snapshot?.protocol,
            McpMonitorKind.network => snapshot?.network,
            McpMonitorKind.console => snapshot?.console,
          } ??
          const <McpMonitorEntry>[];
      return filterMcpMonitorEntries(
        entries,
        query: query.text,
        direction: query.direction,
        kind: query.frameKind,
      );
    });

final mcpMonitorActionsProvider = Provider.autoDispose
    .family<McpMonitorActions, String>((ref, id) {
      final monitor = ref.watch(
        mcpSessionsProvider.select((state) => state.value?.diagnostics[id]),
      );
      return McpMonitorActions(
        monitor,
        () =>
            ref.mounted &&
            monitor != null &&
            identical(
              ref.read(mcpSessionOwnerProvider).state.diagnostics[id],
              monitor,
            ),
      );
    });

Future<String> _formatDiagnostic(Object? value) =>
    Isolate.run(() => const JsonEncoder.withIndent('  ').convert(value));

class McpMonitorActions {
  const McpMonitorActions(this.monitor, this.isCurrent);
  final McpSessionDiagnostics? monitor;
  final bool Function() isCurrent;
  McpDiagnosticBuffer? _buffer(McpMonitorKind kind) => switch (kind) {
    McpMonitorKind.protocol => monitor?.protocol,
    McpMonitorKind.network => monitor?.network,
    McpMonitorKind.console => monitor?.console,
  };
  Result<String> copy(
    McpMonitorKind kind,
    int sequence, {
    McpNetworkBodySide side = McpNetworkBodySide.response,
  }) => isCurrent()
      ? _buffer(kind)!.copyText(sequence, side: side)
      : const Result.failure(_stale);
  void clear(McpMonitorKind kind) {
    if (isCurrent()) monitor!.clearBuffer(kind);
  }

  Future<Result<String>> export(
    McpMonitorKind kind,
    List<McpMonitorEntry> entries,
  ) async {
    if (!isCurrent()) return const Result.failure(_stale);
    final buffer = _buffer(kind);
    if (buffer == null) return const Result.failure(_stale);
    var bytes = 0;
    final records = <Map<String, Object?>>[];
    for (final entry in entries) {
      if (!isCurrent() || !buffer.copyText(entry.sequence).isSuccess) {
        return const Result.failure(_stale);
      }
      final body = entry.text.substring(
        0,
        math.min(entry.text.length, 64 * 1024),
      );
      bytes += body.length * 4;
      if (bytes > 1024 * 1024) {
        return const Result.failure(
          ValidationFailure(
            'The filtered export exceeds 1 MiB. Narrow the filter and try again.',
          ),
        );
      }
      records.add({
        'sequence': entry.sequence,
        'text': body,
        'frame': entry.frame?.toJson(),
        'network': entry.network?.toJson(),
        'console': entry.console?.toJson(),
        'truncated': entry.truncated || entry.text.length > body.length,
      });
    }
    final value = await _formatDiagnostic({
      'monitor': kind.name,
      'captures': records,
    });
    return isCurrent() ? Result.success(value) : const Result.failure(_stale);
  }

  Future<Result<String>> loadFull(
    McpMonitorKind kind,
    McpMonitorEntry entry, {
    McpNetworkBodySide side = McpNetworkBodySide.response,
  }) async {
    final buffer = _buffer(kind);
    if (!isCurrent() || buffer == null) return const Result.failure(_stale);
    if (kind == McpMonitorKind.console ||
        entry.frame?.kind == RpcFrameKind.warning) {
      return buffer.copyText(entry.sequence);
    }
    try {
      final parsed = await buffer.loadFullJson(entry.sequence, side: side);
      if (!parsed.isSuccess) return Result.failure(parsed.failureOrNull!);
      final formatted = await _formatDiagnostic(parsed.valueOrNull);
      if (!isCurrent() || !buffer.copyText(entry.sequence).isSuccess) {
        return const Result.failure(_stale);
      }
      return Result.success(formatted);
    } on Object {
      return const Result.failure(
        UnexpectedFailure('Could not format this diagnostic body.'),
      );
    }
  }

  static const _stale = ValidationFailure(
    'This diagnostic session is no longer active.',
  );
}
