import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import '../repositories/mcp_connection_repository.dart';
import '../repositories/mcp_trust_repository.dart';
import 'mcp_negotiation_service.dart';

sealed class McpConnectOutcome {}

/// Memory-only approval ticket for the exact resolved target shown in the UI.
/// Never serialize or log: the target can contain device credentials.
class McpNeedsApproval extends McpConnectOutcome {
  McpNeedsApproval._(
    this._owner,
    this.target,
    this.changedFields,
    this.storageFailure,
  );
  final McpConnectService _owner;
  final McpConnectTarget target;
  final List<String> changedFields;
  final Failure? storageFailure;
  bool _consumed = false;
}

class McpConnected extends McpConnectOutcome {
  McpConnected(this.session, this.negotiation, {this.rememberFailure});
  final McpSession session;
  final McpNegotiation negotiation;

  /// Explicit approval permits this launch even if remembered trust cannot save.
  final Failure? rememberFailure;
}

/// Coordinates trust and negotiation for a fully resolved, hydrated target.
/// The caller resolves executable/proxy/settings before calling this service.
class McpConnectService {
  McpConnectService(
    this._connections,
    this._trust,
    this._negotiation, {
    required this.isAuthorized,
    this.onSessionOpened,
  });
  final McpConnectionRepository _connections;
  final McpTrustRepository _trust;
  final McpNegotiationService _negotiation;
  final bool Function(McpAccessContext, String serverId) isAuthorized;
  final void Function(McpAccessContext, String, McpSession)? onSessionOpened;

  static const _accessFailure = McpAuthFailure(
    'The account or workspace changed. Reconnect from the current workspace.',
  );

  Failure? _validate(McpConnectTarget target) {
    if (target.context.workspaceId != target.server.workspaceId ||
        !isAuthorized(target.context, target.server.id)) {
      return _accessFailure;
    }
    for (final key in target.server.draft.secretKeys) {
      final draft = target.server.draft;
      final value = key.startsWith('env.')
          ? (target.launch?.environment ?? draft.env)[key.substring(4)]
          : key.startsWith('header.')
          ? draft.headers[key.substring(7)]
          : null;
      if (target.server.secretStates[key] != SecretValueState.present ||
          value == null ||
          value.isEmpty) {
        return McpValidationFailure(
          'Set the missing device secret "$key" before connecting.',
          code: McpErrorCode.invalidParams,
        );
      }
    }
    return null;
  }

  Future<Result<McpConnectOutcome>> connect(McpConnectTarget target) async {
    final invalid = _validate(target);
    if (invalid != null) return Result.failure(invalid);
    if (target.launch != null) {
      final trust = await _trust.check(
        target.context,
        target.server.id,
        target.launch!,
      );
      final stale = _validate(target);
      if (stale != null) return Result.failure(stale);
      if (trust case Err(:final failure)) {
        if (failure is! StorageFailure) return Result.failure(failure);
        return Result.success(
          McpNeedsApproval._(this, target, const [], failure),
        );
      }
      final check = trust.valueOrNull!;
      if (!check.approved) {
        return Result.success(
          McpNeedsApproval._(
            this,
            target,
            List.unmodifiable(check.changedFields),
            null,
          ),
        );
      }
    }
    return _open(target);
  }

  /// Call only after the user explicitly approves this ticket. No re-resolution
  /// occurs between the displayed snapshot and the launched snapshot.
  Future<Result<McpConnectOutcome>> approve(
    McpNeedsApproval ticket, {
    bool remember = false,
  }) async {
    if (!identical(ticket._owner, this) || ticket._consumed) {
      return const Result.failure(
        McpValidationFailure(
          'Request a fresh launch approval.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    ticket._consumed = true;
    final target = ticket.target;
    final invalid = _validate(target);
    if (invalid != null) return Result.failure(invalid);
    Failure? rememberFailure;
    if (remember) {
      final saved = await _trust.approve(
        target.context,
        target.server.id,
        target.launch!,
      );
      final stale = _validate(target);
      if (stale != null) return Result.failure(stale);
      if (saved case Err(:final failure)) {
        if (failure is! StorageFailure) return Result.failure(failure);
        rememberFailure = failure;
      }
    }
    return _open(target, rememberFailure: rememberFailure);
  }

  Future<Result<McpConnectOutcome>> _open(
    McpConnectTarget target, {
    Failure? rememberFailure,
  }) async {
    final invalid = _validate(target);
    if (invalid != null) return Result.failure(invalid);
    final connected = await _connections.connect(target);
    if (connected case Err(:final failure)) return Result.failure(failure);
    final session = connected.valueOrNull!;
    if (_validate(target) case final Failure failure) {
      final closed = await session.close();
      return Result.failure(closed.failureOrNull ?? failure);
    }
    onSessionOpened?.call(target.context, target.server.id, session);
    final negotiated = await _negotiation.negotiate(
      session,
      era: target.server.draft.settings.protocolEra,
    );
    if (negotiated case Err(:final failure)) return Result.failure(failure);
    if (_validate(target) case final Failure failure) {
      final closed = await session.close();
      return Result.failure(closed.failureOrNull ?? failure);
    }
    return Result.success(
      McpConnected(
        session,
        negotiated.valueOrNull!,
        rememberFailure: rememberFailure,
      ),
    );
  }
}
