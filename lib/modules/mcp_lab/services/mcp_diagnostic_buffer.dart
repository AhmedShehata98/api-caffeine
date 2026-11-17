import 'dart:convert';
import 'dart:isolate';

import 'package:test_point/core/error/result.dart';

import '../models/mcp_diagnostics.dart';
import '../models/mcp_failure.dart';

enum McpMonitorKind { protocol, network, console }

class McpMonitorEntry {
  const McpMonitorEntry({
    required this.sequence,
    required this.text,
    required this.size,
    required this.truncated,
    this.frame,
    this.network,
    this.console,
    this.pairedSequence,
    this.duration,
    this.fullAvailable = true,
  });
  final int sequence;
  final String text;
  final int size;
  final bool truncated;
  final RpcFrame? frame;
  final NetworkEntry? network;
  final ConsoleLine? console;
  final int? pairedSequence;
  final Duration? duration;
  final bool fullAvailable;

  McpMonitorEntry paired(int sequence, Duration duration) => McpMonitorEntry(
    sequence: this.sequence,
    text: text,
    size: size,
    truncated: truncated,
    frame: frame,
    network: network,
    console: console,
    pairedSequence: sequence,
    duration: duration,
    fullAvailable: fullAvailable,
  );

  McpMonitorEntry unpaired() => McpMonitorEntry(
    sequence: sequence,
    text: text,
    size: size,
    truncated: truncated,
    frame: frame,
    network: network,
    console: console,
    fullAvailable: fullAvailable,
  );
}

/// Accepts only the session contract's already sanitized diagnostic events.
/// Operation results must never be passed here. Full text is memory-only and is
/// evicted with its entry; Copy and Load full read the same sanitized text.
class McpDiagnosticBuffer {
  McpDiagnosticBuffer({
    this.capacity = 10000,
    this.previewBytes = 256 * 1024,
    this.bodyBudgetBytes = 64 * 1024 * 1024,
  }) {
    if (capacity <= 0 || previewBytes <= 0 || bodyBudgetBytes <= 0) {
      throw ArgumentError('Diagnostic limits must be positive.');
    }
  }
  final int capacity;
  final int previewBytes;
  final int bodyBudgetBytes;
  final _entries = <int, McpMonitorEntry>{};
  final _full = <int, String>{};
  final _pending = <(RpcDirection, Object), int>{};
  var _next = 0;
  var _bytes = 0;
  var _epoch = 0;
  var _disposed = false;
  int dropped = 0;
  List<McpMonitorEntry> get entries => List.unmodifiable(_entries.values);
  int get retainedBodyBytes => _bytes;

  void addFrame(RpcFrame frame) => _add(frame.rawJson, frame: frame);
  void addNetwork(NetworkEntry entry) => _add(entry.body ?? '', network: entry);
  void addConsole(ConsoleLine line) => _add(line.text, console: line);

  void _add(
    String text, {
    RpcFrame? frame,
    NetworkEntry? network,
    ConsoleLine? console,
  }) {
    if (_disposed) return;
    final bytes = utf8.encode(text);
    if (bytes.length > bodyBudgetBytes) {
      dropped++;
      return;
    }
    final truncated = bytes.length > previewBytes;
    var end = truncated ? previewBytes : bytes.length;
    // End on a UTF-8 code point boundary, without replacement characters.
    while (end < bytes.length && end > 0 && bytes[end] & 0xc0 == 0x80) {
      end--;
    }
    final preview = truncated ? utf8.decode(bytes.sublist(0, end)) : text;
    final sequence = _next++;
    var entry = McpMonitorEntry(
      sequence: sequence,
      text: preview,
      size: bytes.length,
      truncated: truncated || (network?.truncated ?? false),
      fullAvailable: !(network?.truncated ?? false),
      frame: frame?.copyWith(rawJson: preview),
      network: network?.copyWith(
        body: preview,
        truncated: truncated || network.truncated,
      ),
      console: console?.copyWith(text: preview),
    );
    while (_entries.length >= capacity ||
        _bytes + bytes.length > bodyBudgetBytes) {
      _evict();
    }
    if (frame != null && (frame.id is String || frame.id is int)) {
      final key = (frame.direction, frame.id!);
      if (frame.kind == RpcFrameKind.request) {
        _pending[key] = sequence;
      } else if (frame.kind == RpcFrameKind.response) {
        final direction = frame.direction == RpcDirection.incoming
            ? RpcDirection.outgoing
            : RpcDirection.incoming;
        final requestSequence = _pending.remove((direction, frame.id!));
        final request = _entries[requestSequence];
        if (request != null) {
          final elapsed = frame.timestamp.difference(request.frame!.timestamp);
          final duration = elapsed.isNegative ? Duration.zero : elapsed;
          _entries[requestSequence!] = request.paired(sequence, duration);
          entry = entry.paired(requestSequence, duration);
        }
      }
    }
    _entries[sequence] = entry;
    _full[sequence] = text;
    _bytes += bytes.length;
  }

  void _evict() {
    final first = _entries.entries.first;
    _entries.remove(first.key);
    final partner = _entries[first.value.pairedSequence];
    if (partner != null) _entries[partner.sequence] = partner.unpaired();
    _full.remove(first.key);
    _bytes -= first.value.size;
    final frame = first.value.frame;
    if (frame?.id != null &&
        _pending[(frame!.direction, frame.id!)] == first.key) {
      _pending.remove((frame.direction, frame.id!));
    }
    dropped++;
  }

  Result<String> copyText(int sequence) {
    final text = _full[sequence];
    return text == null || _disposed
        ? const Result.failure(_unavailable)
        : Result.success(text);
  }

  Future<Result<Object?>> loadFullJson(int sequence) async {
    final epoch = _epoch;
    if (_entries[sequence]?.fullAvailable == false) {
      return const Result.failure(
        McpValidationFailure(
          'The transport retained only a partial body.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
    final text = copyText(sequence);
    if (text case Err(:final failure)) return Result.failure(failure);
    final isEventStream =
        _entries[sequence]?.network?.responseHeaders.entries.any(
          (entry) =>
              entry.key.toLowerCase() == 'content-type' &&
              entry.value.any(
                (value) =>
                    value.split(';').first.trim().toLowerCase() ==
                    'text/event-stream',
              ),
        ) ??
        false;
    try {
      final body = text.valueOrNull!;
      final parsed = await Isolate.run(
        () => isEventStream ? _decodeCapturedFrames(body) : jsonDecode(body),
      );
      if (_disposed || epoch != _epoch || !_full.containsKey(sequence)) {
        return const Result.failure(_unavailable);
      }
      return Result.success(parsed);
    } on FormatException {
      return const Result.failure(
        McpValidationFailure(
          'This diagnostic body is not valid JSON.',
          code: McpErrorCode.invalidParams,
        ),
      );
    }
  }

  void clear() {
    _epoch++;
    _entries.clear();
    _full.clear();
    _pending.clear();
    _bytes = 0;
    dropped = 0;
  }

  void dispose() {
    _disposed = true;
    clear();
  }

  static const _unavailable = McpValidationFailure(
    'This diagnostic body is no longer retained.',
    code: McpErrorCode.invalidParams,
  );
}

/// Network SSE diagnostics retain sanitized JSON data frames, not SSE envelopes.
/// Frame boundaries can span pretty-printed lines and escaped JSON strings.
List<Object?> _decodeCapturedFrames(String text) {
  final frames = <Object?>[];
  var start = -1;
  var depth = 0;
  var quoted = false;
  var escaped = false;
  for (var index = 0; index < text.length; index++) {
    final unit = text.codeUnitAt(index);
    if (start < 0) {
      if (unit == 32 || unit == 9 || unit == 10 || unit == 13) continue;
      if (unit != 123) throw const FormatException();
      start = index;
    }
    if (quoted) {
      if (escaped) {
        escaped = false;
      } else if (unit == 92) {
        escaped = true;
      } else if (unit == 34) {
        quoted = false;
      }
    } else if (unit == 34) {
      quoted = true;
    } else if (unit == 123 || unit == 91) {
      depth++;
    } else if (unit == 125 || unit == 93) {
      depth--;
      if (depth == 0) {
        frames.add(jsonDecode(text.substring(start, index + 1)));
        start = -1;
      }
    }
  }
  if (start >= 0) throw const FormatException();
  return frames;
}
