import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:window_manager/window_manager.dart';

import 'desktop_close_coordinator.dart';

/// Installed once by main, before the application can open MCP sessions.
/// Widget tests do not register native listeners or load window FFI.
void installDesktopCloseHandler(ProviderContainer container) {
  final window = WindowManager.instance.getCurrent();
  if (window == null) return;
  late ListenerId listener;
  late DesktopCloseCoordinator coordinator;
  void onEvent(WindowEvent event) {
    if (event is WindowCloseRequestedEvent && !coordinator.allowNativeClose) {
      event.request.cancel();
      unawaited(coordinator.requestClose());
    }
  }

  coordinator = DesktopCloseCoordinator(
    shutdown: () => container.read(mcpSessionOwnerProvider).shutdownForExit(),
    closeWindow: () {
      // Remove the interceptor even when native events arrive asynchronously.
      window.removeListener(listener);
      try {
        final closed = window.close();
        if (!closed) listener = window.addListener(onEvent);
        return closed;
      } on Object {
        listener = window.addListener(onEvent);
        rethrow;
      }
    },
    reportFailure: (failure) => FlutterError.reportError(
      FlutterErrorDetails(
        exception: failure,
        library: 'API Caffeine desktop shutdown',
      ),
    ),
  );
  listener = window.addListener(onEvent);
}
