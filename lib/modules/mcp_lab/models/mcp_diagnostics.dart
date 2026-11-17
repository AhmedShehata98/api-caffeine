import 'package:freezed_annotation/freezed_annotation.dart';

import 'mcp_failure.dart';

part 'mcp_diagnostics.freezed.dart';
part 'mcp_diagnostics.g.dart';

enum RpcDirection { incoming, outgoing }

enum RpcFrameKind { request, response, notification, warning }

enum NegotiatedEra { legacy, modern }

@freezed
abstract class RpcFrame with _$RpcFrame {
  const factory RpcFrame({
    required RpcDirection direction,
    required DateTime timestamp,
    required RpcFrameKind kind,
    Object? id,
    String? method,
    required String rawJson,
    required int size,
    Object? pairedId,
    @Default({}) Map<String, dynamic> meta,
    @Default(false) bool redacted,
  }) = _RpcFrame;
  factory RpcFrame.fromJson(Map<String, dynamic> json) =>
      _$RpcFrameFromJson(json);
}

@freezed
abstract class NetworkEntry with _$NetworkEntry {
  const factory NetworkEntry({
    required String method,
    required String url,
    int? status,
    @Default({}) Map<String, List<String>> requestHeaders,
    @Default({}) Map<String, List<String>> responseHeaders,
    String? body,
    @Default(false) bool truncated,
    required Duration duration,
  }) = _NetworkEntry;
  factory NetworkEntry.fromJson(Map<String, dynamic> json) =>
      _$NetworkEntryFromJson(json);
}

@freezed
abstract class ConsoleLine with _$ConsoleLine {
  const factory ConsoleLine({
    required DateTime timestamp,
    required String text,
  }) = _ConsoleLine;
  factory ConsoleLine.fromJson(Map<String, dynamic> json) =>
      _$ConsoleLineFromJson(json);
}

// Runtime state intentionally has no JSON codec: failures are not persisted.
@freezed
sealed class ConnectionStatus with _$ConnectionStatus {
  const factory ConnectionStatus.idle() = ConnectionIdle;
  const factory ConnectionStatus.connecting() = ConnectionConnecting;
  const factory ConnectionStatus.connected({
    required NegotiatedEra era,
    required Map<String, dynamic> serverInfo,
  }) = ConnectionConnected;
  const factory ConnectionStatus.disconnected({McpCoded? failure}) =
      ConnectionDisconnected;
}
