// Freezed copies constructor JSON annotations onto its generated classes.
// ignore_for_file: invalid_annotation_target

import 'package:freezed_annotation/freezed_annotation.dart';

part 'mcp_protocol_models.freezed.dart';
part 'mcp_protocol_models.g.dart';

@freezed
abstract class ToolAnnotations with _$ToolAnnotations {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ToolAnnotations({
    String? title,
    bool? readOnlyHint,
    bool? destructiveHint,
    bool? idempotentHint,
    bool? openWorldHint,
  }) = _ToolAnnotations;
  factory ToolAnnotations.fromJson(Map<String, dynamic> json) =>
      _$ToolAnnotationsFromJson(json);
}

@freezed
abstract class McpTool with _$McpTool {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory McpTool({
    required String name,
    String? title,
    String? description,
    required Map<String, dynamic> inputSchema,
    Map<String, dynamic>? outputSchema,
    ToolAnnotations? annotations,
  }) = _McpTool;
  factory McpTool.fromJson(Map<String, dynamic> json) =>
      _$McpToolFromJson(json);
}

@freezed
abstract class McpResource with _$McpResource {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory McpResource({
    required String uri,
    required String name,
    String? title,
    String? description,
    String? mimeType,
    int? size,
  }) = _McpResource;
  factory McpResource.fromJson(Map<String, dynamic> json) =>
      _$McpResourceFromJson(json);
}

@freezed
abstract class McpResourceTemplate with _$McpResourceTemplate {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory McpResourceTemplate({
    required String uriTemplate,
    required String name,
    String? title,
    String? description,
    String? mimeType,
  }) = _McpResourceTemplate;
  factory McpResourceTemplate.fromJson(Map<String, dynamic> json) =>
      _$McpResourceTemplateFromJson(json);
}

@freezed
abstract class ResourceContents with _$ResourceContents {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ResourceContents({
    required String uri,
    String? mimeType,
    String? text,
    String? blob,
  }) = _ResourceContents;
  factory ResourceContents.fromJson(Map<String, dynamic> json) =>
      _$ResourceContentsFromJson(json);
}

@Freezed(unionKey: 'type')
sealed class ContentBlock with _$ContentBlock {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ContentBlock.text({required String text}) = TextBlock;
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ContentBlock.image({
    required String data,
    required String mimeType,
  }) = ImageBlock;
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ContentBlock.audio({
    required String data,
    required String mimeType,
  }) = AudioBlock;
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ContentBlock.resource({required ResourceContents resource}) =
      EmbeddedResourceBlock;
  @FreezedUnionValue('resource_link')
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ContentBlock.resourceLink({
    required String uri,
    required String name,
    String? title,
    String? description,
    String? mimeType,
    int? size,
  }) = ResourceLinkBlock;
  factory ContentBlock.fromJson(Map<String, dynamic> json) =>
      _$ContentBlockFromJson(json);
}

enum ToolResultType {
  complete,
  @JsonValue('input_required')
  inputRequired,
  task,
}

@freezed
abstract class ToolCallResult with _$ToolCallResult {
  const ToolCallResult._();
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory ToolCallResult({
    @Default(ToolResultType.complete) ToolResultType resultType,
    @Default([]) List<ContentBlock> content,
    Object? structuredContent,
    @Default(false) bool isError,
  }) = _ToolCallResult;
  factory ToolCallResult.fromJson(Map<String, dynamic> json) =>
      _$ToolCallResultFromJson(json);

  /// Tool errors are successful protocol results, not infrastructure failures.
  String? get outcomeCode => isError ? 'tool_error' : null;
}

@freezed
abstract class PromptArgument with _$PromptArgument {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory PromptArgument({
    required String name,
    String? title,
    String? description,
    @Default(false) bool required,
  }) = _PromptArgument;
  factory PromptArgument.fromJson(Map<String, dynamic> json) =>
      _$PromptArgumentFromJson(json);
}

@freezed
abstract class McpPrompt with _$McpPrompt {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory McpPrompt({
    required String name,
    String? title,
    String? description,
    @Default([]) List<PromptArgument> arguments,
  }) = _McpPrompt;
  factory McpPrompt.fromJson(Map<String, dynamic> json) =>
      _$McpPromptFromJson(json);
}

enum PromptRole { user, assistant }

@freezed
abstract class PromptMessage with _$PromptMessage {
  @JsonSerializable(fieldRename: FieldRename.none)
  const factory PromptMessage({
    required PromptRole role,
    required ContentBlock content,
  }) = _PromptMessage;
  factory PromptMessage.fromJson(Map<String, dynamic> json) =>
      _$PromptMessageFromJson(json);
}
