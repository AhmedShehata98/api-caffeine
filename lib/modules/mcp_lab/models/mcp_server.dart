// Freezed copies constructor JSON annotations onto its generated classes.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_server.freezed.dart';
part 'mcp_server.g.dart';

enum McpTransport { stdio, http, sse }

enum McpProtocolEra { legacy, auto, modern }

enum SecretValueState { present, missingOnDevice }

/// Credential-bearing header names default to device-only storage/redaction.
bool isMcpCredentialHeader(String name) {
  final key = name.toLowerCase();
  return const {
        'authorization',
        'proxy-authorization',
        'cookie',
        'x-api-key',
      }.contains(key) ||
      RegExp(r'-(token|key|secret)$').hasMatch(key);
}

@freezed
abstract class McpServerSettings with _$McpServerSettings {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory McpServerSettings({
    @Default(McpProtocolEra.legacy) McpProtocolEra protocolEra,
    int? timeoutSeconds,
  }) = _McpServerSettings;
  factory McpServerSettings.fromJson(Map<String, dynamic> json) =>
      _$McpServerSettingsFromJson(json);
}

@freezed
abstract class McpServerDraft with _$McpServerDraft {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory McpServerDraft({
    required String name,
    required McpTransport transport,
    String? command,
    String? url,
    @Default([]) List<String> args,
    String? cwd,
    @Default({}) Map<String, String> env,
    @Default({}) Map<String, String> headers,
    @Default([]) List<String> secretKeys,
    @Default(McpServerSettings()) McpServerSettings settings,
  }) = _McpServerDraft;
  factory McpServerDraft.fromJson(Map<String, dynamic> json) =>
      _$McpServerDraftFromJson(json);
}

@freezed
abstract class McpServer with _$McpServer {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory McpServer({
    required String id,
    required String workspaceId,
    required McpServerDraft draft,
    int? position,
    @Default({}) Map<String, SecretValueState> secretStates,
  }) = _McpServer;
  factory McpServer.fromJson(Map<String, dynamic> json) =>
      _$McpServerFromJson(json);
}
