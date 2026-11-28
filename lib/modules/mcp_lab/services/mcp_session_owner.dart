import 'dart:async';

import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../repositories/mcp_connection_repository.dart';
import 'mcp_connect_service.dart';
import 'mcp_session_diagnostics.dart';
import 'mcp_session_work.dart';

class McpOwnedSessions {
  McpOwnedSessions(
    Map<String, McpConnectOutcome> sessions,
    List<Failure> failures,
    this.context,
    Map<String, McpSessionDiagnostics> diagnostics,
  ) : sessions = Map.unmodifiable(sessions),
      failures = List.unmodifiable(failures),
      diagnostics = Map.unmodifiable(diagnostics);
  final Map<String, McpConnectOutcome> sessions;
  final List<Failure> failures;
  final McpAccessContext? context;
  final Map<String, McpSessionDiagnostics> diagnostics;
}

/// Owns live sessions and approval tickets across account/workspace generations.
/// Boundary invalidation is synchronous; readiness waits for old work to stop.
class McpSessionOwner {
  McpSessionOwner({this.limit = 8, this.createDiagnostics});
  final int limit;
  final McpSessionDiagnostics Function(McpSession)? createDiagnostics;
  final _diagnostics = <String, McpSessionDiagnostics>{};
  final _work = <String, McpSessionWork>{};
  final _changes = StreamController<McpOwnedSessions>.broadcast();
  final _sessions = <String, McpConnectOutcome>{};
  final _opening = <String, McpSession>{};
  final _busy = <String>{};
  final _revoked = <String>{};
  final _operations = <String, Future<void>>{};
  final _pending = <Future<void>>{};
  final _failures = <Failure>[];
  var _cleanupFailureCount = 0;
  McpAccessContext? _context;
  var _generation = 0;
  var _disposed = false;
  var _exiting = false;
  Future<Result<void>>? _exit;
  Future<void> _transition = Future.value();

  McpAccessContext? get context => _context;
  McpOwnedSessions get state =>
      McpOwnedSessions(_sessions, _failures, _context, _diagnostics);
  Stream<McpOwnedSessions> get changes => _changes.stream;
  Future<void> get ready => _transition;

  bool isAuthorized(McpAccessContext context, String serverId) =>
      !_disposed &&
      !_revoked.contains(serverId) &&
      _context != null &&
      context.generation == _generation &&
      context.userId == _context!.userId &&
      context.workspaceId == _context!.workspaceId;

  void _publish() {
    if (!_disposed) _changes.add(state);
  }

  Future<void> switchScope(String? userId, String? workspaceId) {
    final generation = ++_generation;
    _context = null;
    _revoked.clear();
    final old = <McpSession>{
      for (final connected in _sessions.values.whereType<McpConnected>())
        connected.session,
      ..._opening.values,
    };
    _opening.clear();
    _sessions.clear(); // Releases pending approval snapshots immediately.
    final workCleanup = [for (final work in _work.values) work.dispose()];
    _work.clear();
    final monitorCleanup = [
      for (final monitor in _diagnostics.values) monitor.dispose(),
    ];
    _diagnostics.clear();
    _publish();
    final pending = _pending.toList();
    return _transition = _transition.then((_) async {
      await Future.wait([
        for (final connected in old) _close(connected),
        ...pending,
        ...monitorCleanup,
        ...workCleanup,
      ]);
      if (!_disposed &&
          generation == _generation &&
          !_exiting &&
          userId != null &&
          workspaceId != null) {
        _context = McpAccessContext(
          userId: userId,
          workspaceId: workspaceId,
          generation: generation,
        );
      }
      _publish();
    });
  }

  Future<void> _close(McpSession session) async {
    final result = await session.close();
    if (result case Err(:final failure)) {
      _cleanupFailureCount++;
      _failures.add(failure);
      if (_failures.length > 32) _failures.removeAt(0);
    }
  }

  /// Created lazily by the UI, owned and synchronously cleared at boundaries.
  McpSessionWork? workFor(String id) {
    final captured = _context;
    final connected = _sessions[id];
    if (captured == null ||
        connected is! McpConnected ||
        !isAuthorized(captured, id)) {
      return null;
    }
    return _work.putIfAbsent(
      id,
      () => McpSessionWork(
        isAuthorized: () =>
            isAuthorized(captured, id) && identical(_sessions[id], connected),
      ),
    );
  }

  /// Called synchronously after transport open, before negotiation can block.
  void trackOpening(McpAccessContext context, String id, McpSession session) {
    if (isAuthorized(context, id)) {
      _opening[id] = session;
      final previous = _diagnostics.remove(id);
      if (previous != null) {
        final cleanup = previous.dispose();
        _pending.add(cleanup);
        unawaited(cleanup.whenComplete(() => _pending.remove(cleanup)));
      }
      final monitor = createDiagnostics?.call(session);
      if (monitor != null) _diagnostics[id] = monitor;
      _publish();
    }
  }

  /// Prevents duplicate connects and publishes only results from this generation.
  Future<Result<McpConnectOutcome>> run(
    String serverId,
    Future<Result<McpConnectOutcome>> Function(McpAccessContext) operation,
  ) async {
    final captured = _context;
    if (captured == null || !isAuthorized(captured, serverId)) {
      return const Result.failure(
        McpAuthFailure('Wait for the current workspace to become ready.'),
      );
    }
    if (_busy.contains(serverId) ||
        (_sessions.containsKey(serverId) &&
            _sessions[serverId] is McpConnected) ||
        (!_sessions.containsKey(serverId) &&
            {..._sessions.keys, ..._busy}.length >= limit)) {
      return const Result.failure(
        McpValidationFailure(
          'This server is busy or the session limit has been reached.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    _busy.add(serverId);
    final completed = Completer<void>();
    _pending.add(completed.future);
    _operations[serverId] = completed.future;
    try {
      final result = await operation(captured);
      if (!isAuthorized(captured, serverId)) {
        if (result.valueOrNull case final McpConnected connected) {
          await _close(connected.session);
        }
        return const Result.failure(
          McpAuthFailure(
            'The account or workspace changed. Reconnect from the current workspace.',
          ),
        );
      }
      if (result case Success(:final value)) {
        _sessions[serverId] = value;
      } else {
        _sessions.remove(serverId);
      }
      _publish();
      return result;
    } finally {
      _opening.remove(serverId);
      _busy.remove(serverId);
      _pending.remove(completed.future);
      _operations.remove(serverId);
      completed.complete();
    }
  }

  Future<Result<void>> disconnect(String serverId) async {
    if (_busy.contains(serverId)) {
      return const Result.failure(
        McpValidationFailure(
          'Wait for this server operation to finish.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final entry = _sessions.remove(serverId);
    final workCleanup = _work.remove(serverId)?.dispose();
    final monitor = _diagnostics.remove(serverId);
    final monitorCleanup = monitor?.dispose();
    if (entry is! McpConnected) {
      await monitorCleanup;
      await workCleanup;
      _publish();
      return const Result.success(null);
    }
    _busy.add(serverId);
    final done = Completer<void>();
    _pending.add(done.future);
    try {
      final result = await entry.session.close();
      await monitorCleanup;
      await workCleanup;
      _publish();
      return result;
    } finally {
      _busy.remove(serverId);
      _pending.remove(done.future);
      done.complete();
    }
  }

  Future<void> shutdown() => switchScope(null, null);

  /// A successful catalog refresh is authoritative for server availability.
  /// Revocation is synchronous, including while a connection is being opened.
  Future<Result<void>> reconcileCatalog(
    McpAccessContext captured,
    Set<String> ids,
  ) async {
    if (!isAuthorized(captured, '')) {
      return const Result.failure(
        McpAuthFailure('The workspace changed. Reload the catalog.'),
      );
    }
    _revoked.removeAll(ids);
    final missing = {
      ..._sessions.keys,
      ..._opening.keys,
      ..._busy,
      ..._diagnostics.keys,
      ..._work.keys,
    }.difference(ids);
    final closing = <Future<void>>[];
    final count = _cleanupFailureCount;
    for (final id in missing) {
      _revoked.add(id);
      final entry = _sessions.remove(id);
      final work = _work.remove(id);
      if (work != null) closing.add(work.dispose());
      final monitor = _diagnostics.remove(id);
      if (monitor != null) closing.add(monitor.dispose());
      final sessions = <McpSession>{
        if (entry is McpConnected) entry.session,
        if (_opening.remove(id) case final McpSession session) session,
      };
      closing.addAll(sessions.map(_close));
      if (_operations[id] case final Future<void> pending) closing.add(pending);
    }
    _publish();
    await Future.wait(closing);
    if (!isAuthorized(captured, '')) {
      return const Result.failure(
        McpAuthFailure('The workspace changed. Reload the catalog.'),
      );
    }
    if (_cleanupFailureCount > count) return Result.failure(_failures.last);
    return const Result.success(null);
  }

  /// Terminal boundary: auth/workspace updates cannot enable new sessions again.
  /// The desktop coordinator applies the overall exit deadline.
  Future<Result<void>> shutdownForExit() {
    if (_exit != null) return _exit!;
    _exiting = true;
    final failureCount = _cleanupFailureCount;
    return _exit = shutdown().then((_) {
      if (_cleanupFailureCount > failureCount) {
        return Result<void>.failure(_failures.last);
      }
      return const Result<void>.success(null);
    });
  }

  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    await shutdown();
    await _changes.close();
  }
}
