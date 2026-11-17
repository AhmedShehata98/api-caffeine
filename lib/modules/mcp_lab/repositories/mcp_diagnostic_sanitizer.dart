import 'dart:convert';

import '../models/mcp_server.dart' show isMcpCredentialHeader;

/// One session-owned boundary for diagnostic copies, before buffers or logs.
/// Operation results never pass through this object.
class McpDiagnosticSanitizer {
  McpDiagnosticSanitizer({
    Iterable<String> secretValues = const [],
    Map<String, List<String>> headers = const {},
  }) {
    addSecrets(secretValues);
    _rememberHeaders(headers);
  }
  final _values = <String>{};
  RegExp? _pattern;
  bool _disposed = false;
  static const _marker = '[REDACTED]';
  static const _queryKeys = {
    'token',
    'access_token',
    'refresh_token',
    'api_key',
    'key',
    'secret',
    'password',
    'code',
  };
  static final _query = RegExp(r'''([?&])([^=&\s"'<>#]+)=([^&#\s"'<>]*)''');
  static final _headerLine = RegExp(
    // Match fixed credential suffixes instead of backtracking over an entire
    // arbitrary token (a multi-megabyte base64 value can itself be one token).
    r'((?:\b(?:authorization|proxy-authorization|cookie|set-cookie|x-api-key)|-(?:token|key|secret))\s*:\s*)[^\r\n]*',
    caseSensitive: false,
  );

  void _ensureActive() {
    if (_disposed) throw StateError('Diagnostic sanitizer has been disposed.');
  }

  static final _jsonHeader = RegExp(
    r'((?:"(?:authorization|proxy-authorization|cookie|set-cookie|x-api-key)|-(?:token|key|secret))"\s*:\s*)',
    caseSensitive: false,
  );

  bool _credential(String key) =>
      isMcpCredentialHeader(key) || key.toLowerCase() == 'set-cookie';

  void addSecrets(Iterable<String> values) {
    _ensureActive();
    final expanded = <String>{};
    for (final value in values.where((value) => value.isNotEmpty)) {
      expanded.add(value);
      expanded.addAll(
        value.split(RegExp(r'\r\n|\n|\r')).where((part) => part.isNotEmpty),
      );
    }
    for (final value in expanded) {
      for (final variant in [
        value,
        Uri.encodeComponent(value),
        Uri.encodeQueryComponent(value),
        '=?base64?${base64Encode(utf8.encode(value))}?=',
        jsonEncode(value).substring(1, jsonEncode(value).length - 1),
      ]) {
        _values.add(variant);
      }
    }
    final sorted = _values.toList()
      ..sort((a, b) => b.length.compareTo(a.length));
    _pattern = sorted.isEmpty
        ? null
        : RegExp(sorted.map(_escapeSecretPattern).join('|'));
  }

  static String _escapeSecretPattern(String value) {
    final pattern = StringBuffer();
    var offset = 0;
    for (final match in RegExp(r'%[0-9a-fA-F]{2}').allMatches(value)) {
      pattern.write(RegExp.escape(value.substring(offset, match.start)));
      pattern.write('%');
      for (final character in match[0]!.substring(1).split('')) {
        pattern.write(
          character.toLowerCase() == character.toUpperCase()
              ? character
              : '[${character.toLowerCase()}${character.toUpperCase()}]',
        );
      }
      offset = match.end;
    }
    pattern.write(RegExp.escape(value.substring(offset)));
    return pattern.toString();
  }

  void _rememberHeaders(Map<String, List<String>> headers) {
    final values = <String>[];
    for (final entry in headers.entries.where(
      (entry) => _credential(entry.key),
    )) {
      for (final value in entry.value) {
        values.add(value);
        final token = RegExp(
          r'^\s*(?:Bearer|Basic)\s+(\S+)\s*$',
          caseSensitive: false,
        ).firstMatch(value);
        if (token != null) values.add(token[1]!);
        final name = entry.key.toLowerCase();
        if (name == 'cookie' || name == 'set-cookie') {
          final parts = value.split(';');
          for (final part in name == 'set-cookie' ? parts.take(1) : parts) {
            final separator = part.indexOf('=');
            if (separator >= 0) {
              values.add(part.substring(separator + 1).trim());
            }
          }
        }
      }
    }
    addSecrets(values);
  }

  String text(String value) {
    _ensureActive();
    var clean = value;
    clean = clean.replaceAllMapped(_query, (match) {
      String key;
      try {
        key = Uri.decodeQueryComponent(match[2]!).toLowerCase();
      } on FormatException {
        return match[0]!;
      }
      return _queryKeys.contains(key)
          ? '${match[1]}${match[2]}=$_marker'
          : match[0]!;
    });
    clean = _redactJsonHeaders(clean);
    clean = clean.replaceAllMapped(
      _headerLine,
      (match) => '${match[1]}$_marker',
    );
    return _pattern == null
        ? clean
        : clean
              .split(_marker)
              .map((part) => part.replaceAll(_pattern!, _marker))
              .join(_marker);
  }

  String _redactJsonHeaders(String value) {
    final output = StringBuffer();
    var cursor = 0;
    for (final match in _jsonHeader.allMatches(value)) {
      if (match.start < cursor) continue;
      var end = match.end;
      if (end < value.length && value.codeUnitAt(end) == 34) {
        // Scan quoted values without a recursive alternation per character.
        // This also safely consumes a missing closing quote to EOF.
        end++;
        while (end < value.length) {
          final unit = value.codeUnitAt(end++);
          if (unit == 92 && end < value.length) {
            end++;
          } else if (unit == 34) {
            break;
          }
        }
      } else {
        while (end < value.length &&
            value.codeUnitAt(end) != 10 &&
            value.codeUnitAt(end) != 13) {
          end++;
        }
      }
      output.write(value.substring(cursor, match.end));
      output.write('"$_marker"');
      cursor = end;
    }
    if (cursor == 0) return value;
    output.write(value.substring(cursor));
    return output.toString();
  }

  void _rememberJsonHeaders(Object? value) {
    if (value is Map) {
      for (final entry in value.entries) {
        if (_credential(entry.key.toString())) {
          final values = entry.value is List
              ? entry.value as List
              : [entry.value];
          _rememberHeaders({
            entry.key.toString(): values.whereType<String>().toList(),
          });
        } else {
          _rememberJsonHeaders(entry.value);
        }
      }
    } else if (value is List) {
      for (final child in value) {
        _rememberJsonHeaders(child);
      }
    }
  }

  Object? _cleanJson(Object? value) => switch (value) {
    Map() => {
      for (final entry in value.entries)
        text(entry.key.toString()): _credential(entry.key.toString())
            ? _marker
            : _cleanJson(entry.value),
    },
    List() => value.map(_cleanJson).toList(),
    String() => text(value),
    _ => value,
  };

  Object? json(Object? value) {
    _ensureActive();
    _rememberJsonHeaders(value);
    return _cleanJson(value);
  }

  ({String text, bool redacted}) frame(String wire) {
    _ensureActive();
    String sanitized;
    try {
      final original = jsonDecode(wire);
      final clean = json(original);
      sanitized = jsonEncode(original) == jsonEncode(clean)
          ? wire
          : jsonEncode(clean);
    } on FormatException {
      sanitized = text(wire);
    }
    return (text: sanitized, redacted: sanitized != wire);
  }

  Map<String, List<String>> headers(Map<String, List<String>> values) {
    _ensureActive();
    _rememberHeaders(values);
    // Learn credentials from decoded headers before sanitizing any header, so
    // an earlier echo cannot reveal a value declared by a later sentinel.
    for (final entry in values.entries) {
      for (final value in entry.value) {
        if (!value.startsWith('=?base64?') || !value.endsWith('?=')) continue;
        try {
          final decoded = utf8.decode(
            base64Decode(value.substring(9, value.length - 2)),
          );
          _rememberHeaders({
            entry.key: [decoded],
          });
          try {
            _rememberJsonHeaders(jsonDecode(decoded));
          } on FormatException {
            continue; // Plain string sentinels are valid too.
          }
        } on FormatException {
          continue; // Malformed sentinels retain the normal text sanitizer.
        }
      }
    }
    return Map.unmodifiable({
      for (final entry in values.entries)
        text(entry.key): List<String>.unmodifiable(
          _credential(entry.key) ? [_marker] : entry.value.map(_headerValue),
        ),
    });
  }

  String _headerValue(String value) {
    if (value.startsWith('=?base64?') && value.endsWith('?=')) {
      try {
        final decoded = utf8.decode(
          base64Decode(value.substring(9, value.length - 2)),
        );
        // Sanitize the decoded representation before it can be displayed.
        final clean = frame(decoded).text;
        return '=?base64?${base64Encode(utf8.encode(clean))}?=';
      } on FormatException {
        return text(value);
      }
    }
    return text(value);
  }

  void dispose() {
    _values.clear();
    _pattern = null;
    _disposed = true;
  }
}
