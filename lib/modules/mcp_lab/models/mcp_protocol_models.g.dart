// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'mcp_protocol_models.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_ToolAnnotations _$ToolAnnotationsFromJson(Map<String, dynamic> json) =>
    _ToolAnnotations(
      title: json['title'] as String?,
      readOnlyHint: json['readOnlyHint'] as bool?,
      destructiveHint: json['destructiveHint'] as bool?,
      idempotentHint: json['idempotentHint'] as bool?,
      openWorldHint: json['openWorldHint'] as bool?,
    );

Map<String, dynamic> _$ToolAnnotationsToJson(_ToolAnnotations instance) =>
    <String, dynamic>{
      'title': instance.title,
      'readOnlyHint': instance.readOnlyHint,
      'destructiveHint': instance.destructiveHint,
      'idempotentHint': instance.idempotentHint,
      'openWorldHint': instance.openWorldHint,
    };

_McpTool _$McpToolFromJson(Map<String, dynamic> json) => _McpTool(
  name: json['name'] as String,
  title: json['title'] as String?,
  description: json['description'] as String?,
  inputSchema: json['inputSchema'] as Map<String, dynamic>,
  outputSchema: json['outputSchema'] as Map<String, dynamic>?,
  annotations: json['annotations'] == null
      ? null
      : ToolAnnotations.fromJson(json['annotations'] as Map<String, dynamic>),
);

Map<String, dynamic> _$McpToolToJson(_McpTool instance) => <String, dynamic>{
  'name': instance.name,
  'title': instance.title,
  'description': instance.description,
  'inputSchema': instance.inputSchema,
  'outputSchema': instance.outputSchema,
  'annotations': instance.annotations,
};

_McpResource _$McpResourceFromJson(Map<String, dynamic> json) => _McpResource(
  uri: json['uri'] as String,
  name: json['name'] as String,
  title: json['title'] as String?,
  description: json['description'] as String?,
  mimeType: json['mimeType'] as String?,
  size: (json['size'] as num?)?.toInt(),
);

Map<String, dynamic> _$McpResourceToJson(_McpResource instance) =>
    <String, dynamic>{
      'uri': instance.uri,
      'name': instance.name,
      'title': instance.title,
      'description': instance.description,
      'mimeType': instance.mimeType,
      'size': instance.size,
    };

_McpResourceTemplate _$McpResourceTemplateFromJson(Map<String, dynamic> json) =>
    _McpResourceTemplate(
      uriTemplate: json['uriTemplate'] as String,
      name: json['name'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
    );

Map<String, dynamic> _$McpResourceTemplateToJson(
  _McpResourceTemplate instance,
) => <String, dynamic>{
  'uriTemplate': instance.uriTemplate,
  'name': instance.name,
  'title': instance.title,
  'description': instance.description,
  'mimeType': instance.mimeType,
};

_ResourceContents _$ResourceContentsFromJson(Map<String, dynamic> json) =>
    _ResourceContents(
      uri: json['uri'] as String,
      mimeType: json['mimeType'] as String?,
      text: json['text'] as String?,
      blob: json['blob'] as String?,
    );

Map<String, dynamic> _$ResourceContentsToJson(_ResourceContents instance) =>
    <String, dynamic>{
      'uri': instance.uri,
      'mimeType': instance.mimeType,
      'text': instance.text,
      'blob': instance.blob,
    };

TextBlock _$TextBlockFromJson(Map<String, dynamic> json) =>
    TextBlock(text: json['text'] as String, $type: json['type'] as String?);

Map<String, dynamic> _$TextBlockToJson(TextBlock instance) => <String, dynamic>{
  'text': instance.text,
  'type': instance.$type,
};

ImageBlock _$ImageBlockFromJson(Map<String, dynamic> json) => ImageBlock(
  data: json['data'] as String,
  mimeType: json['mimeType'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$ImageBlockToJson(ImageBlock instance) =>
    <String, dynamic>{
      'data': instance.data,
      'mimeType': instance.mimeType,
      'type': instance.$type,
    };

AudioBlock _$AudioBlockFromJson(Map<String, dynamic> json) => AudioBlock(
  data: json['data'] as String,
  mimeType: json['mimeType'] as String,
  $type: json['type'] as String?,
);

Map<String, dynamic> _$AudioBlockToJson(AudioBlock instance) =>
    <String, dynamic>{
      'data': instance.data,
      'mimeType': instance.mimeType,
      'type': instance.$type,
    };

EmbeddedResourceBlock _$EmbeddedResourceBlockFromJson(
  Map<String, dynamic> json,
) => EmbeddedResourceBlock(
  resource: ResourceContents.fromJson(json['resource'] as Map<String, dynamic>),
  $type: json['type'] as String?,
);

Map<String, dynamic> _$EmbeddedResourceBlockToJson(
  EmbeddedResourceBlock instance,
) => <String, dynamic>{'resource': instance.resource, 'type': instance.$type};

ResourceLinkBlock _$ResourceLinkBlockFromJson(Map<String, dynamic> json) =>
    ResourceLinkBlock(
      uri: json['uri'] as String,
      name: json['name'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      mimeType: json['mimeType'] as String?,
      size: (json['size'] as num?)?.toInt(),
      $type: json['type'] as String?,
    );

Map<String, dynamic> _$ResourceLinkBlockToJson(ResourceLinkBlock instance) =>
    <String, dynamic>{
      'uri': instance.uri,
      'name': instance.name,
      'title': instance.title,
      'description': instance.description,
      'mimeType': instance.mimeType,
      'size': instance.size,
      'type': instance.$type,
    };

_ToolCallResult _$ToolCallResultFromJson(Map<String, dynamic> json) =>
    _ToolCallResult(
      resultType:
          $enumDecodeNullable(_$ToolResultTypeEnumMap, json['resultType']) ??
          ToolResultType.complete,
      content:
          (json['content'] as List<dynamic>?)
              ?.map((e) => ContentBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          const [],
      structuredContent: json['structuredContent'],
      isError: json['isError'] as bool? ?? false,
    );

Map<String, dynamic> _$ToolCallResultToJson(_ToolCallResult instance) =>
    <String, dynamic>{
      'resultType': _$ToolResultTypeEnumMap[instance.resultType]!,
      'content': instance.content,
      'structuredContent': instance.structuredContent,
      'isError': instance.isError,
    };

const _$ToolResultTypeEnumMap = {
  ToolResultType.complete: 'complete',
  ToolResultType.inputRequired: 'input_required',
  ToolResultType.task: 'task',
};

_PromptArgument _$PromptArgumentFromJson(Map<String, dynamic> json) =>
    _PromptArgument(
      name: json['name'] as String,
      title: json['title'] as String?,
      description: json['description'] as String?,
      required: json['required'] as bool? ?? false,
    );

Map<String, dynamic> _$PromptArgumentToJson(_PromptArgument instance) =>
    <String, dynamic>{
      'name': instance.name,
      'title': instance.title,
      'description': instance.description,
      'required': instance.required,
    };

_McpPrompt _$McpPromptFromJson(Map<String, dynamic> json) => _McpPrompt(
  name: json['name'] as String,
  title: json['title'] as String?,
  description: json['description'] as String?,
  arguments:
      (json['arguments'] as List<dynamic>?)
          ?.map((e) => PromptArgument.fromJson(e as Map<String, dynamic>))
          .toList() ??
      const [],
);

Map<String, dynamic> _$McpPromptToJson(_McpPrompt instance) =>
    <String, dynamic>{
      'name': instance.name,
      'title': instance.title,
      'description': instance.description,
      'arguments': instance.arguments,
    };

_PromptMessage _$PromptMessageFromJson(Map<String, dynamic> json) =>
    _PromptMessage(
      role: $enumDecode(_$PromptRoleEnumMap, json['role']),
      content: ContentBlock.fromJson(json['content'] as Map<String, dynamic>),
    );

Map<String, dynamic> _$PromptMessageToJson(_PromptMessage instance) =>
    <String, dynamic>{
      'role': _$PromptRoleEnumMap[instance.role]!,
      'content': instance.content,
    };

const _$PromptRoleEnumMap = {
  PromptRole.user: 'user',
  PromptRole.assistant: 'assistant',
};
