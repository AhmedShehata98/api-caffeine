import 'dart:convert';
import 'dart:typed_data';

import 'mcp_frame_limits.dart';

class McpSseEvent {
  const McpSseEvent({
    this.data,
    this.id,
    this.retryMilliseconds,
    this.type = 'message',
  });
  final String? data;
  final String? id;
  final int? retryMilliseconds;
  final String type;
}

class McpSseIncompleteEvent extends FormatException {
  const McpSseIncompleteEvent() : super('Incomplete SSE event.');
}

/// Compatibility projection for consumers that only need JSON data frames.
Stream<String> mcpSseFrames(
  Stream<List<int>> bytes, {
  int maxBytes = mcpMaxFrameBytes,
}) async* {
  await for (final event in mcpSseEvents(bytes, maxBytes: maxBytes)) {
    if (event.data case final data?) yield data;
  }
}

/// Only completed blocks publish metadata; partial events are never dispatched.
Stream<McpSseEvent> mcpSseEvents(
  Stream<List<int>> bytes, {
  int maxBytes = mcpMaxFrameBytes,
}) async* {
  if (maxBytes <= 0) throw ArgumentError('Frame limit must be positive.');
  final line = BytesBuilder(copy: false);
  final data = <String>[];
  var size = 0;
  var skipLf = false;
  var firstLine = true;
  String? id;
  int? retry;
  var type = 'message';
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
        if (data.isNotEmpty || id != null || retry != null) {
          yield McpSseEvent(
            data: data.isEmpty ? null : data.join('\n'),
            id: id,
            retryMilliseconds: retry,
            type: type,
          );
        }
        data.clear();
        id = null;
        retry = null;
        type = 'message';
        size = 0;
      } else if (text == 'data' || text.startsWith('data:')) {
        final value = text == 'data' ? '' : text.substring(5);
        data.add(value.startsWith(' ') ? value.substring(1) : value);
      } else if (text == 'id' || text.startsWith('id:')) {
        final value = text == 'id' ? '' : text.substring(3);
        if (!value.contains('\u0000')) {
          id = value.startsWith(' ') ? value.substring(1) : value;
        }
      } else if (text.startsWith('retry:')) {
        var value = text.substring(6);
        if (value.startsWith(' ')) value = value.substring(1);
        if (RegExp(r'^[0-9]+$').hasMatch(value)) {
          retry = (int.tryParse(value) ?? 0x7fffffff).clamp(0, 0x7fffffff);
        }
      } else if (text == 'event' || text.startsWith('event:')) {
        var value = text == 'event' ? '' : text.substring(6);
        if (value.startsWith(' ')) value = value.substring(1);
        type = value.isEmpty ? 'message' : value;
      }
    }
    if (start < typed.length) line.add(Uint8List.sublistView(typed, start));
  }
  if (line.isNotEmpty || data.isNotEmpty || id != null || retry != null) {
    throw const McpSseIncompleteEvent();
  }
}
