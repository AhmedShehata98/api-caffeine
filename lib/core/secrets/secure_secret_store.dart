import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/secrets/secret_store.dart';

/// [SecretStore] backed by the OS secure store: Keychain on macOS,
/// Credential Manager + an encrypted file on Windows, libsecret on Linux.
class SecureSecretStore implements SecretStore {
  SecureSecretStore([FlutterSecureStorage? storage])
    : _storage = storage ?? const FlutterSecureStorage(mOptions: _macOs);

  // The legacy keychain needs no `keychain-access-groups` entitlement or
  // provisioning profile, so debug builds on any Mac can use it.
  static const _macOs = MacOsOptions(usesDataProtectionKeychain: false);

  static const _unavailable = StorageFailure(
    'Secure storage is unavailable on this device, so secret values '
    'cannot be read or saved.',
  );

  final FlutterSecureStorage _storage;

  @override
  Future<Result<String?>> read(String key) async {
    try {
      return Result.success(await _storage.read(key: key));
    } on Object {
      return const Result.failure(_unavailable);
    }
  }

  @override
  Future<Result<void>> write(String key, String value) async {
    try {
      await _storage.write(key: key, value: value);
      return const Result.success(null);
    } on Object {
      return const Result.failure(_unavailable);
    }
  }

  @override
  Future<Result<void>> delete(String key) async {
    try {
      await _storage.delete(key: key);
      return const Result.success(null);
    } on Object {
      return const Result.failure(_unavailable);
    }
  }
}
