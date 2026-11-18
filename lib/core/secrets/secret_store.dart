import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/secrets/secure_secret_store.dart';

/// Device-only storage for secret values (OS keychain / credential store).
///
/// Secret values never go to Supabase: synced rows keep a placeholder and the
/// real value lives here, on this device only.
abstract interface class SecretStore {
  /// The stored value, or null when nothing is stored under [key].
  Future<Result<String?>> read(String key);

  Future<Result<void>> write(String key, String value);

  Future<Result<void>> delete(String key);
}

final secretStoreProvider = Provider<SecretStore>((ref) => SecureSecretStore());
