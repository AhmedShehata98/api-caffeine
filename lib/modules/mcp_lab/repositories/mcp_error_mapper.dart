import 'dart:async';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:api_caffeine/core/error/failure.dart';

import '../models/mcp_failure.dart';
import 'mcp_diagnostic_sanitizer.dart';

/// Server/exception text is never copied into an unsanitized application error.
class McpErrorMapper {
  McpErrorMapper(this._sanitizer);
  final McpDiagnosticSanitizer _sanitizer;

  Failure rpc(
    int code,
    String message, {
    Map<String, dynamic>? data,
    String? method,
  }) {
    if ((code == -32602 || code == -32002) && method == 'resources/read') {
      return const McpValidationFailure(
        'Resource not found.',
        code: McpErrorCode.invalidParams,
      );
    }
    if (code == -32602 || code == -32002) {
      final unknownTool = RegExp(
        r'unknown tool|tool.*not found|no (?:such )?tool',
        caseSensitive: false,
      ).hasMatch(message);
      return McpValidationFailure(
        unknownTool ? 'Unknown tool.' : 'Invalid parameters.',
        code: unknownTool
            ? McpErrorCode.toolNotFound
            : McpErrorCode.invalidParams,
      );
    }
    final versionValues = data?['supported'];
    final versions = versionValues is List
        ? versionValues.whereType<String>().map(_sanitizer.text).toList()
        : null;
    return switch (code) {
      -32020 => McpNetworkFailure(
        'MCP request headers do not match the request.',
        code: McpErrorCode.headerMismatch,
      ),
      -32021 => McpNetworkFailure(
        'The server requires an unsupported client capability.',
        code: McpErrorCode.missingCapability,
      ),
      -32022 => McpNetworkFailure(
        'The server does not support this protocol version.',
        code: McpErrorCode.protocolVersionUnsupported,
        supportedVersions: versions,
      ),
      _ => const UnexpectedFailure('The MCP server rejected the request.'),
    };
  }

  Failure http(int status, {String? retryAfter, DateTime? now}) {
    if (status == 401 || status == 403) {
      return const McpAuthFailure('Sign in to this MCP server to continue.');
    }
    if (status == 429) {
      Duration? retry;
      final seconds = int.tryParse(retryAfter?.trim() ?? '');
      if (seconds != null && seconds >= 0) {
        retry = Duration(seconds: seconds);
      } else if (retryAfter != null) {
        try {
          final delay = HttpDate.parse(retryAfter)
              .difference(now ?? DateTime.now().toUtc());
          retry = delay.isNegative ? Duration.zero : delay;
        } on HttpException {
          /* An invalid optional Retry-After carries no delay. */
        }
      }
      return McpNetworkFailure(
        'The MCP server is rate limiting requests.',
        code: McpErrorCode.rateLimited,
        retryAfter: retry,
      );
    }
    return McpNetworkFailure(
      status == 404
          ? 'MCP session expired. Reconnect to continue.'
          : 'MCP HTTP request failed ($status).',
      code: McpErrorCode.unreachable,
    );
  }

  /// Null means malformed wire data: emit a sanitized warning, not a disconnect.
  Failure? exception(Object error) => switch (error) {
    FormatException() => null,
    DioException() ||
    SocketException() ||
    ProcessException() ||
    TimeoutException() ||
    HttpException() => McpNetworkFailure(
      'Cannot reach the MCP server.',
      code: McpErrorCode.unreachable,
    ),
    _ => const UnexpectedFailure('The MCP operation could not be completed.'),
  };

  McpUnexpectedFailure processExited(int exitCode, String stderr) {
    final sanitized = _sanitizer.text(stderr);
    return McpUnexpectedFailure(
      'MCP server process exited ($exitCode).',
      exitCode: exitCode,
      stderrTail: sanitized.length > 8192
          ? sanitized.substring(sanitized.length - 8192)
          : sanitized,
    );
  }
}
