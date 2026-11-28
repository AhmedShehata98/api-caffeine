import 'dart:convert';

import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/secrets/secret_store.dart';
import 'package:api_caffeine/core/utils/names.dart';
import 'package:api_caffeine/modules/environments/models/environment.dart';
import 'package:api_caffeine/modules/environments/models/environment_variable.dart';
import 'package:api_caffeine/modules/environments/repositories/environment_repository.dart';

/// Environment rules (names, variable keys) on top of the repository.
///
/// Secret values stay on this device: the repository (Supabase) only ever
/// receives secret rows with an empty `value` placeholder, and the real
/// values of one environment are kept in the [SecretStore] as a JSON map
/// `{key: value}`.
class EnvironmentService {
  EnvironmentService(this._repository, this._secrets);

  final EnvironmentRepository _repository;
  final SecretStore _secrets;

  /// [SecretStore] key that holds the secret values of one environment.
  static String secretsKey(String environmentId) =>
      'environment-secrets:$environmentId';

  Future<Result<List<Environment>>> list(String workspaceId) async {
    final result = await _repository.list(workspaceId);
    final environments = result.valueOrNull;
    if (environments == null) return result;
    final loaded = <Environment>[];
    for (final environment in environments) {
      switch (await _attachSecrets(environment)) {
        case Success(:final value):
          loaded.add(value);
        case Err(:final failure):
          return Result.failure(failure);
      }
    }
    return Result.success(loaded);
  }

  Future<Result<Environment>> create({
    required String workspaceId,
    required String name,
  }) {
    final valid = validateName(name, label: 'Environment name');
    if (valid.failure != null) {
      return Future.value(Result.failure(valid.failure!));
    }
    return _repository.create(workspaceId: workspaceId, name: valid.name!);
  }

  Future<Result<Environment>> rename(String id, String name) async {
    final valid = validateName(name, label: 'Environment name');
    if (valid.failure != null) return Result.failure(valid.failure!);
    return switch (await _repository.rename(id, valid.name!)) {
      Success(:final value) => _attachSecrets(value),
      Err(:final failure) => Result.failure(failure),
    };
  }

  /// Blank rows are dropped; keys must not contain whitespace or braces so
  /// they can be written as `{{key}}`. Secret values are written to this
  /// device and replaced by the placeholder before they are synced.
  Future<Result<Environment>> saveVariables(
    String id,
    List<EnvironmentVariable> variables,
  ) async {
    final cleaned = [
      for (final v in variables)
        if (v.key.trim().isNotEmpty || v.value.isNotEmpty)
          v.copyWith(key: v.key.trim()),
    ];
    for (final v in cleaned) {
      if (v.key.isEmpty || RegExp(r'[\s{}]').hasMatch(v.key)) {
        return Result.failure(
          ValidationFailure(
            v.key.isEmpty
                ? 'Every variable needs a name.'
                : 'Variable "${v.key}" must not contain spaces or braces.',
          ),
        );
      }
    }

    // Secrets not set on this device stay unset; there is nothing to keep.
    final local = {
      for (final v in cleaned)
        if (v.secret && !v.missingOnDevice) v.key: v.value,
    };
    final stored = await _storeSecrets(id, local);
    if (stored case Err(:final failure)) return Result.failure(failure);

    return switch (await _repository.saveVariables(
      id,
      _placeholders(cleaned),
    )) {
      Success(:final value) => Result.success(
        value.copyWith(variables: _merge(value.variables, local)),
      ),
      Err(:final failure) => Result.failure(failure),
    };
  }

  Future<Result<void>> delete(String id) async {
    final result = await _repository.delete(id);
    if (!result.isSuccess) return result;
    return _secrets.delete(secretsKey(id));
  }

  /// Fills secret rows with this device's values. Secrets that an older
  /// version synced as plain text are moved to the device first, then
  /// replaced by the placeholder in the database.
  Future<Result<Environment>> _attachSecrets(Environment environment) async {
    final secrets = environment.variables.where((v) => v.secret).toList();
    if (secrets.isEmpty) return Result.success(environment);

    final Map<String, String> local;
    switch (await _readSecrets(environment.id)) {
      case Success(:final value):
        local = {...value};
      case Err(:final failure):
        return Result.failure(failure);
    }

    final plaintext = secrets.where((v) => v.value.isNotEmpty).toList();
    if (plaintext.isNotEmpty) {
      for (final v in plaintext) {
        local.putIfAbsent(v.key, () => v.value);
      }
      final stored = await _storeSecrets(environment.id, local);
      if (stored case Err(:final failure)) return Result.failure(failure);
      final stripped = await _repository.saveVariables(
        environment.id,
        _placeholders(environment.variables),
      );
      if (stripped case Err(:final failure)) return Result.failure(failure);
    }

    return Result.success(
      environment.copyWith(variables: _merge(environment.variables, local)),
    );
  }

  Future<Result<Map<String, String>>> _readSecrets(String id) async {
    switch (await _secrets.read(secretsKey(id))) {
      case Err(:final failure):
        return Result.failure(failure);
      case Success(:final value):
        if (value == null) return const Result.success({});
        try {
          final decoded = jsonDecode(value) as Map<String, dynamic>;
          return Result.success(decoded.cast<String, String>());
        } on Object {
          // Fail visibly; saving would overwrite values we cannot read.
          return const Result.failure(
            StorageFailure(
              'Secret values saved on this device are unreadable.',
            ),
          );
        }
    }
  }

  Future<Result<void>> _storeSecrets(
    String id,
    Map<String, String> values,
  ) async {
    if (values.isNotEmpty) {
      return _secrets.write(secretsKey(id), jsonEncode(values));
    }
    // Nothing secret to keep: clearing old values is best effort. When the
    // store is unavailable nothing can have been saved in it, and failing
    // here would block environments that have no secrets at all.
    await _secrets.delete(secretsKey(id));
    return const Result.success(null);
  }

  /// The rows as synced: every secret value replaced by the placeholder.
  static List<EnvironmentVariable> _placeholders(
    List<EnvironmentVariable> variables,
  ) => [for (final v in variables) v.secret ? v.copyWith(value: '') : v];

  /// The rows as shown on this device: secrets filled from [local], or
  /// marked [EnvironmentVariable.missingOnDevice] when it has no value.
  static List<EnvironmentVariable> _merge(
    List<EnvironmentVariable> variables,
    Map<String, String> local,
  ) => [
    for (final v in variables)
      if (!v.secret)
        v
      else if (local[v.key] case final value?)
        v.copyWith(value: value, missingOnDevice: false)
      else
        v.copyWith(value: '', missingOnDevice: true),
  ];
}
