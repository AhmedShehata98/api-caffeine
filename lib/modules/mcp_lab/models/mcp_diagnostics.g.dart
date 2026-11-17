// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_diagnostics.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_RpcFrame _$RpcFrameFromJson(Map<String, dynamic> json) => _RpcFrame(
  direction: $enumDecode(_$RpcDirectionEnumMap, json['direction']),
  timestamp: DateTime.parse(json['timestamp'] as String),
  kind: $enumDecode(_$RpcFrameKindEnumMap, json['kind']),
  id: json['id'],
  method: json['method'] as String?,
  rawJson: json['raw_json'] as String,
  size: (json['size'] as num).toInt(),
  pairedId: json['paired_id'],
  meta: json['meta'] as Map<String, dynamic>? ?? const {},
  redacted: json['redacted'] as bool? ?? false,
);

Map<String, dynamic> _$RpcFrameToJson(_RpcFrame instance) => <String, dynamic>{
  'direction': _$RpcDirectionEnumMap[instance.direction]!,
  'timestamp': instance.timestamp.toIso8601String(),
  'kind': _$RpcFrameKindEnumMap[instance.kind]!,
  'id': instance.id,
  'method': instance.method,
  'raw_json': instance.rawJson,
  'size': instance.size,
  'paired_id': instance.pairedId,
  'meta': instance.meta,
  'redacted': instance.redacted,
};

const _$RpcDirectionEnumMap = {
  RpcDirection.incoming: 'incoming',
  RpcDirection.outgoing: 'outgoing',
};

const _$RpcFrameKindEnumMap = {
  RpcFrameKind.request: 'request',
  RpcFrameKind.response: 'response',
  RpcFrameKind.notification: 'notification',
  RpcFrameKind.warning: 'warning',
};

_NetworkEntry _$NetworkEntryFromJson(
  Map<String, dynamic> json,
) => _NetworkEntry(
  method: json['method'] as String,
  url: json['url'] as String,
  status: (json['status'] as num?)?.toInt(),
  requestHeaders:
      (json['request_headers'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ) ??
      const {},
  responseHeaders:
      (json['response_headers'] as Map<String, dynamic>?)?.map(
        (k, e) =>
            MapEntry(k, (e as List<dynamic>).map((e) => e as String).toList()),
      ) ??
      const {},
  body: json['body'] as String?,
  truncated: json['truncated'] as bool? ?? false,
  duration: Duration(microseconds: (json['duration'] as num).toInt()),
);

Map<String, dynamic> _$NetworkEntryToJson(_NetworkEntry instance) =>
    <String, dynamic>{
      'method': instance.method,
      'url': instance.url,
      'status': instance.status,
      'request_headers': instance.requestHeaders,
      'response_headers': instance.responseHeaders,
      'body': instance.body,
      'truncated': instance.truncated,
      'duration': instance.duration.inMicroseconds,
    };

_ConsoleLine _$ConsoleLineFromJson(Map<String, dynamic> json) => _ConsoleLine(
  timestamp: DateTime.parse(json['timestamp'] as String),
  text: json['text'] as String,
);

Map<String, dynamic> _$ConsoleLineToJson(_ConsoleLine instance) =>
    <String, dynamic>{
      'timestamp': instance.timestamp.toIso8601String(),
      'text': instance.text,
    };
