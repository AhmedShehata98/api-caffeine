import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/secrets/secret_store.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_trust_repository_impl.dart';

import 'trust_digest_checks.dart' as digest_checks;

class _Secrets implements SecretStore {
  final values = <String, String>{};
  final reads = <String>[];
  final readStarted = Completer<void>();
  bool unavailable = false;
  Completer<void>? gate;
  @override
  Future<Result<String?>> read(String key) async {
    reads.add(key);
    if (!readStarted.isCompleted) readStarted.complete();
    await gate?.future;
    return unavailable
        ? const Result.failure(McpStorageFailure('Unavailable'))
        : Result.success(values[key]);
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    if (unavailable) {
      return const Result.failure(McpStorageFailure('Unavailable'));
    }
    values[key] = value;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    values.remove(key);
    return const Result.success(null);
  }
}

void main() {
  test('launch snapshot and trust digest invariants', digest_checks.main);
  const context = McpAccessContext(
    userId: 'user-a',
    workspaceId: 'workspace',
    generation: 1,
  );
  McpLaunchSnapshot snapshot([String token = 'canary']) => McpLaunchSnapshot(
    command: 'dart',
    executable: '/sdk/dart',
    cwd: '/workspace',
    args: ['server.dart'],
    environment: {'TOKEN': token},
  );

  test('approvals stay local, missing device keys fail closed and clear removes approval', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = _Secrets();
    final repository = McpTrustRepositoryImpl(
      prefs,
      secrets,
      isAuthorized: (scope, server) =>
          scope.userId == context.userId && server == 'server',
    );
    expect(
      (await repository.check(
        context,
        'server',
        snapshot(),
      )).valueOrNull!.approved,
      isFalse,
    );
    expect(
      (await repository.approve(context, 'server', snapshot())).isSuccess,
      isTrue,
    );
    expect(
      (await repository.check(
        context,
        'server',
        snapshot(),
      )).valueOrNull!.approved,
      isTrue,
    );
    expect(
      prefs.getString(McpTrustRepositoryImpl.recordKey('user-a', 'server')),
      isNot(contains('canary')),
    );
    expect(secrets.values.keys, [McpTrustRepositoryImpl.deviceKey('user-a')]);
    expect(
      (await repository.check(
        context,
        'server',
        snapshot('changed'),
      )).valueOrNull!.changedFields,
      ['env.TOKEN'],
    );
    secrets.values.clear();
    expect(
      (await repository.check(
        context,
        'server',
        snapshot(),
      )).valueOrNull!.approved,
      isFalse,
    );
    expect(
      (await repository.approve(context, 'server', snapshot())).isSuccess,
      isTrue,
    );
    expect((await repository.clear(context, 'server')).isSuccess, isTrue);
    expect(
      (await repository.check(
        context,
        'server',
        snapshot(),
      )).valueOrNull!.approved,
      isFalse,
    );
  });

  test('unavailable secure storage cannot persist approval', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = _Secrets()..unavailable = true;
    final repository = McpTrustRepositoryImpl(
      prefs,
      secrets,
      isAuthorized: (_, _) => true,
    );
    expect(
      (await repository.approve(context, 'server', snapshot())).failureOrNull,
      isA<McpStorageFailure>(),
    );
    expect(prefs.getKeys(), isEmpty);
  });

  test('account generation changes reject late reads and never read another user key', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final secrets = _Secrets()..gate = Completer<void>();
    var current = true;
    final repository = McpTrustRepositoryImpl(
      prefs,
      secrets,
      isAuthorized: (_, _) => current,
    );
    final operation = repository.approve(context, 'server', snapshot());
    await secrets.readStarted.future;
    current = false;
    secrets.gate!.complete();
    expect((await operation).failureOrNull, isA<McpAuthFailure>());
    expect(secrets.values, isEmpty);
    expect(prefs.getKeys(), isEmpty);
    final count = secrets.reads.length;
    expect(
      (await repository.check(context, 'server', snapshot())).failureOrNull,
      isA<McpAuthFailure>(),
    );
    expect(secrets.reads.length, count);
  });
}
