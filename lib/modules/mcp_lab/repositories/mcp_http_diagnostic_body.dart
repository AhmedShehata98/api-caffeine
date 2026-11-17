import 'dart:convert';
import 'dart:typed_data';

/// Bounded request or response data-frame capture. Input must be sanitized.
/// Full bodies are retained here; the monitor applies its own 256 KiB preview.
class McpHttpDiagnosticBody {
  McpHttpDiagnosticBody({this.limitBytes = 16 * 1024 * 1024}) {
    if (limitBytes <= 0) throw ArgumentError('Body limit must be positive.');
  }
  final int limitBytes;
  final _bytes = BytesBuilder(copy: false);
  bool truncated = false;
  void add(String sanitized) {
    if (truncated) return;
    final remaining = limitBytes - _bytes.length;
    if (remaining == 0) {
      truncated = true;
      return;
    }
    final bytes = utf8.encode('$sanitized\n');
    if (bytes.length <= remaining) {
      _bytes.add(bytes);
      return;
    }
    truncated = true;
    var end = remaining;
    while (end > 0 && bytes[end] & 0xc0 == 0x80) {
      end--;
    }
    _bytes.add(bytes.sublist(0, end));
  }

  String get text => utf8.decode(_bytes.toBytes());
  void clear() {
    _bytes.clear();
    truncated = false;
  }
}
