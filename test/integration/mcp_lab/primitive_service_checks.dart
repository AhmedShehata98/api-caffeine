import 'dart:convert';
import 'dart:io';

import 'package:test_point/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';

/// Standalone loopback harness: actual HTTP/session/negotiation plus S1 services.
Future<void> main() async {
  final peer = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  const capabilities = {
    'tools': <String, dynamic>{},
    'resources': <String, dynamic>{},
    'prompts': <String, dynamic>{},
  };
  peer.listen((request) async {
    if (request.method == 'DELETE') {
      request.response.statusCode = 204;
      await request.response.close();
      return;
    }
    final rpc = jsonDecode(
      await utf8.decoder.bind(request).join(),
    ) as Map<String, dynamic>;
    if (!rpc.containsKey('id')) {
      request.response.statusCode = 202;
      await request.response.close();
      return;
    }
    final params = rpc['params'] as Map;
    final result = switch (rpc['method']) {
      'initialize' => {
        'protocolVersion': '2025-11-25',
        'serverInfo': {'name': 'primitives', 'version': '1'},
        'capabilities': capabilities,
      },
      'server/discover' => {
        'supportedVersions': ['2026-07-28'],
        'serverInfo': {'name': 'primitives', 'version': '1'},
        'capabilities': capabilities,
      },
      'tools/list' => {
        'tools': [
          {
            'name': params['cursor'] == null ? 'add' : 'echo',
            'inputSchema': {'type': 'object'},
          },
        ],
        if (params['cursor'] == null) 'nextCursor': 'second',
      },
      'tools/call' => {
        'content': [
          {'type': 'text', 'text': '5'},
        ],
        'isError': params['name'] == 'fail',
      },
      'resources/list' => {
        'resources': [
          {'uri': 'test:///one', 'name': 'one'},
        ],
        'nextCursor': 'next',
      },
      'resources/templates/list' => {
        'resourceTemplates': [
          {'uriTemplate': 'test:///{id}', 'name': 'template'},
        ],
      },
      'resources/read' => {
        'contents': [
          {'uri': params['uri'], 'text': 'resource'},
        ],
      },
      'prompts/list' => {
        'prompts': [
          {
            'name': 'city',
            'arguments': [
              {'name': 'city', 'required': true},
            ],
          },
        ],
      },
      'prompts/get' => {
        'messages': [
          {
            'role': 'user',
            'content': {'type': 'text', 'text': params['arguments']['city']},
          },
        ],
      },
      _ => throw StateError('Unexpected fixture method'),
    };
    request.response.headers.contentType = ContentType.json;
    request.response.write(
      jsonEncode({'jsonrpc': '2.0', 'id': rpc['id'], 'result': result}),
    );
    await request.response.close();
  });
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  try {
    for (final era in [McpProtocolEra.legacy, McpProtocolEra.modern]) {
      const context = McpAccessContext(
        userId: 'u',
        workspaceId: 'w',
        generation: 1,
      );
      final repository = McpHttpConnectionRepository(
        isAuthorized: (_, _) => true,
        clientVersion: '1',
      );
      final target = McpConnectTarget(
        context: context,
        timeout: const Duration(seconds: 3),
        server: McpServer(
          id: 's',
          workspaceId: 'w',
          draft: McpServerDraft(
            name: 'Fixture',
            transport: McpTransport.http,
            url: 'http://127.0.0.1:${peer.port}/mcp',
          ),
        ),
      );
      final session = (await repository.connect(target)).valueOrNull!;
      try {
        final negotiated = (await const McpNegotiationService(
          clientVersion: '1',
        ).negotiate(session, era: era)).valueOrNull!;
        final services = McpPrimitiveServices(
          session,
          negotiated,
          isAuthorized: () => true,
        );
        check(
          (await services.tools.list()).valueOrNull!.length == 2,
          'Tool pagination failed',
        );
        check(
          (await services.tools.call('add', {
                'a': 2,
                'b': 3,
              })).valueOrNull!.result.content.single ==
              const ContentBlock.text(text: '5'),
          'Tool call failed',
        );
        check(
          (await services.tools.call(
                'fail',
                {},
              )).valueOrNull!.result.outcomeCode ==
              'tool_error',
          'Tool error became transport failure',
        );
        check(
          (await services.resources.list()).valueOrNull!.nextCursor == 'next',
          'Resource cursor lost',
        );
        check(
          (await services.resources.templates())
                  .valueOrNull!
                  .items
                  .single
                  .name ==
              'template',
          'Templates failed',
        );
        check(
          (await services.resources.read('test:///one'))
                  .valueOrNull!
                  .single
                  .text ==
              'resource',
          'Resource read failed',
        );
        final prompt = (await services.prompts.list()).valueOrNull!.single;
        check(
          (await services.prompts.get(prompt, {
                'city': 'Cairo',
              })).valueOrNull!.messages.single.content ==
              const ContentBlock.text(text: 'Cairo'),
          'Prompt get failed',
        );
        stdout.writeln(
          'PASS: ${era.name} real HTTP primitive services, capability negotiation, tool pagination/error, resources/templates and prompts',
        );
      } finally {
        await session.close();
      }
    }
  } finally {
    await peer.close(force: true);
  }
}
