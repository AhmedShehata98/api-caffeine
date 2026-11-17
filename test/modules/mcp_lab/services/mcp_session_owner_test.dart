import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/auth/auth.dart';
import 'package:test_point/modules/workspaces/workspaces.dart';

class _Session extends Mock implements McpSession {}

class _User extends SessionNotifier {
  @override
  Future<AuthUser?> build() async => const AuthUser(id: 'u', isAnonymous: true);
  void loading() => state = const AsyncLoading();
}

void main() {
  late McpSessionOwner owner;
  late _Session session;
  late McpConnected connected;
  setUp(() async {
    owner = McpSessionOwner(limit: 2);
    await owner.switchScope('u', 'w');
    session = _Session();
    when(() => session.close())
        .thenAnswer((_) async => const Result.success(null));
    connected = McpConnected(
      session,
      McpNegotiation(
        era: NegotiatedEra.legacy,
        version: '2025-11-25',
        discovery: {},
      ),
    );
  });
  tearDown(() => owner.dispose());

  test(
    'catalog revocation cancels pending negotiation without changing workspace',
    () async {
      final captured = owner.context!;
      final failed = Completer<Result<McpConnectOutcome>>();
      final pending = owner.run('s', (context) {
        owner.trackOpening(context, 's', session);
        return failed.future;
      });
      when(() => session.close()).thenAnswer((_) async {
        failed.complete(const Result.failure(McpAuthFailure('Access revoked')));
        return const Result.success(null);
      });
      expect((await owner.reconcileCatalog(captured, {})).isSuccess, isTrue);
      expect((await pending).isSuccess, isFalse);
      expect(owner.isAuthorized(captured, 's'), isFalse);
      expect(owner.isAuthorized(captured, 'another-server'), isTrue);
      expect(owner.state.sessions, isEmpty);
      await owner.reconcileCatalog(captured, {'s'});
      expect(owner.isAuthorized(captured, 's'), isTrue);
    },
  );

  test('exit cancels an opened session while negotiation is pending', () async {
    final failed = Completer<Result<McpConnectOutcome>>();
    final opening = owner.run('s', (context) {
      owner.trackOpening(context, 's', session);
      return failed.future;
    });
    when(() => session.close()).thenAnswer((_) async {
      failed.complete(const Result.failure(McpAuthFailure('Session closed')));
      return const Result.success(null);
    });
    expect((await owner.shutdownForExit()).isSuccess, isTrue);
    expect((await opening).isSuccess, isFalse);
    verify(() => session.close()).called(1);
  });

  test(
    'exit is idempotent and future scope updates cannot reopen access',
    () async {
      await owner.run('s', (_) async => Result.success(connected));
      final exiting = owner.shutdownForExit();
      expect(owner.context, isNull);
      expect(owner.shutdownForExit(), same(exiting));
      await owner.switchScope('new', 'new-workspace');
      expect((await exiting).isSuccess, isTrue);
      expect(owner.context, isNull);
      verify(() => session.close()).called(1);
    },
  );

  test('exit returns session cleanup failures', () async {
    await owner.run('s', (_) async => Result.success(connected));
    const failure = McpUnexpectedFailure('Process stop failed');
    when(() => session.close())
        .thenAnswer((_) async => const Result.failure(failure));
    expect((await owner.shutdownForExit()).failureOrNull, same(failure));
  });

  test('boundary revokes immediately and waits for close before enabling next scope', () async {
    await owner.run('s', (_) async => Result.success(connected));
    final old = owner.context!;
    final stopped = Completer<Result<void>>();
    when(() => session.close()).thenAnswer((_) => stopped.future);
    final change = owner.switchScope('next', 'next-workspace');
    expect(owner.context, isNull);
    expect(owner.state.sessions, isEmpty);
    expect(owner.isAuthorized(old, 's'), isFalse);
    stopped.complete(const Result.success(null));
    await change;
    expect(owner.context!.userId, 'next');
    verify(() => session.close()).called(1);
  });

  test('late connect is closed before new scope becomes ready', () async {
    final result = Completer<Result<McpConnectOutcome>>();
    final pending = owner.run('s', (_) => result.future);
    final change = owner.switchScope('next', 'w');
    result.complete(Result.success(connected));
    expect((await pending).isSuccess, isFalse);
    await change;
    verify(() => session.close()).called(1);
    expect(owner.state.sessions, isEmpty);
  });

  test('duplicate connect and session limit cannot start extra work', () async {
    await owner.run('a', (_) async => Result.success(connected));
    final blocked = Completer<Result<McpConnectOutcome>>();
    final pending = owner.run('b', (_) => blocked.future);
    var started = false;
    for (final id in ['a', 'b', 'c']) {
      expect(
        (await owner.run(id, (_) async {
          started = true;
          return Result.success(connected);
        })).isSuccess,
        isFalse,
      );
    }
    expect(started, isFalse);
    blocked.complete(const Result.failure(McpAuthFailure('Cancelled')));
    await pending;
  });

  test('rapid scope changes only activate the newest generation', () async {
    final first = owner.switchScope('old', 'old');
    final second = owner.switchScope('new', 'new');
    await Future.wait([first, second]);
    expect(owner.context!.userId, 'new');
  });

  test(
    'cleanup failures remain visible and do not preserve old sessions',
    () async {
      await owner.run('s', (_) async => Result.success(connected));
      const failure = McpUnexpectedFailure('Could not stop process');
      when(() => session.close())
          .thenAnswer((_) async => const Result.failure(failure));
      await owner.shutdown();
      expect(owner.state.failures, [failure]);
      expect(owner.state.sessions, isEmpty);
      expect(owner.context, isNull);
    },
  );

  test('disconnect awaits close and removes the session', () async {
    await owner.run('s', (_) async => Result.success(connected));
    expect((await owner.disconnect('s')).isSuccess, isTrue);
    expect(owner.state.sessions, isEmpty);
    verify(() => session.close()).called(1);
  });

  test(
    'provider lifecycle loading revokes access and drains sessions',
    () async {
      final container = ProviderContainer(
        overrides: [
          mcpSessionOwnerProvider.overrideWithValue(owner),
          sessionProvider.overrideWith(_User.new),
          currentWorkspaceProvider.overrideWith(
            (ref) async => const Workspace(
              id: 'w',
              organizationId: 'o',
              name: 'Workspace',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      container.listen(mcpLifecycleProvider, (_, _) {});
      await container.read(sessionProvider.future);
      await container.read(currentWorkspaceProvider.future);
      await container.pump();
      await owner.ready;
      expect(owner.context!.userId, 'u');
      await owner.run('s', (_) async => Result.success(connected));
      (container.read(sessionProvider.notifier) as _User).loading();
      await container.pump();
      await owner.ready;
      expect(owner.context, isNull);
      verify(() => session.close()).called(1);
    },
  );
}
