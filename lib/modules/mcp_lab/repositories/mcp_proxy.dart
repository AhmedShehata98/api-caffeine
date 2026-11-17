import 'dart:io';

import 'package:test_point/core/error/result.dart';

import '../models/mcp_failure.dart';

/// Null is direct. Explicit Settings proxy wins; NO_PROXY applies in both modes.
Result<Uri?> resolveMcpProxy(
  Uri target,
  String? settingsProxyUrl,
  Map<String, String> environment,
) {
  String? variable(String name) {
    final lower = environment[name.toLowerCase()]?.trim();
    return lower != null && lower.isNotEmpty
        ? lower
        : environment[name]?.trim();
  }

  final host = target.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  if (host == 'localhost' ||
      InternetAddress.tryParse(host)?.isLoopback == true) {
    return const Result.success(null);
  }
  for (final entry in (variable('NO_PROXY') ?? '').split(',')) {
    if (_bypasses(target, entry.trim())) return const Result.success(null);
  }
  final configured = settingsProxyUrl?.trim();
  final raw = configured != null && configured.isNotEmpty
      ? configured
      : variable(target.scheme == 'https' ? 'HTTPS_PROXY' : 'HTTP_PROXY');
  if (raw == null || raw.isEmpty) return const Result.success(null);
  final proxy = Uri.tryParse(raw);
  if (proxy == null ||
      !const {'http', 'https'}.contains(proxy.scheme) ||
      proxy.host.isEmpty) {
    return const Result.failure(
      McpValidationFailure(
        'Configure an HTTP(S) proxy URL with a host.',
        code: McpErrorCode.invalidParams,
      ),
    );
  }
  return Result.success(proxy);
}

bool _bypasses(Uri target, String entry) {
  if (entry.isEmpty) return false;
  if (entry == '*') return true;
  final literal = InternetAddress.tryParse(entry);
  if (literal != null && literal == InternetAddress.tryParse(target.host)) {
    return true;
  }
  if (entry.contains('/')) {
    final parts = entry.split('/');
    if (parts.length != 2) return false;
    final network = InternetAddress.tryParse(parts[0]);
    final address = InternetAddress.tryParse(target.host);
    final bits = int.tryParse(parts[1]);
    if (network == null ||
        address == null ||
        bits == null ||
        network.type != address.type ||
        bits < 0 ||
        bits > network.rawAddress.length * 8) {
      return false;
    }
    for (var i = 0; i < network.rawAddress.length; i++) {
      final remaining = (bits - i * 8).clamp(0, 8);
      final mask = (255 << (8 - remaining)) & 255;
      if ((network.rawAddress[i] & mask) != (address.rawAddress[i] & mask)) {
        return false;
      }
    }
    return true;
  }
  final parsed = Uri.tryParse('http://$entry');
  if (parsed == null || parsed.host.isEmpty) return false;
  if (parsed.hasPort && parsed.port != target.port) return false;
  final domain = parsed.host
      .toLowerCase()
      .replaceFirst(RegExp(r'^\*?\.'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  final host = target.host.toLowerCase().replaceFirst(RegExp(r'\.$'), '');
  return host == domain || host.endsWith('.$domain');
}
