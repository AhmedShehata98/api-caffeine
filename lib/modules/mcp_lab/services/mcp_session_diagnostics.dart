import 'dart:async';

import '../repositories/mcp_connection_repository.dart';
import 'mcp_diagnostic_buffer.dart';

/// Subscribes at transport open so handshake/startup output reaches the monitors.
class McpSessionDiagnostics {
  McpSessionDiagnostics(McpSession session) {
    _subscriptions.addAll([
      session.frames.listen((value) {
        protocol.addFrame(value);
        _publish();
      }, onError: _error),
      session.network.listen((value) {
        network.addNetwork(value);
        _publish();
      }, onError: _error),
      session.console.listen((value) {
        console.addConsole(value);
        _publish();
      }, onError: _error),
    ]);
  }
  final protocol = McpDiagnosticBuffer();
  final network = McpDiagnosticBuffer();
  final console = McpDiagnosticBuffer();
  final _subscriptions = <StreamSubscription<dynamic>>[];
  final _changes = StreamController<void>.broadcast();
  var _disposed = false;
  var streamErrors = 0;
  Future<void>? _closing;
  Timer? _notification;
  Stream<void> get changes => _changes.stream;
  void _publish() {
    if (_disposed || _notification != null) return;
    _notification = Timer(const Duration(milliseconds: 16), () {
      _notification = null;
      if (!_disposed) _changes.add(null);
    });
  }

  void _error(Object error, StackTrace stack) {
    // Count errors without retaining possibly credential-bearing exception text.
    streamErrors++;
    _publish();
  }

  void clear() {
    protocol.clear();
    network.clear();
    console.clear();
    streamErrors = 0;
    _publish();
  }

  void clearBuffer(McpMonitorKind kind) {
    switch (kind) {
      case McpMonitorKind.protocol:
        protocol.clear();
      case McpMonitorKind.network:
        network.clear();
      case McpMonitorKind.console:
        console.clear();
    }
    _publish();
  }

  Future<void> dispose() {
    if (_closing != null) return _closing!;
    _disposed = true;
    streamErrors = 0;
    _notification?.cancel();
    protocol.dispose();
    network.dispose();
    console.dispose();
    // Replace any retained StreamProvider snapshot before closing. A paused
    // monitor listener must not delay account/workspace shutdown.
    _changes.add(null);
    unawaited(_changes.close());
    return _closing = Future.wait(
      _subscriptions.map((subscription) => subscription.cancel()),
    ).then((_) {});
  }
}
