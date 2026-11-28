import 'package:mcp_dart/mcp_dart.dart'
    show
        latestInitializationProtocolVersion,
        legacyProtocolVersions,
        stableProtocolVersion;
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_diagnostics.dart';
import '../models/mcp_failure.dart';
import '../models/mcp_server.dart';
import '../repositories/mcp_connection_repository.dart';

/// Handshake information for connection info and subsequent capability checks.
/// This is an operation result, never a diagnostic cache.
class McpNegotiation {
  McpNegotiation({
    required this.era,
    required this.version,
    required Map<String, dynamic> discovery,
  }) : discovery = Map.unmodifiable(discovery);

  final NegotiatedEra era;
  final String version;
  final Map<String, dynamic> discovery;
}

/// Negotiates an already authorized transport. Launch approval and target
/// resolution belong to the connect service; this service cannot launch a process.
class McpNegotiationService {
  const McpNegotiationService({required this.clientVersion});
  final String clientVersion;

  /// The caller owns the session on success. Failure always awaits close.
  /// A cleanup failure is returned in preference to the handshake failure so
  /// that failed process/session cleanup is never silently discarded.
  Future<Result<McpNegotiation>> negotiate(
    McpSession session, {
    McpProtocolEra era = McpProtocolEra.legacy,
  }) async {
    final result = await _negotiate(session, era);
    if (result is Err<McpNegotiation>) {
      final cleanup = await session.close();
      if (cleanup case Err(:final failure)) return Result.failure(failure);
    }
    return result;
  }

  Future<Result<McpNegotiation>> _negotiate(
    McpSession session,
    McpProtocolEra era,
  ) async {
    if (era != McpProtocolEra.legacy) {
      final discovery = await session.request('server/discover', const {});
      if (discovery case Success(:final value)) {
        final versions = value['supportedVersions'];
        if (versions is List &&
            versions.every((item) => item is String) &&
            versions.contains(stableProtocolVersion)) {
          return _finish(
            session,
            NegotiatedEra.modern,
            stableProtocolVersion,
            value,
          );
        }
        if (era == McpProtocolEra.modern) return _unsupported();
      } else if (era == McpProtocolEra.modern) {
        return Result.failure(discovery.failureOrNull!);
      }
      // Explicit auto mode only. Both attempts pass through the same transport
      // diagnostics; no ordinary operation is retried or replayed here.
    }

    final initialized = await session.request('initialize', {
      'protocolVersion': latestInitializationProtocolVersion,
      'capabilities': <String, dynamic>{},
      'clientInfo': {'name': 'API Caffeine', 'version': clientVersion},
    });
    if (initialized case Err(:final failure)) return Result.failure(failure);
    final value = initialized.valueOrNull!;
    final version = value['protocolVersion'];
    if (version is! String || !legacyProtocolVersions.contains(version)) {
      return _unsupported();
    }
    return _finish(session, NegotiatedEra.legacy, version, value);
  }

  Future<Result<McpNegotiation>> _finish(
    McpSession session,
    NegotiatedEra era,
    String version,
    Map<String, dynamic> value,
  ) async {
    final info = value['serverInfo'];
    if (value['capabilities'] is! Map<String, dynamic> ||
        info is! Map<String, dynamic> ||
        info['name'] is! String ||
        info['version'] is! String ||
        (value['instructions'] != null && value['instructions'] is! String)) {
      return const Result.failure(
        McpValidationFailure(
          'The MCP server returned an invalid handshake.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final configured = session.configureProtocol(era: era, version: version);
    if (configured case Err(:final failure)) return Result.failure(failure);
    if (era == NegotiatedEra.legacy) {
      final ready = await session.notify('notifications/initialized', const {});
      if (ready case Err(:final failure)) return Result.failure(failure);
    }
    return Result.success(
      McpNegotiation(era: era, version: version, discovery: value),
    );
  }

  Result<McpNegotiation> _unsupported() => Result.failure(
    McpNetworkFailure(
      'The server does not support a compatible MCP protocol version.',
      code: McpErrorCode.protocolVersionUnsupported,
    ),
  );
}
