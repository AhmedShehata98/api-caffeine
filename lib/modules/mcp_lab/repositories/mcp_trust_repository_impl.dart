import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/secrets/secret_store.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import 'mcp_trust_digest.dart';
import 'mcp_trust_repository.dart';

/// Authorization must check current user/workspace/generation and server access.
typedef McpTrustAuthorization = bool Function(
  McpAccessContext context,
  String serverId,
);

class McpTrustRepositoryImpl implements McpTrustRepository {
  McpTrustRepositoryImpl(
    this._preferences,
    this._secrets, {
    required this.isAuthorized,
  });
  final SharedPreferences _preferences;
  final SecretStore _secrets;
  final McpTrustAuthorization isAuthorized;
  Future<void> _queue = Future.value();

  static String recordKey(String userId, String serverId) =>
      'mcp-trust:$userId:$serverId';
  static String deviceKey(String userId) => 'mcp-trust-key:$userId';
  static const _storageFailure = McpStorageFailure(
    'Could not access launch approvals on this device.',
  );
  static const _accessFailure = McpAuthFailure(
    'The account or workspace changed. Reload the server before connecting.',
  );

  // Serialize key creation and preference writes within this device repository.
  Future<Result<T>> _run<T>(Future<Result<T>> Function() operation) {
    final result = _queue.then((_) async {
      try {
        return await operation();
      } on Object {
        return Result<T>.failure(_storageFailure);
      }
    });
    _queue = result.then<void>((_) {});
    return result;
  }

  @override
  Future<Result<McpTrustCheck>> check(
    McpAccessContext context,
    String serverId,
    McpLaunchSnapshot snapshot,
  ) => _run(() async {
    if (!isAuthorized(context, serverId)) {
      return const Result.failure(_accessFailure);
    }
    final keyResult = await _secrets.read(deviceKey(context.userId));
    if (!isAuthorized(context, serverId)) {
      return const Result.failure(_accessFailure);
    }
    if (keyResult case Err()) return const Result.failure(_storageFailure);
    final encoded = keyResult.valueOrNull;
    // Missing key means unapproved, even when preferences retain an old record.
    if (encoded == null) return Result.success(McpTrustCheck(approved: false));
    final key = base64Decode(encoded);
    if (key.length != 32) return const Result.failure(_storageFailure);
    final raw = _preferences.getString(recordKey(context.userId, serverId));
    McpTrustRecord? stored;
    if (raw != null) {
      try {
        stored = McpTrustRecord.fromJson(
          jsonDecode(raw) as Map<String, dynamic>,
        );
      } on FormatException {
        return Result.success(McpTrustCheck(approved: false));
      }
    }
    return Result.success(
      compareMcpTrust(
        stored,
        digestMcpLaunch(
          deviceKey: key,
          context: context,
          serverId: serverId,
          snapshot: snapshot,
        ),
      ),
    );
  });

  @override
  Future<Result<void>> approve(
    McpAccessContext context,
    String serverId,
    McpLaunchSnapshot snapshot,
  ) => _run(() async {
    if (!isAuthorized(context, serverId)) {
      return const Result.failure(_accessFailure);
    }
    final keyResult = await _secrets.read(deviceKey(context.userId));
    if (!isAuthorized(context, serverId)) {
      return const Result.failure(_accessFailure);
    }
    if (keyResult case Err()) return const Result.failure(_storageFailure);
    final existing = keyResult.valueOrNull;
    final random = Random.secure();
    final key = existing == null
        ? List<int>.generate(32, (_) => random.nextInt(256))
        : base64Decode(existing);
    if (key.length != 32) return const Result.failure(_storageFailure);
    if (existing == null) {
      final saved = await _secrets.write(
        deviceKey(context.userId),
        base64Encode(key),
      );
      if (!isAuthorized(context, serverId)) {
        return const Result.failure(_accessFailure);
      }
      if (saved case Err()) return const Result.failure(_storageFailure);
    }
    final record = digestMcpLaunch(
      deviceKey: key,
      context: context,
      serverId: serverId,
      snapshot: snapshot,
    );
    final recordName = recordKey(context.userId, serverId);
    final saved = await _preferences.setString(
      recordName,
      jsonEncode(record.toJson()),
    );
    if (!saved) {
      // SharedPreferences updates its cache before persistence completes.
      await _preferences.remove(recordName);
      return const Result.failure(_storageFailure);
    }
    if (!isAuthorized(context, serverId)) {
      // Remove this late write; it must not authorize a subsequent operation.
      await _preferences.remove(recordName);
      return const Result.failure(_accessFailure);
    }
    return const Result.success(null);
  });

  @override
  Future<Result<void>> clear(McpAccessContext context, String serverId) =>
      _run(() async {
        if (!isAuthorized(context, serverId)) {
          return const Result.failure(_accessFailure);
        }
        final removed = await _preferences.remove(
          recordKey(context.userId, serverId),
        );
        if (!isAuthorized(context, serverId)) {
          return const Result.failure(_accessFailure);
        }
        return removed
            ? const Result.success(null)
            : const Result.failure(_storageFailure);
      });
}
