import 'dart:convert';
import 'dart:io';

import 'package:test_point/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_stdio_launcher.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_target_repository_impl.dart';

import '../../fixtures/mcp/http_peer.dart';

/// Run directly with Dart; uses a real loopback peer and no native plugins.
Future<void> main() async {
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  const context = McpAccessContext(
    userId: 'user',
    workspaceId: 'workspace',
    generation: 1,
  );
  for (final era in [McpProtocolEra.legacy, McpProtocolEra.modern]) {
    for (final sse in [false, true]) {
      final peer = await McpHttpPeer.start();
      peer.completionSupport = true;
      peer.sse = sse;
      McpSession? session;
      final frames = <RpcFrame>[];
      final network = <NetworkEntry>[];
      try {
        final server = McpServer(
          id: 'completion',
          workspaceId: 'workspace',
          draft: McpServerDraft(
            name: 'Completion fixture',
            transport: McpTransport.http,
            url: peer.url.toString(),
            headers: {'authorization': 'Bearer ${McpHttpPeer.secret}'},
            secretKeys: ['header.authorization'],
          ),
          secretStates: {'header.authorization': SecretValueState.present},
        );
        final target =
            await McpTargetRepositoryImpl(
              McpStdioLauncher(),
              isAuthorized: (_, _) => true,
            ).resolve(
              context,
              server,
              const McpTargetSettings(timeout: Duration(seconds: 5)),
            );
        check(target.isSuccess, 'Target resolution failed');
        final opened = await McpHttpConnectionRepository(
          isAuthorized: (_, _) => true,
          clientVersion: '1.0.0-test',
          listenForLegacyNotifications: false,
        ).connect(target.valueOrNull!);
        check(opened.isSuccess, 'HTTP connection failed');
        session = opened.valueOrNull!;
        final frameSubscription = session.frames.listen(frames.add);
        final networkSubscription = session.network.listen(network.add);
        try {
          final negotiated = await const McpNegotiationService(
            clientVersion: '1.0.0-test',
          ).negotiate(session, era: era);
          check(negotiated.isSuccess, 'Negotiation failed');
          final services = McpPrimitiveServices(
            session,
            negotiated.valueOrNull!,
            isAuthorized: () => true,
          );
          check(services.supports('completions'), 'Completion capability lost');
          const source = 'weather://{city}{?country}';
          final inputs = {
            'city': const McpUriTemplateInput('Li'),
            'country': const McpUriTemplateInput('Portugal'),
          };
          final reply = await services.resources.completeTemplate(
            source,
            'city',
            inputs,
          );
          check(
            reply.isSuccess,
            'Completion failed: ${reply.failureOrNull?.message}',
          );
          check(
            jsonEncode(reply.valueOrNull!.values) ==
                jsonEncode(['Lisbon', '雪', McpHttpPeer.secret]),
            'Completion values changed',
          );
          check(
            reply.valueOrNull!.hasMore && reply.valueOrNull!.total == 5,
            'Completion metadata lost',
          );
          final request = peer.bodies.last;
          final params = request['params'] as Map;
          check(
            request['method'] == 'completion/complete' &&
                params['ref']['uri'] == source &&
                params['ref']['type'] == 'ref/resource',
            'Completion reference changed',
          );
          check(
            params['argument']['name'] == 'city' &&
                params['argument']['value'] == 'Li' &&
                params['context']['arguments']['country'] == 'Portugal',
            'Completion context changed',
          );
          if (era == McpProtocolEra.modern) {
            check(
              params['_meta']['io.modelcontextprotocol/protocolVersion'] ==
                      '2026-07-28' &&
                  peer.headers.last['mcp-method'] == 'completion/complete',
              'Modern metadata/routing missing',
            );
            check(
              !peer.headers.last.containsKey('mcp-session-id'),
              'Legacy session header leaked',
            );
          } else {
            check(
              peer.headers.last['mcp-session-id'] == 'fixture-session' &&
                  peer.headers.last['mcp-protocol-version'] == '2025-11-25',
              'Legacy session/version headers missing',
            );
          }
          // No read, automatic pagination, or implicit follow-up request.
          check(
            peer.bodies
                        .where(
                          (body) => body['method'] == 'completion/complete',
                        )
                        .length ==
                    1 &&
                !peer.bodies.any((body) => body['method'] == 'resources/read'),
            'Completion drove additional work',
          );
          await Future<void>.delayed(const Duration(milliseconds: 10));
          final diagnostics =
              '${frames.map((frame) => frame.rawJson).join()}${jsonEncode(network.map((entry) => entry.toJson()).toList())}';
          check(
            frames.any((frame) => frame.method == 'completion/complete'),
            'Completion transcript missing',
          );
          check(
            !diagnostics.contains(McpHttpPeer.secret),
            'Credential leaked in completion diagnostics',
          );
          peer.nextStatus = 429;
          final limited = await services.resources.completeTemplate(
            source,
            'city',
            inputs,
          );
          check(
            (limited.failureOrNull as McpCoded).code ==
                McpErrorCode.rateLimited,
            'Rate limit was not preserved',
          );
          check(
            peer.bodies
                    .where((body) => body['method'] == 'completion/complete')
                    .length ==
                2,
            'Completion retried automatically',
          );
        } finally {
          await frameSubscription.cancel();
          await networkSubscription.cancel();
        }
      } finally {
        await session?.close();
        await peer.close();
      }
      stdout.writeln(
        'PASS: ${era.name} completion over ${sse ? 'SSE' : 'JSON'}, context, metadata, redaction and rate limiting',
      );
    }
  }
}
