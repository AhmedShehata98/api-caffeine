import 'dart:async';

import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

/// Deduplicates native close requests and bounds the app's cleanup wait.
class DesktopCloseCoordinator {
  DesktopCloseCoordinator({
    required this.shutdown,
    required this.closeWindow,
    required this.reportFailure,
    this.deadline = const Duration(seconds: 5),
  });
  final Future<Result<void>> Function() shutdown;
  final bool Function() closeWindow;
  final void Function(Failure) reportFailure;
  final Duration deadline;
  Future<void>? _pending;
  bool _closed = false;
  bool _allowNativeClose = false;
  bool get allowNativeClose => _allowNativeClose;

  Future<void> requestClose() {
    if (_closed) return Future.value();
    return _pending ??= _finish().whenComplete(() => _pending = null);
  }

  Future<void> _finish() async {
    try {
      final result = await shutdown().timeout(deadline);
      if (result case Err(:final failure)) reportFailure(failure);
    } on TimeoutException {
      reportFailure(
        const UnexpectedFailure(
          'MCP cleanup exceeded the desktop exit deadline.',
        ),
      );
    } on Object {
      // Never forward exception text: a transport exception can contain secrets.
      reportFailure(
        const UnexpectedFailure('MCP cleanup failed during desktop exit.'),
      );
    }
    _allowNativeClose = true;
    try {
      _closed = closeWindow();
      if (!_closed) {
        reportFailure(
          const UnexpectedFailure('The desktop window could not be closed.'),
        );
      }
    } on Object {
      reportFailure(
        const UnexpectedFailure('The desktop window could not be closed.'),
      );
    } finally {
      _allowNativeClose = false;
    }
  }
}
