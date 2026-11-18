import 'package:test_point/core/error/failure.dart';

enum McpErrorCode {
  unreachable('unreachable'),
  authRequired('auth_required'),
  rateLimited('rate_limited'),
  protocolVersionUnsupported('protocol_version_unsupported'),
  headerMismatch('header_mismatch'),
  missingCapability('missing_capability'),
  toolNotFound('tool_not_found'),
  invalidParams('invalid_params'),
  schemaUnportable('schema_unportable'),
  storeUnavailable('store_unavailable'),
  processExited('process_exited');

  const McpErrorCode(this.wireValue);
  final String wireValue;
}

abstract interface class McpCoded {
  McpErrorCode get code;
  Duration? get retryAfter;
  List<String>? get supportedVersions;
  int? get exitCode;
  String? get stderrTail;
}

mixin _McpDetails implements McpCoded {
  @override
  Duration? get retryAfter => null;
  @override
  List<String>? get supportedVersions => null;
  @override
  int? get exitCode => null;
  @override
  String? get stderrTail => null;
}

class McpNetworkFailure extends NetworkFailure with _McpDetails {
  McpNetworkFailure(
    super.message, {
    required this.code,
    this.retryAfter,
    List<String>? supportedVersions,
  }) : supportedVersions = supportedVersions == null
           ? null
           : List.unmodifiable(supportedVersions);
  @override
  final McpErrorCode code;
  @override
  final Duration? retryAfter;
  @override
  final List<String>? supportedVersions;
}

class McpAuthFailure extends AuthFailure with _McpDetails {
  const McpAuthFailure(super.message);
  @override
  McpErrorCode get code => McpErrorCode.authRequired;
}

class McpValidationFailure extends ValidationFailure with _McpDetails {
  const McpValidationFailure(super.message, {required this.code});
  @override
  final McpErrorCode code;
}

class McpStorageFailure extends StorageFailure with _McpDetails {
  const McpStorageFailure(super.message);
  @override
  McpErrorCode get code => McpErrorCode.storeUnavailable;
}

class McpUnexpectedFailure extends UnexpectedFailure with _McpDetails {
  const McpUnexpectedFailure(super.message, {this.exitCode, this.stderrTail});
  @override
  McpErrorCode get code => McpErrorCode.processExited;
  @override
  final int? exitCode;

  /// Sanitized by the diagnostic boundary before constructing this failure.
  @override
  final String? stderrTail;
}
