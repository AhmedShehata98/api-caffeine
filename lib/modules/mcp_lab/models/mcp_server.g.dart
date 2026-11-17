// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_server.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_McpServerSettings _$McpServerSettingsFromJson(Map<String, dynamic> json) =>
    _McpServerSettings(
      protocolEra:
          $enumDecodeNullable(_$McpProtocolEraEnumMap, json['protocolEra']) ??
          McpProtocolEra.legacy,
      timeoutSeconds: (json['timeoutSeconds'] as num?)?.toInt(),
    );

Map<String, dynamic> _$McpServerSettingsToJson(_McpServerSettings instance) =>
    <String, dynamic>{
      'protocolEra': _$McpProtocolEraEnumMap[instance.protocolEra]!,
      'timeoutSeconds': instance.timeoutSeconds,
    };

const _$McpProtocolEraEnumMap = {
  McpProtocolEra.legacy: 'legacy',
  McpProtocolEra.auto: 'auto',
  McpProtocolEra.modern: 'modern',
};

_McpServerDraft _$McpServerDraftFromJson(Map<String, dynamic> json) =>
    _McpServerDraft(
      name: json['name'] as String,
      transport: $enumDecode(_$McpTransportEnumMap, json['transport']),
      command: json['command'] as String?,
      url: json['url'] as String?,
      args:
          (json['args'] as List<dynamic>?)?.map((e) => e as String).toList() ??
          const [],
      cwd: json['cwd'] as String?,
      env:
          (json['env'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      headers:
          (json['headers'] as Map<String, dynamic>?)?.map(
            (k, e) => MapEntry(k, e as String),
          ) ??
          const {},
      secretKeys:
          (json['secretKeys'] as List<dynamic>?)
              ?.map((e) => e as String)
              .toList() ??
          const [],
      settings: json['settings'] == null
          ? const McpServerSettings()
          : McpServerSettings.fromJson(
              json['settings'] as Map<String, dynamic>,
            ),
    );

Map<String, dynamic> _$McpServerDraftToJson(_McpServerDraft instance) =>
    <String, dynamic>{
      'name': instance.name,
      'transport': _$McpTransportEnumMap[instance.transport]!,
      'command': instance.command,
      'url': instance.url,
      'args': instance.args,
      'cwd': instance.cwd,
      'env': instance.env,
      'headers': instance.headers,
      'secretKeys': instance.secretKeys,
      'settings': instance.settings,
    };

const _$McpTransportEnumMap = {
  McpTransport.stdio: 'stdio',
  McpTransport.http: 'http',
  McpTransport.sse: 'sse',
};

_McpServer _$McpServerFromJson(Map<String, dynamic> json) => _McpServer(
  id: json['id'] as String,
  workspaceId: json['workspaceId'] as String,
  draft: McpServerDraft.fromJson(json['draft'] as Map<String, dynamic>),
  position: (json['position'] as num?)?.toInt(),
  secretStates:
      (json['secretStates'] as Map<String, dynamic>?)?.map(
        (k, e) => MapEntry(k, $enumDecode(_$SecretValueStateEnumMap, e)),
      ) ??
      const {},
);

Map<String, dynamic> _$McpServerToJson(_McpServer instance) =>
    <String, dynamic>{
      'id': instance.id,
      'workspaceId': instance.workspaceId,
      'draft': instance.draft,
      'position': instance.position,
      'secretStates': instance.secretStates.map(
        (k, e) => MapEntry(k, _$SecretValueStateEnumMap[e]!),
      ),
    };

const _$SecretValueStateEnumMap = {
  SecretValueState.present: 'present',
  SecretValueState.missingOnDevice: 'missingOnDevice',
};
