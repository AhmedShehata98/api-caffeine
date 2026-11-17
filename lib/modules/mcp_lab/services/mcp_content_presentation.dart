import '../models/mcp_protocol_models.dart';
import 'mcp_session_work.dart';

enum McpContentOrigin { resource, tool, prompt }

ResourceContents? resourceForMcpContent(ContentBlock block) => switch (block) {
  ImageBlock(:final data, :final mimeType) => ResourceContents(
    uri: 'mcp-result:image',
    blob: data,
    mimeType: mimeType,
  ),
  AudioBlock(:final data, :final mimeType) => ResourceContents(
    uri: 'mcp-result:audio',
    blob: data,
    mimeType: mimeType,
  ),
  EmbeddedResourceBlock(:final resource) => resource,
  TextBlock(:final text) => ResourceContents(
    uri: 'mcp-result:text',
    text: text,
    mimeType: 'text/plain',
  ),
  ResourceLinkBlock() => null,
};

Object? mcpContentResult(McpSessionWork work, McpContentOrigin origin) =>
    switch (origin) {
      McpContentOrigin.resource => work.resources.state.outcome,
      McpContentOrigin.tool => work.tools.state.outcome,
      McpContentOrigin.prompt => work.prompts.state.outcome,
    };

bool ownsMcpContent(
  McpSessionWork work,
  McpContentOrigin origin,
  ContentBlock block,
) => switch (origin) {
  McpContentOrigin.resource => false,
  McpContentOrigin.tool =>
    work.tools.state.outcome?.valueOrNull?.result.content.any(
          (item) => identical(item, block),
        ) ??
        false,
  McpContentOrigin.prompt =>
    work.prompts.state.outcome?.valueOrNull?.messages.any(
          (message) => identical(message.content, block),
        ) ??
        false,
};
