import 'dart:convert';
import 'dart:typed_data';

import 'mcp_frame_limits.dart';

/// Decode complete SSE data events; an EOF never dispatches a partial event.
Stream<String> mcpSseFrames(
  Stream<List<int>> bytes, {
  int maxBytes = mcpMaxFrameBytes,
}) async* {
  if (maxBytes <= 0) throw ArgumentError('Frame limit must be positive.');
  final line = BytesBuilder(copy: false);
  final data = <String>[];
  var size = 0;
  var skipLf = false;
  var firstLine = true;
  await for (final chunk in bytes) {
    final typed = chunk is Uint8List ? chunk : Uint8List.fromList(chunk);
    var start = 0;
    for (var index = 0; index < typed.length; index++) {
      final byte = typed[index];
      if (skipLf && byte == 10) {
        skipLf = false;
        start = index + 1;
        continue;
      }
      skipLf = false;
      size++;
      if (size > maxBytes) {
        throw const FormatException('SSE event exceeds the frame limit.');
      }
      if (byte != 10 && byte != 13) {
        continue;
      }
      if (index > start) line.add(Uint8List.sublistView(typed, start, index));
      start = index + 1;
      skipLf = byte == 13;
      var text = utf8.decode(line.takeBytes());
      if (firstLine && text.startsWith('\uFEFF')) text = text.substring(1);
      firstLine = false;
      if (text.isEmpty) {
        if (data.isNotEmpty) yield data.join('\n');
        data.clear();
        size = 0;
      } else if (text == 'data' || text.startsWith('data:')) {
        final value = text == 'data' ? '' : text.substring(5);
        data.add(value.startsWith(' ') ? value.substring(1) : value);
      }
    }
    if (start < typed.length) line.add(Uint8List.sublistView(typed, start));
  }
  if (line.isNotEmpty || data.isNotEmpty) {
    throw const FormatException('Incomplete SSE event.');
  }
}
