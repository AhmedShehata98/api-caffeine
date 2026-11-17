import 'dart:convert';

import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/secrets/secret_store.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import '../repositories/mcp_server_repository.dart';
import 'mcp_server_validator.dart';

/// Authorization checks the captured current user/workspace/generation.
typedef McpCatalogAuthorization = bool Function(McpAccessContext context);

class McpCatalogService {
  McpCatalogService(
    this._repository,
    this._secrets, {
    required this.isAuthorized,
  });
  final McpServerRepository _repository;
  final SecretStore _secrets;
  final McpCatalogAuthorization isAuthorized;
  Future<void> _queue = Future.value();
  static const _accessFailure = McpAuthFailure(
    'The account or workspace changed. Reload the server catalog.',
  );
  static const _storageFailure = McpStorageFailure(
    'Could not access MCP secrets on this device.',
  );
  static String secretsKey(String userId, String serverId) =>
      'mcp-server-secrets:$userId:$serverId';

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

  Future<Result<List<McpServer>>> list(McpAccessContext context) =>
      _run(() async {
        final rows = await _authorizedRows(context);
        if (rows case Err(:final failure)) return Result.failure(failure);
        final loaded = <McpServer>[];
        for (final server in rows.valueOrNull!) {
          final local = await _read(context, server);
          if (local case Err(:final failure)) return Result.failure(failure);
          loaded.add(_merge(server, local.valueOrNull!));
        }
        if (!isAuthorized(context)) return const Result.failure(_accessFailure);
        return Result.success(loaded);
      });

  /// Reloads ownership before reading this device's secrets for one server.
  Future<Result<McpServer>> get(McpAccessContext context, String serverId) =>
      _run(() async {
        final found = await _find(context, serverId);
        if (found case Err(:final failure)) return Result.failure(failure);
        final server = found.valueOrNull!;
        final local = await _read(context, server);
        if (local case Err(:final failure)) return Result.failure(failure);
        if (!isAuthorized(context)) return const Result.failure(_accessFailure);
        return Result.success(_merge(server, local.valueOrNull!));
      });

  Future<Result<McpServer>> create(
    McpAccessContext context,
    McpServerDraft draft, {
    int? position,
    Set<String> confirmedPlaintextHeaders = const {},
  }) => _run(() async {
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    final valid = validateMcpServerDraft(
      draft,
      confirmedPlaintextHeaders: confirmedPlaintextHeaders,
    );
    if (valid case Err(:final failure)) return Result.failure(failure);
    final clean = valid.valueOrNull!;
    final local = _extract(clean, const {}, const {});
    final created = await _repository.create(
      workspaceId: context.workspaceId,
      draft: _placeholders(clean),
      position: position,
    );
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    if (created case Err(:final failure)) return Result.failure(failure);
    final server = created.valueOrNull!;
    if (server.workspaceId != context.workspaceId) {
      return const Result.failure(_accessFailure);
    }
    if (local.isNotEmpty) {
      final saved = await _write(context, server.id, local);
      if (saved case Err(:final failure)) {
        if (!isAuthorized(context)) return const Result.failure(_accessFailure);
        final rollback = await _repository.delete(
          workspaceId: context.workspaceId,
          id: server.id,
        );
        if (!isAuthorized(context)) return const Result.failure(_accessFailure);
        if (rollback case Err()) {
          return const Result.failure(
            McpStorageFailure(
              'Server settings were saved, but device secrets could not be saved. Reload before retrying.',
            ),
          );
        }
        return Result.failure(failure);
      }
    }
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    return Result.success(_merge(server, local));
  });

  Future<Result<McpServer>> update(
    McpAccessContext context,
    McpServer edited, {
    Set<String> confirmedPlaintextHeaders = const {},
  }) => _run(() async {
    if (edited.workspaceId != context.workspaceId) {
      return const Result.failure(_accessFailure);
    }
    final valid = validateMcpServerDraft(
      edited.draft,
      confirmedPlaintextHeaders: confirmedPlaintextHeaders,
    );
    if (valid case Err(:final failure)) return Result.failure(failure);
    final found = await _find(context, edited.id);
    if (found case Err(:final failure)) return Result.failure(failure);
    final current = found.valueOrNull!;
    final old = await _read(context, current);
    if (old case Err(:final failure)) return Result.failure(failure);
    final clean = valid.valueOrNull!;
    final local = _extract(clean, old.valueOrNull!, edited.secretStates);
    final saved = await _repository.update(
      workspaceId: context.workspaceId,
      id: edited.id,
      draft: _placeholders(clean),
      position: edited.position,
    );
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    if (saved case Err(:final failure)) return Result.failure(failure);
    final server = saved.valueOrNull!;
    if (server.workspaceId != context.workspaceId) {
      return const Result.failure(_accessFailure);
    }
    // Database first: failed remote saves cannot overwrite existing device values.
    if (current.draft.secretKeys.isNotEmpty || clean.secretKeys.isNotEmpty) {
      final stored = await _write(context, server.id, local);
      if (stored case Err()) {
        if (!isAuthorized(context)) return const Result.failure(_accessFailure);
        return const Result.failure(
          McpStorageFailure(
            'Server settings were saved, but device secrets could not be updated. Reload before reconnecting.',
          ),
        );
      }
    }
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    return Result.success(_merge(server, local));
  });

  Future<Result<void>> delete(McpAccessContext context, String serverId) =>
      _run(() async {
        final found = await _find(context, serverId);
        if (found case Err(:final failure)) return Result.failure(failure);
        final current = found.valueOrNull!;
        final old = await _read(context, current);
        if (old case Err(:final failure)) return Result.failure(failure);
        // Device cleanup first keeps a failed cleanup retryable in the catalog.
        if (current.draft.secretKeys.isNotEmpty) {
          final cleared = await _write(context, serverId, const {});
          if (cleared case Err(:final failure)) return Result.failure(failure);
        }
        final deleted = await _repository.delete(
          workspaceId: context.workspaceId,
          id: serverId,
        );
        if (!isAuthorized(context)) return const Result.failure(_accessFailure);
        if (deleted case Err() when old.valueOrNull!.isNotEmpty) {
          final restored = await _write(context, serverId, old.valueOrNull!);
          if (restored case Err(:final failure)) return Result.failure(failure);
        }
        return deleted;
      });

  Future<Result<List<McpServer>>> _authorizedRows(
    McpAccessContext context,
  ) async {
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    final result = await _repository.list(context.workspaceId);
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    if (result case Success(:final value)
        when value.any((row) => row.workspaceId != context.workspaceId)) {
      return const Result.failure(_accessFailure);
    }
    return result;
  }

  Future<Result<McpServer>> _find(
    McpAccessContext context,
    String serverId,
  ) async {
    final result = await _authorizedRows(context);
    if (result case Err(:final failure)) return Result.failure(failure);
    for (final row in result.valueOrNull!) {
      if (row.id == serverId) return Result.success(row);
    }
    return const Result.failure(
      McpValidationFailure(
        'Server is no longer available in this workspace.',
        code: McpErrorCode.invalidParams,
      ),
    );
  }

  Future<Result<Map<String, String>>> _read(
    McpAccessContext context,
    McpServer server,
  ) async {
    if (!isAuthorized(context) || server.workspaceId != context.workspaceId) {
      return const Result.failure(_accessFailure);
    }
    if (server.draft.secretKeys.isEmpty) return const Result.success({});
    final result = await _secrets.read(secretsKey(context.userId, server.id));
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    if (result case Err()) return const Result.failure(_storageFailure);
    final raw = result.valueOrNull;
    if (raw == null) return const Result.success({});
    try {
      final map = Map<String, String>.from(jsonDecode(raw) as Map);
      return Result.success(map);
    } on Object {
      return const Result.failure(_storageFailure);
    }
  }

  Future<Result<void>> _write(
    McpAccessContext context,
    String serverId,
    Map<String, String> local,
  ) async {
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    final result = local.isEmpty
        ? await _secrets.delete(secretsKey(context.userId, serverId))
        : await _secrets.write(
            secretsKey(context.userId, serverId),
            jsonEncode(local),
          );
    if (!isAuthorized(context)) return const Result.failure(_accessFailure);
    return result.isSuccess
        ? const Result.success(null)
        : const Result.failure(_storageFailure);
  }

  McpServerDraft _placeholders(McpServerDraft draft) => draft.copyWith(
    env: {
      for (final entry in draft.env.entries)
        entry.key: draft.secretKeys.contains('env.${entry.key}')
            ? ''
            : entry.value,
    },
    headers: {
      for (final entry in draft.headers.entries)
        entry.key: draft.secretKeys.contains('header.${entry.key}')
            ? ''
            : entry.value,
    },
  );

  Map<String, String> _extract(
    McpServerDraft draft,
    Map<String, String> old,
    Map<String, SecretValueState> states,
  ) {
    final local = <String, String>{};
    for (final key in draft.secretKeys) {
      final value = key.startsWith('env.')
          ? draft.env[key.substring(4)]!
          : draft.headers[key.substring(7)]!;
      if (value.isNotEmpty) {
        local[key] = value;
      } else if (states[key] == SecretValueState.missingOnDevice &&
          old[key] != null) {
        local[key] = old[key]!;
      }
    }
    return local;
  }

  McpServer _merge(McpServer server, Map<String, String> local) =>
      server.copyWith(
        draft: server.draft.copyWith(
          env: {
            for (final entry in server.draft.env.entries)
              entry.key: server.draft.secretKeys.contains('env.${entry.key}')
                  ? local['env.${entry.key}'] ?? ''
                  : entry.value,
          },
          headers: {
            for (final entry in server.draft.headers.entries)
              entry.key: server.draft.secretKeys.contains('header.${entry.key}')
                  ? local['header.${entry.key}'] ?? ''
                  : entry.value,
          },
        ),
        secretStates: {
          for (final key in server.draft.secretKeys)
            key: local[key]?.isNotEmpty == true
                ? SecretValueState.present
                : SecretValueState.missingOnDevice,
        },
      );
}
