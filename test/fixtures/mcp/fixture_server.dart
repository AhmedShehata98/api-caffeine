import 'package:mcp_dart/mcp_dart.dart';

/// Minimal SDK peer for the transport spike. stdout is exclusively JSON-RPC.
Future<void> main() async {
  final server = McpServer(
    const Implementation(name: 'api-caffeine-basic', version: '1.0.0'),
    options: const McpServerOptions(capabilities: ServerCapabilities()),
  );
  server.registerTool(
    'echo',
    inputSchema: JsonSchema.object(
      properties: {'text': JsonSchema.string()},
      required: ['text'],
    ),
    callback: (args, extra) async =>
        CallToolResult.fromContent([TextContent(text: args['text'] as String)]),
  );
  await server.connect(StdioServerTransport());
}
