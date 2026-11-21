import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_target_settings.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import '../repositories/mcp_connection_repository.dart';
import '../repositories/mcp_target_repository.dart';
import 'mcp_catalog_service.dart';
import 'mcp_server_validator.dart';

/// Reloads a saved server and hydrates device secrets before resolving its target.
class McpTargetService {
  const McpTargetService(
    this._catalog,
    this._targets, {
    required this.isAuthorized,
  });
  final McpCatalogService _catalog;
  final McpTargetRepository _targets;
  final bool Function(McpAccessContext, String serverId) isAuthorized;
  static const _accessFailure = McpAuthFailure(
    'The account or workspace changed. Resolve the server again.',
  );

  Future<Result<McpConnectTarget>> resolve(
    McpAccessContext context,
    String serverId,
    McpTargetSettings settings,
  ) async {
    if (!isAuthorized(context, serverId)) {
      return const Result.failure(_accessFailure);
    }
    final loaded = await _catalog.get(context, serverId);
    if (!isAuthorized(context, serverId)) {
      return const Result.failure(_accessFailure);
    }
    if (loaded case Err(:final failure)) return Result.failure(failure);
    final server = loaded.valueOrNull!;
    final draft = server.draft;
    // A saved plaintext override was already confirmed at catalog save time.
    final valid = validateMcpServerDraft(
      draft,
      confirmedPlaintextHeaders: {
        for (final key in draft.headers.keys)
          if (!draft.secretKeys.contains('header.$key')) key,
      },
    );
    if (valid case Err(:final failure)) return Result.failure(failure);
    if (valid.valueOrNull!.transport != draft.transport) {
      return const Result.failure(
        McpValidationFailure(
          'The saved transport does not match its target.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final clean = server.copyWith(draft: valid.valueOrNull!);
    for (final key in clean.draft.secretKeys) {
      final value = key.startsWith('env.')
          ? clean.draft.env[key.substring(4)]
          : clean.draft.headers[key.substring(7)];
      if (clean.secretStates[key] != SecretValueState.present ||
          value == null ||
          value.isEmpty) {
        return Result.failure(
          McpValidationFailure(
            'Set the missing device secret "$key" before connecting.',
            code: McpErrorCode.invalidParams,
          ),
        );
      }
    }
    final target = await _targets.resolve(context, clean, settings);
    if (!isAuthorized(context, serverId)) {
      return const Result.failure(_accessFailure);
    }
    return target;
  }
}
