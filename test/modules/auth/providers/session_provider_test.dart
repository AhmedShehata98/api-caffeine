import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/modules/auth/auth.dart';

import '../../../support/fake_backend.dart';

ProviderContainer _container(AuthRepository repository) =>
    ProviderContainer.test(
      overrides: [authRepositoryProvider.overrideWithValue(repository)],
    );

void main() {
  test('reuses the stored session without signing in again', () async {
    const stored = AuthUser(id: 'u1', isAnonymous: false, email: 'a@b.co');
    final repository = stubAuth(user: stored);

    final user = await _container(repository).read(sessionProvider.future);

    expect(user, stored);
    verifyNever(() => repository.signInAnonymously());
  });

  test('starts a guest session when none is stored', () async {
    final repository = stubAuth(user: null);

    final user = await _container(repository).read(sessionProvider.future);

    expect(user, guestUser);
    verify(() => repository.signInAnonymously()).called(1);
  });

  test('exposes the failure when guest sign-in fails', () async {
    final repository = stubAuth(user: null);
    when(
      () => repository.signInAnonymously(),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure('offline')));
    final container = _container(repository);

    await expectLater(
      container.read(sessionProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
  });

  test('waits for session restoration before exposing a user', () async {
    final repository = stubAuth(user: guestUser);
    final restore = Completer<Result<AuthUser?>>();
    when(() => repository.restoreSession()).thenAnswer((_) => restore.future);
    final container = _container(repository);

    final user = container.read(sessionProvider.future);
    expect(container.read(sessionProvider).isLoading, isTrue);

    when(() => repository.currentUser).thenReturn(null);
    restore.complete(const Result.success(null));
    expect(await user, guestUser);
    verify(() => repository.signInAnonymously()).called(1);
  });

  test('starts a new guest when Supabase clears the active session', () async {
    const stored = AuthUser(id: 'u1', isAnonymous: false);
    final repository = stubAuth(user: stored);
    final changes = StreamController<AuthUser?>.broadcast();
    addTearDown(changes.close);
    when(() => repository.userChanges).thenAnswer((_) => changes.stream);
    final container = _container(repository);
    final recovered = Completer<AuthUser>();
    container.listen(sessionProvider, (_, next) {
      if (next.value case final user? when user.isAnonymous) {
        recovered.complete(user);
      }
    });

    expect(await container.read(sessionProvider.future), stored);
    when(() => repository.currentUser).thenReturn(null);
    changes.add(null);

    expect(await recovered.future, guestUser);
    verify(() => repository.signInAnonymously()).called(1);
  });

  test('keeps the stored account when restoration fails offline', () async {
    final repository = stubAuth();
    when(
      () => repository.restoreSession(),
    ).thenAnswer((_) async => const Result.failure(NetworkFailure('offline')));
    final container = _container(repository);

    await expectLater(
      container.read(sessionProvider.future),
      throwsA(isA<NetworkFailure>()),
    );
    verifyNever(() => repository.signInAnonymously());
  });

  test('AuthUser.initial uses the email, or ? without one', () {
    expect(
      const AuthUser(id: '1', isAnonymous: false, email: 'zed@x.co').initial,
      'Z',
    );
    expect(guestUser.initial, '?');
  });
}
