import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/utils/names.dart';

import '../models/mcp_failure.dart';
import '../models/mcp_server.dart';

Result<McpServerDraft> validateMcpServerDraft(
  McpServerDraft draft, {
  Set<String> confirmedPlaintextHeaders = const {},
}) {
  Result<McpServerDraft> invalid(String message) => Result.failure(
    McpValidationFailure(message, code: McpErrorCode.invalidParams),
  );
  final name = validateName(draft.name, label: 'Server name');
  if (name.failure != null) return invalid(name.failure!.message);
  String? optional(String? value) =>
      value == null || value.trim().isEmpty ? null : value.trim();
  final command = optional(draft.command);
  final url = optional(draft.url);
  if ((command == null) == (url == null)) {
    return invalid('Provide either a command or a server URL.');
  }
  if (url != null) {
    final uri = Uri.tryParse(url);
    if (uri == null ||
        !const {'http', 'https'}.contains(uri.scheme) ||
        uri.host.isEmpty ||
        uri.authority.contains('@') ||
        RegExp(r'^https?://[^/?#]*@', caseSensitive: false).hasMatch(url)) {
      return invalid('Use an HTTP(S) server URL without embedded credentials.');
    }
  }
  if (draft.settings.timeoutSeconds case final seconds? when seconds <= 0) {
    return invalid('Timeout must be greater than zero.');
  }
  final headers = <String, String>{};
  for (final entry in draft.headers.entries) {
    final key = entry.key.trim().toLowerCase();
    if (key.isEmpty || !RegExp(r"^[!#$%&'*+.^_`|~0-9a-z-]+$").hasMatch(key)) {
      return invalid('Every header needs a valid name.');
    }
    if (headers.containsKey(key)) {
      return invalid('Header names must be unique (case-insensitive).');
    }
    if (entry.value.contains('\r') || entry.value.contains('\n')) {
      return invalid('Header values must stay on one line.');
    }
    headers[key] = entry.value;
  }
  for (final key in draft.env.keys) {
    if (key.isEmpty || RegExp(r'[\s=\x00]').hasMatch(key)) {
      return invalid(
        'Environment keys must not be blank or contain whitespace or equals signs.',
      );
    }
  }
  final secretKeys = <String>{};
  for (final key in draft.secretKeys) {
    if (key.startsWith('env.') && draft.env.containsKey(key.substring(4))) {
      secretKeys.add(key);
    } else if (key.startsWith('header.') &&
        headers.containsKey(key.substring(7).trim().toLowerCase())) {
      secretKeys.add('header.${key.substring(7).trim().toLowerCase()}');
    } else {
      return invalid(
        'Secret keys must refer to an existing environment variable or header.',
      );
    }
  }
  final overrides = confirmedPlaintextHeaders
      .map((key) => key.trim().toLowerCase())
      .toSet();
  for (final key in headers.keys) {
    if (isMcpCredentialHeader(key) && !overrides.contains(key)) {
      secretKeys.add('header.$key');
    }
  }
  return Result.success(
    draft.copyWith(
      name: name.name!,
      command: command,
      url: url,
      cwd: optional(draft.cwd),
      headers: headers,
      secretKeys: secretKeys.toList()..sort(),
      transport: command != null
          ? McpTransport.stdio
          : draft.transport == McpTransport.sse
          ? McpTransport.sse
          : McpTransport.http,
    ),
  );
}
