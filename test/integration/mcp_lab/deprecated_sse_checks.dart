import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:api_caffeine/core/error/result.dart';

import 'package:api_caffeine/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:api_caffeine/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';
import 'package:api_caffeine/modules/mcp_lab/services/mcp_resource_preview.dart';

import '../../fixtures/mcp/deprecated_sse_peer.dart';
import '../../fixtures/mcp/binary_payload.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  Future<Result<McpSession>> connect(
    DeprecatedSsePeer peer, {
    Duration timeout = const Duration(seconds: 2),
  }) =>
      McpHttpConnectionRepository(
        isAuthorized: (_, _) => true,
        clientVersion: 'test',
      ).connect(
        McpConnectTarget(
          context: const McpAccessContext(
            userId: 'u',
            workspaceId: 'w',
            generation: 1,
          ),
          server: McpServer(
            id: 'old',
            workspaceId: 'w',
            draft: McpServerDraft(
              name: 'Old',
              transport: McpTransport.sse,
              url: peer.url.toString(),
              headers: {'authorization': 'Bearer ${DeprecatedSsePeer.secret}'},
              secretKeys: ['header.authorization'],
            ),
            secretStates: {'header.authorization': SecretValueState.present},
          ),
          timeout: timeout,
        ),
      );
  const negotiation = McpNegotiationService(clientVersion: 'test');
  final peer = await DeprecatedSsePeer.start();
  final session = (await connect(peer)).valueOrNull as McpSession;
  final frames = <RpcFrame>[];
  final network = <NetworkEntry>[];
  final protocol = session.frames.listen(frames.add);
  final capture = session.network.listen(network.add);
  try {
    check(
      (await negotiation.negotiate(session)).isSuccess,
      'Old transport negotiation failed',
    );
    final results = await Future.wait([
      session.request('tools/call', {'name': 'first'}, id: 7),
      session.request('tools/call', {'name': 'second'}, id: '7'),
    ]);
    check(
      results[0].valueOrNull?['id'] == 7 &&
          results[1].valueOrNull?['id'] == '7',
      'Concurrent old-stream ID correlation failed',
    );
    check(
      results.every(
        (result) => result.valueOrNull?['text'] == DeprecatedSsePeer.secret,
      ),
      'Operation result credentials were changed',
    );
    check(
      peer.gets == 1 &&
          peer.urls.every(
            (url) =>
                url.path == '/messages' &&
                url.queryParameters['sessionId'] == DeprecatedSsePeer.token,
          ),
      'Old transport posted to the wrong endpoint or reconnected',
    );
    check(
      peer.headers.every(
        (header) =>
            header['authorization'] == 'Bearer ${DeprecatedSsePeer.secret}',
      ),
      'Configured credentials were not forwarded to the approved same-origin endpoint',
    );
    await peer.send({
      'jsonrpc': '2.0',
      'id': 'ask',
      'method': 'sampling/createMessage',
      'params': {},
    });
    check(
      await peer.reply.future.timeout(const Duration(seconds: 2)) == -32601,
      'Old-stream server request was not rejected',
    );
    peer.answerCalls = false;
    check(
      !(await session.request('tools/call', {
        'name': 'timeout',
      }, timeout: const Duration(milliseconds: 50))).isSuccess,
      'Request deadline was ignored',
    );
    peer.answerCalls = true;
    check(
      (await session.request('tools/call', {
        'name': 'after-timeout',
      })).isSuccess,
      'A call timeout closed the shared stream',
    );
    final diagnostics = jsonEncode({
      'frames': frames.map((frame) => frame.toJson()).toList(),
      'network': network.map((entry) => entry.toJson()).toList(),
    });
    check(
      !diagnostics.contains(DeprecatedSsePeer.secret) &&
          !diagnostics.contains(DeprecatedSsePeer.token),
      'Old transport diagnostics leaked header/endpoint credentials',
    );
    peer.answerCalls = false;
    final posted = peer.posted.stream.firstWhere(
      (message) => message['method'] == 'tools/call',
    );
    final pending = session.request('tools/call', {'name': 'cut'});
    await posted;
    await peer.endStream();
    check(
      !(await pending).isSuccess &&
          !(await session.request('tools/call', {})).isSuccess,
      'Stream loss left pending calls or a disconnected session usable',
    );
    check(peer.gets == 1, 'Old stream loss automatically reconnected');
  } finally {
    await session.close();
    await protocol.cancel();
    await capture.cancel();
    check(peer.deletes == 0, 'Old transport sent Streamable HTTP DELETE');
    await peer.close();
  }
  stdout.writeln(
    'PASS: deprecated HTTP+SSE negotiation, endpoint routing, concurrent IDs, redaction, deadlines, server requests and EOF',
  );

  for (final endpoint in [
    'http://127.0.0.1:1/messages',
    '//untrusted.invalid/post',
    '/messages#fragment',
    'http://@127.0.0.1/messages',
  ]) {
    final unsafe = await DeprecatedSsePeer.start()
      ..endpointOverride = endpoint;
    try {
      check(
        !(await connect(unsafe)).isSuccess && unsafe.messages.isEmpty,
        'Unsafe endpoint received a POST',
      );
    } finally {
      await unsafe.close();
    }
  }
  stdout.writeln(
    'PASS: cross-origin, user-info and fragment endpoints fail before credential-bearing POSTs',
  );

  final silent = await DeprecatedSsePeer.start()
    ..announce = false;
  try {
    final watch = Stopwatch()..start();
    check(
      !(await connect(
        silent,
        timeout: const Duration(milliseconds: 80),
      )).isSuccess,
      'An unannounced endpoint connected',
    );
    check(
      watch.elapsedMilliseconds < 1500 && silent.messages.isEmpty,
      'Endpoint negotiation was unbounded or posted before announcement',
    );
  } finally {
    await silent.close();
  }
  stdout.writeln('PASS: endpoint announcement has a bounded deadline');

  final large = await DeprecatedSsePeer.start();
  final largeSession = (await connect(
    large,
    timeout: const Duration(seconds: 30),
  )).valueOrNull!;
  try {
    check(
      (await negotiation.negotiate(largeSession)).isSuccess,
      'Large-result negotiation failed',
    );
    final result = await largeSession.request('tools/call', {
      'name': 'binary-20-mib',
    });
    check(result.isSuccess, 'Old SSE rejected a 20 MiB binary result');
    final block =
        ToolCallResult.fromJson(result.valueOrNull!).content.single
            as EmbeddedResourceBlock;
    final preview = await prepareMcpResourcePreview(block.resource);
    check(
      preview.byteLength == fixtureBinarySize &&
          preview.imageBytes == null &&
          preview.text == null,
      'Large binary result was lost or rendered inline',
    );
  } finally {
    await largeSession.close();
    await large.close();
  }
  stdout.writeln(
    'PASS: deprecated SSE receives a 20 MiB binary result with metadata-only preview',
  );
}
