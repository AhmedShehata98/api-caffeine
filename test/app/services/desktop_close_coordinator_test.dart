import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/app/services/desktop_close_coordinator.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

void main() {
  test(
    'close waits for cleanup and duplicate requests share one future',
    () async {
      final stopped = Completer<Result<void>>();
      var stops = 0;
      var closes = 0;
      final failures = <Failure>[];
      final coordinator = DesktopCloseCoordinator(
        shutdown: () {
          stops++;
          return stopped.future;
        },
        closeWindow: () {
          closes++;
          return true;
        },
        reportFailure: failures.add,
      );
      final first = coordinator.requestClose();
      expect(coordinator.requestClose(), same(first));
      expect(closes, 0);
      stopped.complete(const Result.success(null));
      await first;
      await coordinator.requestClose();
      expect(stops, 1);
      expect(closes, 1);
      expect(failures, isEmpty);
    },
  );

  test('cleanup failure is reported before close', () async {
    const failure = UnexpectedFailure('Cleanup failed');
    final events = <Object>[];
    final coordinator = DesktopCloseCoordinator(
      shutdown: () async => const Result.failure(failure),
      reportFailure: events.add,
      closeWindow: () {
        events.add('close');
        return true;
      },
    );
    await coordinator.requestClose();
    expect(events, [failure, 'close']);
  });

  testWidgets('cleanup deadline closes once even after late completion', (
    tester,
  ) async {
    final stopped = Completer<Result<void>>();
    final failures = <Failure>[];
    var closes = 0;
    final coordinator = DesktopCloseCoordinator(
      shutdown: () => stopped.future,
      reportFailure: failures.add,
      closeWindow: () {
        closes++;
        return true;
      },
    );
    final pending = coordinator.requestClose();
    await tester.pump(const Duration(seconds: 4));
    expect(closes, 0);
    await tester.pump(const Duration(seconds: 1));
    await pending;
    expect(closes, 1);
    expect(failures.single.message, contains('deadline'));
    stopped.complete(const Result.success(null));
    await tester.pump();
    expect(closes, 1);
  });

  test('shutdown exceptions are sanitized', () async {
    final failures = <Failure>[];
    final coordinator = DesktopCloseCoordinator(
      shutdown: () async => throw StateError('secret-canary'),
      reportFailure: failures.add,
      closeWindow: () => true,
    );
    await coordinator.requestClose();
    expect(failures.single.message, isNot(contains('secret-canary')));
  });

  test('rejected native close reports failure and permits retry', () async {
    final failures = <Failure>[];
    var closes = 0;
    final coordinator = DesktopCloseCoordinator(
      shutdown: () async => const Result.success(null),
      reportFailure: failures.add,
      closeWindow: () => ++closes > 1,
    );
    await coordinator.requestClose();
    expect(failures, hasLength(1));
    await coordinator.requestClose();
    expect(closes, 2);
  });

  test('native exceptions are sanitized and reset the close bypass', () async {
    final failures = <Failure>[];
    final coordinator = DesktopCloseCoordinator(
      shutdown: () async => const Result.success(null),
      reportFailure: failures.add,
      closeWindow: () => throw StateError('secret-canary'),
    );
    await coordinator.requestClose();
    expect(coordinator.allowNativeClose, isFalse);
    expect(failures.single.message, isNot(contains('secret-canary')));
  });
}
