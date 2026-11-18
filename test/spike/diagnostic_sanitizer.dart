import 'dart:convert';

/// Spike-only policy. Production diagnostics must share one module boundary.
class DiagnosticSanitizer {
  DiagnosticSanitizer(Iterable<String> secrets)
    : _values = {
        for (final value in secrets.where((value) => value.isNotEmpty)) ...[
          value,
          Uri.encodeComponent(value),
          Uri.encodeQueryComponent(value),
        ],
      }.toList()..sort((a, b) => b.length.compareTo(a.length));

  final List<String> _values;
  static final _credential = RegExp(
    r'^(authorization|proxy-authorization|cookie|set-cookie|x-api-key|api-key)$',
    caseSensitive: false,
  );
  static final _query = RegExp(
    r'([?&](?:token|access_token|refresh_token|api_key|key|secret|password|code)=)[^&#\s"<>]*',
    caseSensitive: false,
  );

  String text(String value) {
    var clean = value;
    for (final secret in _values) {
      clean = clean.replaceAll(secret, '[REDACTED]');
    }
    return clean.replaceAllMapped(_query, (match) => '${match[1]}[REDACTED]');
  }

  Object? json(Object? value) => switch (value) {
    Map() => {
      for (final entry in value.entries)
        text(entry.key.toString()): _credential.hasMatch(entry.key.toString())
            ? '[REDACTED]'
            : json(entry.value),
    },
    List() => value.map(json).toList(),
    String() => text(value),
    _ => value,
  };

  /// Preserve exact unmodified wire text; label changed frames at the consumer.
  String frame(String wire) {
    try {
      final decoded = jsonDecode(wire);
      final clean = json(decoded);
      return jsonEncode(clean) == jsonEncode(decoded)
          ? wire
          : jsonEncode(clean);
    } on FormatException {
      return text(wire);
    }
  }
}
