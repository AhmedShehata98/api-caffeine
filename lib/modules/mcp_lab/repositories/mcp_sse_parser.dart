import 'dart:convert';

/// Decode complete SSE data events; an EOF never dispatches a partial event.
Stream<String> mcpSseFrames(
  Stream<List<int>> bytes, {
  int maxBytes = 10 * 1024 * 1024,
}) async* {
  final line = <int>[];
  final data = <String>[];
  var size = 0;
  var skipLf = false;
  var firstLine = true;
  await for (final chunk in bytes) {
    for (final byte in chunk) {
      if (skipLf && byte == 10) {
        skipLf = false;
        continue;
      }
      skipLf = false;
      size++;
      if (size > maxBytes) {
        throw const FormatException('SSE event exceeds the frame limit.');
      }
      if (byte != 10 && byte != 13) {
        line.add(byte);
        continue;
      }
      skipLf = byte == 13;
      var text = utf8.decode(line);
      if (firstLine && text.startsWith('\uFEFF')) text = text.substring(1);
      firstLine = false;
      line.clear();
      if (text.isEmpty) {
        if (data.isNotEmpty) yield data.join('\n');
        data.clear();
        size = 0;
      } else if (text == 'data' || text.startsWith('data:')) {
        final value = text == 'data' ? '' : text.substring(5);
        data.add(value.startsWith(' ') ? value.substring(1) : value);
      }
    }
  }
  if (line.isNotEmpty || data.isNotEmpty) {
    throw const FormatException('Incomplete SSE event.');
  }
}
