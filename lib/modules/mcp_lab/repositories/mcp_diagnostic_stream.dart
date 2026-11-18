import 'dart:async';

/// Bounded sanitized startup output, then a broadcast stream owned by providers.
class McpDiagnosticStream<T> {
  McpDiagnosticStream(this._overflow);
  final T Function(int count) _overflow;
  final _events = StreamController<T>.broadcast();
  final _startup = <T>[];
  var _bytes = 0;
  var _dropped = 0;
  var _observed = false;
  var _closed = false;
  Future<void>? _closeFuture;
  Stream<T> get stream => Stream.multi((sink) {
    final subscription = _events.stream.listen(
      sink.add,
      onError: sink.addError,
      onDone: sink.close,
    );
    if (!_observed) {
      _observed = true;
      for (final value in _startup) {
        sink.add(value);
      }
      if (_dropped > 0) sink.add(_overflow(_dropped));
      _startup.clear();
      _bytes = 0;
      _dropped = 0;
    }
    sink.onCancel = subscription.cancel;
  }, isBroadcast: true);
  void add(T value, int bytes) {
    if (_closed) throw StateError('Diagnostic stream has been closed.');
    if (_observed) {
      _events.add(value);
    } else if (_startup.length < 256 && _bytes + bytes <= 1024 * 1024) {
      _startup.add(value);
      _bytes += bytes;
    } else {
      _dropped++;
    }
  }

  Future<void> close() {
    if (_closeFuture != null) return _closeFuture!;
    _closed = true;
    _startup.clear();
    _bytes = 0;
    _dropped = 0;
    return _closeFuture = _events.close();
  }
}
