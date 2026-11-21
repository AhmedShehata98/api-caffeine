import 'dart:convert';
import 'dart:io';

import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab_protocol.dart';

/// Also runnable directly with Dart while Flutter native hooks are unavailable.
void main() {
  void check(bool condition, String message) {
    if (!condition) throw StateError(message);
  }

  Object asObject(Object value) => value;

  void roundTrip<T>(
    T value,
    Map<String, dynamic> Function() encode,
    T Function(Map<String, dynamic>) decode,
  ) {
    final json = jsonDecode(jsonEncode(encode())) as Map<String, dynamic>;
    check(decode(json) == value, 'Round trip failed for $T');
  }

  const settings = McpServerSettings();
  check(
    McpServerSettings.fromJson({'protocolEra': 'modern'}).protocolEra ==
        McpProtocolEra.modern,
    'Server settings must use camelCase wire keys',
  );
  roundTrip(settings, settings.toJson, McpServerSettings.fromJson);
  check(
    settings.protocolEra == McpProtocolEra.legacy,
    'Default era must be legacy',
  );
  const draft = McpServerDraft(
    name: 'Fixture',
    transport: McpTransport.stdio,
    command: 'dart',
    args: ['--era=modern'],
    env: {'TOKEN': ''},
    secretKeys: ['env.TOKEN'],
  );
  roundTrip(draft, draft.toJson, McpServerDraft.fromJson);
  const server = McpServer(
    id: 'server',
    workspaceId: 'workspace',
    draft: draft,
    secretStates: {'env.TOKEN': SecretValueState.missingOnDevice},
  );
  roundTrip(server, server.toJson, McpServer.fromJson);
  check(
    server.draft.settings.protocolEra == McpProtocolEra.legacy,
    'Server args must not change Lab settings',
  );
  var immutable = false;
  try {
    draft.args.add('mutate');
  } on UnsupportedError {
    immutable = true;
  }
  check(immutable, 'Model collections must be immutable');
  const annotations = ToolAnnotations(
    readOnlyHint: true,
    destructiveHint: false,
  );
  roundTrip(annotations, annotations.toJson, ToolAnnotations.fromJson);
  const tool = McpTool(
    name: 'echo',
    inputSchema: {'type': 'object'},
    outputSchema: {'type': 'array'},
    annotations: annotations,
  );
  roundTrip(tool, tool.toJson, McpTool.fromJson);
  const resource = McpResource(
    uri: 'test://data',
    name: 'data',
    mimeType: 'text/plain',
  );
  roundTrip(resource, resource.toJson, McpResource.fromJson);
  const template = McpResourceTemplate(
    uriTemplate: 'test://{name}',
    name: 'template',
  );
  roundTrip(template, template.toJson, McpResourceTemplate.fromJson);
  for (final contents in [
    const ResourceContents(uri: 'test://text', text: 'hello'),
    const ResourceContents(
      uri: 'test://blob',
      blob: 'AQID',
      mimeType: 'application/octet-stream',
    ),
  ]) {
    roundTrip(contents, contents.toJson, ResourceContents.fromJson);
  }
  const blocks = <ContentBlock>[
    ContentBlock.text(text: 'hello'),
    ContentBlock.image(data: 'AQID', mimeType: 'image/png'),
    ContentBlock.audio(data: 'AQID', mimeType: 'audio/wav'),
    ContentBlock.resource(
      resource: ResourceContents(uri: 'test://embedded', text: 'embedded'),
    ),
    ContentBlock.resourceLink(uri: 'test://link', name: 'linked'),
  ];
  for (final block in blocks) {
    roundTrip(block, block.toJson, ContentBlock.fromJson);
  }
  check(
    blocks.last.toJson()['type'] == 'resource_link',
    'MCP content discriminator mismatch',
  );
  check(
    ContentBlock.fromJson({
          'type': 'image',
          'data': 'AQID',
          'mimeType': 'image/png',
        }) ==
        blocks[1],
    'MCP mimeType wire key mismatch',
  );
  check(
    McpTool.fromJson({
          'name': 'echo',
          'inputSchema': {'type': 'object'},
        }).inputSchema['type'] ==
        'object',
    'MCP inputSchema wire key mismatch',
  );
  for (final structured in <Object?>[
    null,
    false,
    42,
    'text',
    [1, 2],
    {'items': []},
  ]) {
    final result = ToolCallResult(
      content: blocks,
      structuredContent: structured,
      isError: true,
    );
    roundTrip(result, result.toJson, ToolCallResult.fromJson);
    check(
      result.outcomeCode == 'tool_error',
      'Tool error must remain a result',
    );
  }
  check(
    ToolCallResult.fromJson({}).resultType == ToolResultType.complete,
    'Absent resultType must mean complete',
  );
  check(
    ToolCallResult.fromJson({'resultType': 'input_required'}).resultType ==
        ToolResultType.inputRequired,
    'input_required wire enum mismatch',
  );
  const argument = PromptArgument(name: 'name', required: true);
  roundTrip(argument, argument.toJson, PromptArgument.fromJson);
  const prompt = McpPrompt(name: 'greet', arguments: [argument]);
  roundTrip(prompt, prompt.toJson, McpPrompt.fromJson);
  const message = PromptMessage(
    role: PromptRole.assistant,
    content: ContentBlock.text(text: 'hello'),
  );
  roundTrip(message, message.toJson, PromptMessage.fromJson);
  final frame = RpcFrame(
    direction: RpcDirection.incoming,
    timestamp: DateTime.utc(2026),
    kind: RpcFrameKind.response,
    id: 'string-id',
    rawJson: '{}',
    size: 2,
    redacted: true,
  );
  roundTrip(frame, frame.toJson, RpcFrame.fromJson);
  const network = NetworkEntry(
    method: 'POST',
    url: 'https://example.test',
    requestBody: '{"safe":true}',
    requestTruncated: true,
    body: '{"response":true}',
    duration: Duration(microseconds: 1234),
    responseHeaders: {
      'content-type': ['application/json'],
    },
  );
  roundTrip(network, network.toJson, NetworkEntry.fromJson);
  final console = ConsoleLine(timestamp: DateTime.utc(2026), text: 'sanitized');
  roundTrip(console, console.toJson, ConsoleLine.fromJson);
  final versions = ['2025-11-25'];
  final failure = McpNetworkFailure(
    'Unsupported version',
    code: McpErrorCode.protocolVersionUnsupported,
    supportedVersions: versions,
  );
  versions.clear();
  check(
    asObject(failure) is NetworkFailure &&
        failure.supportedVersions!.length == 1,
    'Failure must retain core kind and immutable metadata',
  );
  check(
    asObject(const McpAuthFailure('Sign in')) is AuthFailure,
    'Auth kind lost',
  );
  check(
    asObject(const McpStorageFailure('Unavailable')) is StorageFailure,
    'Storage kind lost',
  );
  check(
    asObject(
      const McpValidationFailure('Invalid', code: McpErrorCode.invalidParams),
    ) is ValidationFailure,
    'Validation kind lost',
  );
  check(
    const McpUnexpectedFailure('Exited', exitCode: 1).exitCode == 1,
    'Exit metadata lost',
  );
  check(
    const ConnectionStatus.connected(
      era: NegotiatedEra.modern,
      serverInfo: {'name': 'test'},
    ) is ConnectionConnected,
    'Connection state mismatch',
  );
  stdout.writeln(
    'PASS: MCP model round trips, defaults, immutability and failure kinds',
  );
}
