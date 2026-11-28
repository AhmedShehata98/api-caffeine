import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/secrets/secret_store.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_catalog_service.dart';

class _Repository implements McpServerRepository {
  final rows = <String, McpServer>{};
  final sent = <McpServerDraft>[];
  bool failUpdates = false;
  bool failDeletes = false;
  int nextId = 0;
  @override
  Future<Result<List<McpServer>>> list(String workspaceId) async =>
      Result.success(
        rows.values.where((row) => row.workspaceId == workspaceId).toList(),
      );
  @override
  Future<Result<McpServer>> create({
    required String workspaceId,
    required McpServerDraft draft,
    int? position,
  }) async {
    sent.add(draft);
    final server = McpServer(
      id: 's${nextId++}',
      workspaceId: workspaceId,
      draft: draft,
      position: position,
    );
    rows[server.id] = server;
    return Result.success(server);
  }

  @override
  Future<Result<McpServer>> update({
    required String workspaceId,
    required String id,
    required McpServerDraft draft,
    int? position,
  }) async {
    if (failUpdates) {
      return const Result.failure(StorageFailure('Database unavailable'));
    }
    sent.add(draft);
    final server = rows[id]!.copyWith(draft: draft, position: position);
    rows[id] = server;
    return Result.success(server);
  }

  @override
  Future<Result<void>> delete({
    required String workspaceId,
    required String id,
  }) async {
    if (failDeletes) {
      return const Result.failure(StorageFailure('Database unavailable'));
    }
    rows.remove(id);
    return const Result.success(null);
  }
}

class _Secrets implements SecretStore {
  final values = <String, String>{};
  final reads = <String>[];
  bool unavailable = false;
  Completer<void>? holdRead;
  final readStarted = Completer<void>();
  @override
  Future<Result<String?>> read(String key) async {
    reads.add(key);
    if (!readStarted.isCompleted) readStarted.complete();
    await holdRead?.future;
    return unavailable
        ? const Result.failure(StorageFailure('Keyring unavailable'))
        : Result.success(values[key]);
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    if (unavailable) {
      return const Result.failure(StorageFailure('Keyring unavailable'));
    }
    values[key] = value;
    return const Result.success(null);
  }

  @override
  Future<Result<void>> delete(String key) async {
    if (unavailable) {
      return const Result.failure(StorageFailure('Keyring unavailable'));
    }
    values.remove(key);
    return const Result.success(null);
  }
}

void main() {
  const context = McpAccessContext(
    userId: 'user-a',
    workspaceId: 'workspace',
    generation: 1,
  );
  const draft = McpServerDraft(
    name: '  Fixture  ',
    transport: McpTransport.http,
    url: 'https://example.test/mcp',
    env: {'TOKEN': 'env-canary', 'PUBLIC': 'visible'},
    headers: {'Authorization': 'Bearer header-canary', 'X-Team': 'team'},
    secretKeys: ['env.TOKEN'],
  );
  late _Repository repository;
  late _Secrets secrets;
  late McpCatalogService service;
  var current = true;
  setUp(() {
    repository = _Repository();
    secrets = _Secrets();
    current = true;
    service = McpCatalogService(
      repository,
      secrets,
      isAuthorized: (_) => current,
    );
  });

  test('create syncs placeholders and hydrates device-only secrets', () async {
    final created = (await service.create(context, draft)).valueOrNull!;
    expect(created.draft.name, 'Fixture');
    expect(repository.sent.single.env['TOKEN'], '');
    expect(repository.sent.single.headers['authorization'], '');
    expect(repository.sent.single.headers['x-team'], 'team');
    expect(repository.sent.single.secretKeys, [
      'env.TOKEN',
      'header.authorization',
    ]);
    expect(
      jsonDecode(
        secrets.values[McpCatalogService.secretsKey('user-a', created.id)]!,
      ),
      {
        'env.TOKEN': 'env-canary',
        'header.authorization': 'Bearer header-canary',
      },
    );
    final loaded = (await service.list(context)).valueOrNull!.single;
    expect(loaded.draft.env['TOKEN'], 'env-canary');
    expect(loaded.secretStates.values, everyElement(SecretValueState.present));
  });

  test(
    'single-server get proves ownership before hydrating local secrets',
    () async {
      final created = (await service.create(context, draft)).valueOrNull!;
      final loaded = (await service.get(context, created.id)).valueOrNull!;
      expect(loaded.draft.env['TOKEN'], 'env-canary');
      secrets.reads.clear();
      expect((await service.get(context, 'missing')).isSuccess, isFalse);
      expect(secrets.reads, isEmpty);
      current = false;
      expect((await service.get(context, created.id)).isSuccess, isFalse);
      expect(secrets.reads, isEmpty);
    },
  );

  test('another account cannot hydrate the first account secrets', () async {
    final created = (await service.create(context, draft)).valueOrNull!;
    const other = McpAccessContext(
      userId: 'user-b',
      workspaceId: 'workspace',
      generation: 2,
    );
    final loaded = (await service.list(other)).valueOrNull!.single;
    expect(loaded.draft.env['TOKEN'], '');
    expect(
      loaded.secretStates.values,
      everyElement(SecretValueState.missingOnDevice),
    );
    expect(secrets.reads, [McpCatalogService.secretsKey('user-b', created.id)]);
  });

  test('non-secret create and delete work without a keyring', () async {
    secrets.unavailable = true;
    final created = (await service.create(
      context,
      const McpServerDraft(
        name: 'Local',
        transport: McpTransport.stdio,
        command: 'dart',
      ),
    )).valueOrNull!;
    expect((await service.delete(context, created.id)).isSuccess, isTrue);
    expect(secrets.reads, isEmpty);
  });

  test(
    'failed secret storage rolls back a newly created catalog row',
    () async {
      secrets.unavailable = true;
      expect(
        (await service.create(context, draft)).failureOrNull,
        isA<McpStorageFailure>(),
      );
      expect(repository.rows, isEmpty);
      expect(secrets.values, isEmpty);
    },
  );

  test('failed create rollback reports the remaining catalog row', () async {
    secrets.unavailable = true;
    repository.failDeletes = true;
    final result = await service.create(context, draft);
    expect(
      result.failureOrNull!.message,
      contains('Server settings were saved'),
    );
    expect(repository.rows, hasLength(1));
    expect(repository.rows.values.single.draft.env['TOKEN'], '');
  });

  test(
    'missing device secrets remain missing through metadata edits',
    () async {
      final created = (await service.create(context, draft)).valueOrNull!;
      secrets.values.clear();
      final loaded = (await service.list(context)).valueOrNull!.single;
      final updated = (await service.update(
        context,
        loaded.copyWith(draft: loaded.draft.copyWith(name: 'Renamed')),
      )).valueOrNull!;
      expect(updated.draft.name, 'Renamed');
      expect(
        updated.secretStates.values,
        everyElement(SecretValueState.missingOnDevice),
      );
      expect(
        secrets.values[McpCatalogService.secretsKey('user-a', created.id)],
        isNull,
      );
    },
  );

  test(
    'failed remote update leaves original device secrets unchanged',
    () async {
      final created = (await service.create(context, draft)).valueOrNull!;
      final before = Map<String, String>.from(secrets.values);
      repository.failUpdates = true;
      final result = await service.update(
        context,
        created.copyWith(
          draft: created.draft.copyWith(
            env: {...created.draft.env, 'TOKEN': 'new-canary'},
          ),
        ),
      );
      expect(result.failureOrNull, isA<StorageFailure>());
      expect(secrets.values, before);
    },
  );

  test(
    'confirmed plaintext header override removes the old local secret',
    () async {
      final created = (await service.create(
        context,
        draft.copyWith(env: {}, secretKeys: []),
      )).valueOrNull!;
      final result = await service.update(
        context,
        created.copyWith(draft: created.draft.copyWith(secretKeys: [])),
        confirmedPlaintextHeaders: {'Authorization'},
      );
      expect(result.isSuccess, isTrue);
      expect(repository.sent.last.secretKeys, isEmpty);
      expect(
        repository.sent.last.headers['authorization'],
        'Bearer header-canary',
      );
      expect(secrets.values, isEmpty);
    },
  );

  test('deleting a server removes its device secrets', () async {
    final created = (await service.create(context, draft)).valueOrNull!;
    expect((await service.delete(context, created.id)).isSuccess, isTrue);
    expect(repository.rows, isEmpty);
    expect(secrets.values, isEmpty);
  });

  test('failed remote deletion restores existing device secrets', () async {
    final created = (await service.create(context, draft)).valueOrNull!;
    final before = Map<String, String>.from(secrets.values);
    repository.failDeletes = true;
    expect(
      (await service.delete(context, created.id)).failureOrNull,
      isA<StorageFailure>(),
    );
    expect(repository.rows, hasLength(1));
    expect(secrets.values, before);
  });

  test('foreign or nonexistent servers never trigger secret lookups', () async {
    const forged = McpServer(id: 'foreign', workspaceId: 'other', draft: draft);
    expect(
      (await service.update(context, forged)).failureOrNull,
      isA<McpAuthFailure>(),
    );
    expect(
      (await service.delete(context, 'foreign')).failureOrNull,
      isA<McpValidationFailure>(),
    );
    expect(secrets.reads, isEmpty);
  });

  test(
    'corrupt device storage fails visibly rather than overwriting values',
    () async {
      final created = (await service.create(context, draft)).valueOrNull!;
      final key = McpCatalogService.secretsKey('user-a', created.id);
      secrets.values[key] = '{broken';
      expect(
        (await service.list(context)).failureOrNull,
        isA<McpStorageFailure>(),
      );
      expect(
        (await service.update(context, created)).failureOrNull,
        isA<McpStorageFailure>(),
      );
      expect(secrets.values[key], '{broken');
    },
  );

  test('account changes discard late secret reads', () async {
    await service.create(context, draft);
    secrets.holdRead = Completer<void>();
    final operation = service.list(context);
    await secrets.readStarted.future;
    current = false;
    secrets.holdRead!.complete();
    expect((await operation).failureOrNull, isA<McpAuthFailure>());
    final count = secrets.reads.length;
    expect((await service.list(context)).failureOrNull, isA<McpAuthFailure>());
    expect(secrets.reads.length, count);
  });
}
