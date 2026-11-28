import 'dart:io';

import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_target_settings.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_launch_trust.dart';
import '../models/mcp_server.dart';
import 'mcp_connection_repository.dart';
import 'mcp_proxy.dart';
import 'mcp_stdio_launcher.dart';
import 'mcp_target_repository.dart';

class McpTargetRepositoryImpl implements McpTargetRepository {
  McpTargetRepositoryImpl(
    this._launcher, {
    required this.isAuthorized,
    Map<String, String>? environment,
  }) : _environment = Map.unmodifiable(environment ?? Platform.environment);
  final McpStdioLauncher _launcher;
  final bool Function(McpAccessContext, String serverId) isAuthorized;
  final Map<String, String> _environment;
  static const _accessFailure = McpAuthFailure(
    'The account or workspace changed. Resolve the server again.',
  );

  @override
  Future<Result<McpConnectTarget>> resolve(
    McpAccessContext context,
    McpServer server,
    McpTargetSettings settings,
  ) async {
    bool active() =>
        server.workspaceId == context.workspaceId &&
        isAuthorized(context, server.id);
    if (!active()) return const Result.failure(_accessFailure);
    final draft = server.draft;
    final seconds = draft.settings.timeoutSeconds;
    final timeout = seconds == null
        ? settings.timeout
        : Duration(seconds: seconds);
    if (timeout <= Duration.zero) {
      return const Result.failure(
        McpValidationFailure(
          'Timeout must be greater than zero.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    if (draft.transport == McpTransport.stdio) {
      if (draft.command == null || draft.command!.trim().isEmpty) {
        return const Result.failure(
          McpValidationFailure(
            'Provide a server command.',
            code: McpErrorCode.invalidParams,
          ),
        );
      }
      final launch = await _launcher.resolve(
        command: draft.command!,
        args: draft.args,
        cwd: draft.cwd,
        environment: draft.env,
        inheritedEnvironment: _environment,
      );
      if (!active()) return const Result.failure(_accessFailure);
      if (launch case Err(:final failure)) return Result.failure(failure);
      return Result.success(
        McpConnectTarget(
          context: context,
          server: server,
          timeout: timeout,
          launch: launch.valueOrNull!,
        ),
      );
    }
    final uri = Uri.tryParse(draft.url ?? '');
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        RegExp(
          r'^https?://[^/?#]*@',
          caseSensitive: false,
        ).hasMatch(draft.url ?? '')) {
      return const Result.failure(
        McpValidationFailure(
          'Use an HTTP(S) server URL without embedded credentials.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final proxy = resolveMcpProxy(uri, settings.proxyUrl, _environment);
    if (proxy case Err(:final failure)) return Result.failure(failure);
    return Result.success(
      McpConnectTarget(
        context: context,
        server: server,
        timeout: timeout,
        proxy: proxy.valueOrNull,
      ),
    );
  }
}
