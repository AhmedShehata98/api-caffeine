import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/modules/environments/environments.dart';
import 'package:api_caffeine/modules/environments/services/environment_service.dart';

import '../../../support/fake_backend.dart';

void main() {
  late FakeStore store;
  late EnvironmentService service;

  setUp(() {
    store = FakeStore(
      environments: const [
        Environment(id: 'e1', workspaceId: 'ws-1', name: 'Dev'),
      ],
    );
    service = EnvironmentService(
      FakeEnvironmentRepository(store),
      FakeSecretStore(store),
    );
  });

  /// What Supabase holds for environment [id].
  List<EnvironmentVariable> synced([String id = 'e1']) =>
      store.environments.firstWhere((e) => e.id == id).variables;

  /// What this device's secure storage holds for environment [id].
  Map<String, dynamic>? onDevice([String id = 'e1']) {
    final raw = store.secrets[EnvironmentService.secretsKey(id)];
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  test('create trims the name and rejects blanks', () async {
    final ok = await service.create(workspaceId: 'ws-1', name: '  Staging ');
    expect(ok.valueOrNull!.name, 'Staging');

    final blank = await service.create(workspaceId: 'ws-1', name: ' ');
    expect(blank.failureOrNull, isA<ValidationFailure>());
    expect(store.environments, hasLength(2));
  });

  test('saveVariables drops blank rows and trims keys', () async {
    final result = await service.saveVariables('e1', const [
      EnvironmentVariable(key: ' host ', value: 'a.test'),
      EnvironmentVariable(),
    ]);
    expect(result.valueOrNull!.variables, [
      const EnvironmentVariable(key: 'host', value: 'a.test'),
    ]);
  });

  test(
    'saveVariables rejects keys that cannot be written as {{key}}',
    () async {
      for (final key in ['two words', 'a{b', '']) {
        final result = await service.saveVariables('e1', [
          EnvironmentVariable(key: key, value: 'x'),
        ]);
        expect(result.failureOrNull, isA<ValidationFailure>(), reason: key);
      }
      expect(store.environments.single.variables, isEmpty);
    },
  );

  group('secret values', () {
    test('stay on the device; the database gets a placeholder', () async {
      final result = await service.saveVariables('e1', const [
        EnvironmentVariable(key: 'host', value: 'a.test'),
        EnvironmentVariable(key: 'token', value: 's3cret', secret: true),
      ]);

      expect(synced(), const [
        EnvironmentVariable(key: 'host', value: 'a.test'),
        EnvironmentVariable(key: 'token', secret: true),
      ]);
      expect(onDevice(), {'token': 's3cret'});
      expect(result.valueOrNull!.values, {'host': 'a.test', 'token': 's3cret'});
    });

    test('are filled in from the device when listing', () async {
      await service.saveVariables('e1', const [
        EnvironmentVariable(key: 'token', value: 's3cret', secret: true),
      ]);

      final listed = (await service.list('ws-1')).valueOrNull!.single;
      expect(listed.variables.single.value, 's3cret');
      expect(listed.variables.single.missingOnDevice, isFalse);
    });

    test('set on another device are marked and left unresolved', () async {
      store.environments[0] = store.environments[0].copyWith(
        variables: const [EnvironmentVariable(key: 'token', secret: true)],
      );

      final listed = (await service.list('ws-1')).valueOrNull!.single;
      expect(listed.variables.single.missingOnDevice, isTrue);
      expect(listed.values, isEmpty);
    });

    test('keep a missing secret missing when other rows are saved', () async {
      final result = await service.saveVariables('e1', const [
        EnvironmentVariable(key: 'token', secret: true, missingOnDevice: true),
        EnvironmentVariable(key: 'host', value: 'a.test'),
      ]);

      expect(onDevice(), isNull);
      expect(result.valueOrNull!.variables.first.missingOnDevice, isTrue);
    });

    test(
      'synced as plain text by an older version move to the device',
      () async {
        store.environments[0] = store.environments[0].copyWith(
          variables: const [
            EnvironmentVariable(key: 'token', value: 'legacy', secret: true),
          ],
        );

        final listed = (await service.list('ws-1')).valueOrNull!.single;

        expect(listed.variables.single.value, 'legacy');
        expect(onDevice(), {'token': 'legacy'});
        expect(synced().single.value, isEmpty);
      },
    );

    test('a value already on the device wins over a legacy one', () async {
      store.secrets[EnvironmentService.secretsKey('e1')] = '{"token":"new"}';
      store.environments[0] = store.environments[0].copyWith(
        variables: const [
          EnvironmentVariable(key: 'token', value: 'old', secret: true),
        ],
      );

      final listed = (await service.list('ws-1')).valueOrNull!.single;
      expect(listed.variables.single.value, 'new');
    });

    test(
      'turning the flag off syncs the value and clears the device',
      () async {
        await service.saveVariables('e1', const [
          EnvironmentVariable(key: 'token', value: 's3cret', secret: true),
        ]);
        await service.saveVariables('e1', const [
          EnvironmentVariable(key: 'token', value: 's3cret'),
        ]);

        expect(synced().single.value, 's3cret');
        expect(onDevice(), isNull);
      },
    );

    test('are removed from the device with the environment', () async {
      await service.saveVariables('e1', const [
        EnvironmentVariable(key: 'token', value: 's3cret', secret: true),
      ]);

      expect((await service.delete('e1')).isSuccess, isTrue);
      expect(store.secrets, isEmpty);
    });

    test('are not synced when secure storage fails', () async {
      store.secretFailure = const StorageFailure('unavailable');

      final result = await service.saveVariables('e1', const [
        EnvironmentVariable(key: 'token', value: 's3cret', secret: true),
      ]);

      expect(result.failureOrNull, isA<StorageFailure>());
      expect(synced(), isEmpty);
    });

    test(
      'unreadable device data fails the load instead of being lost',
      () async {
        store.secrets[EnvironmentService.secretsKey('e1')] = 'not json';
        store.environments[0] = store.environments[0].copyWith(
          variables: const [EnvironmentVariable(key: 'token', secret: true)],
        );

        final result = await service.list('ws-1');
        expect(result.failureOrNull, isA<StorageFailure>());
        expect(store.secrets, isNotEmpty);
      },
    );

    test('environments without secrets work without secure storage', () async {
      store.secretFailure = const StorageFailure('unavailable');

      final saved = await service.saveVariables('e1', const [
        EnvironmentVariable(key: 'host', value: 'a.test'),
      ]);
      expect(saved.isSuccess, isTrue);
      expect((await service.list('ws-1')).isSuccess, isTrue);
    });
  });
}
