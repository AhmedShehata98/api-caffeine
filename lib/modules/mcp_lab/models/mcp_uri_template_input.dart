enum McpUriTemplateInputKind { text, list, object }

/// Unsubmitted memory-only input. Invalid JSON remains editable across tabs.
class McpUriTemplateInput {
  const McpUriTemplateInput(
    this.text, {
    this.kind = McpUriTemplateInputKind.text,
  });
  final String text;
  final McpUriTemplateInputKind kind;
}
