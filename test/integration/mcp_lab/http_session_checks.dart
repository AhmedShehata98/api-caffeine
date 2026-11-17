import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test_point/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_stdio_launcher.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_target_repository_impl.dart';
import 'package:test_point/modules/mcp_lab/services/mcp_diagnostic_buffer.dart';

import '../../fixtures/mcp/http_peer.dart';

Future<void> main() async {
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  const context = McpAccessContext(
    userId: 'user',
    workspaceId: 'workspace',
    generation: 1,
  );
  var authorized = true;
  final repository = McpHttpConnectionRepository(
    isAuthorized: (_, _) => authorized,
    clientVersion: '1.0.0-test',
  );
  Future<McpSession> connect(McpHttpPeer peer, {bool modern = false}) async {
    final server = McpServer(
      id: 'http',
      workspaceId: context.workspaceId,
      draft: McpServerDraft(
        name: 'HTTP',
        transport: McpTransport.http,
        url: peer.url.toString(),
        headers: {
          'authorization': 'Bearer ${McpHttpPeer.secret}',
          'x-team': 'qa',
          'last-event-id': 'must-not-send',
        },
        secretKeys: ['header.authorization'],
      ),
      secretStates: {'header.authorization': SecretValueState.present},
    );
    final target =
        await McpTargetRepositoryImpl(
          McpStdioLauncher(),
          isAuthorized: (_, _) => authorized,
        ).resolve(
          context,
          server,
          const McpTargetSettings(timeout: Duration(seconds: 5)),
        );
    check(target.isSuccess, 'HTTP target resolution failed');
    final session = (await repository.connect(target.valueOrNull!))
        .valueOrNull!;
    final result =
        await const McpNegotiationService(clientVersion: '1.0.0-test')
            .negotiate(
              session,
              era: modern ? McpProtocolEra.modern : McpProtocolEra.legacy,
            );
    check(
      result.isSuccess,
      'HTTP negotiation failed: ${result.failureOrNull?.message}',
    );
    return session;
  }

  final peer = await McpHttpPeer.start();
  final legacy = await connect(peer);
  final frames = <RpcFrame>[];
  final network = <NetworkEntry>[];
  final frameSubscription = legacy.frames.listen(frames.add);
  final networkSubscription = legacy.network.listen(network.add);
  try {
    final result = await legacy.request('tools/call', {
      'name': 'echo',
      'arguments': {},
    }, id: 777);
    check(
      result.valueOrNull?['content'][0]['text'] == McpHttpPeer.secret,
      'Raw HTTP operation result was mutated',
    );
    check(
      peer.headers.last['mcp-session-id'] == 'fixture-session',
      'Session header missing',
    );
    check(
      peer.headers.last['mcp-protocol-version'] == '2025-11-25' &&
          peer.headers.last['x-team'] == 'qa',
      'Version/custom headers missing',
    );
    check(
      frames.any(
        (frame) =>
            frame.id == 777 && frame.rawJson.contains('x-wire-extension'),
      ),
      'HTTP ID/extension lost',
    );
    final diagnostics =
        '${frames.map((frame) => frame.rawJson).join()}${jsonEncode(network.map((entry) => entry.toJson()).toList())}';
    check(
      !diagnostics.contains(McpHttpPeer.secret) &&
          !diagnostics.contains('response-canary'),
      'HTTP diagnostic credentials leaked',
    );
    check(
      !(await legacy.request('tools/call', {}, id: 777)).isSuccess,
      'Reused HTTP ID accepted',
    );
    peer.sse = true;
    final streamed = await legacy.request('tools/call', {'name': 'echo'});
    check(
      streamed.valueOrNull?['label'] == '雪',
      'Fragmented SSE/multiline JSON failed',
    );
    final ask = await legacy.request('tools/call', {'name': 'ask'});
    check(
      ask.valueOrNull?['clientErrorCode'] == -32601,
      'Unsupported HTTP server request not rejected: ${ask.failureOrNull?.message}; '
      'methods=${peer.bodies.map((body) => body["method"] ?? "client-response").toList()}; '
      'frameKinds=${frames.map((frame) => "${frame.kind.name}:${frame.method}").toList()}',
    );
    check(
      (await legacy.close()).isSuccess && peer.deletes == 1,
      'DELETE 405 cleanup failed',
    );
  } finally {
    await legacy.close();
    await frameSubscription.cancel();
    await networkSubscription.cancel();
    await peer.close();
  }
  stdout.writeln(
    'PASS: legacy JSON/SSE, session/custom headers, raw frames, redaction, client-method rejection and DELETE 405',
  );

  final modernPeer = await McpHttpPeer.start();
  final modern = await connect(modernPeer, modern: true);
  try {
    modernPeer.sse = true;
    final result = await modern.request('tools/call', {'name': 'needs-input'});
    check(
      result.valueOrNull?['resultType'] == 'input_required',
      'HTTP intermediate result consumed',
    );
    check(modernPeer.bodies.length == 2, 'Automatic HTTP MRTR/retry detected');
    check(
      modernPeer.headers.last['mcp-method'] == 'tools/call' &&
          modernPeer.headers.last['mcp-name'] == 'needs-input',
      'Modern routing headers missing',
    );
    check(
      !modernPeer.headers.last.containsKey('mcp-session-id') &&
          !modernPeer.headers.last.containsKey('last-event-id'),
      'Modern stateful headers leaked',
    );
    modernPeer.cutStream = true;
    final lost = await modern.request('tools/call', {'name': 'echo'});
    check(
      lost.failureOrNull!.message.contains('Stream lost'),
      'Cut modern stream did not fail',
    );
    check(
      modernPeer.gets == 0 && modernPeer.bodies.length == 3,
      'Modern stream auto-resumed/replayed',
    );
    modernPeer.cutStream = false;
    check(
      (await modern.request('tools/call', {'name': 'echo'})).isSuccess,
      'Explicit new-ID retry failed',
    );
    modernPeer.nextStatus = 429;
    final limited =
        (await modern.request('tools/call', {'name': 'echo'})).failureOrNull
            as McpNetworkFailure;
    check(
      limited.code == McpErrorCode.rateLimited &&
          limited.retryAfter == const Duration(seconds: 2),
      'HTTP Retry-After lost',
    );
  } finally {
    await modern.close();
    check(modernPeer.deletes == 0, 'Modern session sent DELETE');
    await modernPeer.close();
  }
  stdout.writeln(
    'PASS: modern routing/meta, intermediate results, no stream replay, explicit retry and rate limits',
  );

  final expiredPeer = await McpHttpPeer.start();
  final expired = await connect(expiredPeer);
  try {
    expiredPeer.holdCalls = true;
    final held = expired.request('tools/call', {'name': 'held'});
    await expiredPeer.heldArrived.future.timeout(const Duration(seconds: 3));
    expiredPeer.expired = true;
    final before = expiredPeer.bodies.length;
    final result = await expired.request('tools/call', {'name': 'expire'});
    check(
      result.failureOrNull!.message.contains('expired'),
      '404 did not expire session',
    );
    check(
      (await held).failureOrNull != null,
      'Expiry left another call pending',
    );
    check(
      !(await expired.request('tools/call', {'name': 'again'})).isSuccess,
      'Expired session remained usable',
    );
    await expired.close();
    check(
      expiredPeer.bodies.length == before + 1 && expiredPeer.deletes == 0,
      'Expired call replayed or stale DELETE sent',
    );
  } finally {
    await expired.close();
    await expiredPeer.close();
  }
  stdout.writeln(
    'PASS: 404 invalidates session, cancels concurrent requests and requires explicit reconnect',
  );

  final cleanupPeer = await McpHttpPeer.start();
  final cleanup = await connect(cleanupPeer);
  try {
    cleanupPeer.holdCalls = true;
    final pending = cleanup.request('tools/call', {'name': 'held'});
    await cleanupPeer.heldArrived.future.timeout(const Duration(seconds: 3));
    cleanupPeer.holdDelete = true;
    final watch = Stopwatch()..start();
    check(
      !(await cleanup.close()).isSuccess,
      'Hanging DELETE cleanup failure was hidden',
    );
    check(
      watch.elapsed < const Duration(seconds: 5),
      'HTTP close exceeded bound',
    );
    check(
      (await pending).failureOrNull != null,
      'Close left HTTP request pending',
    );
    check(
      !(await cleanup.request('tools/call', {})).isSuccess,
      'Closed HTTP session remained usable',
    );
  } finally {
    await cleanup.close();
    await cleanupPeer.close();
  }
  stdout.writeln(
    'PASS: hanging DELETE is bounded, visible and does not prevent local cancellation',
  );

  final stalePeer = await McpHttpPeer.start();
  final stale = await connect(stalePeer);
  authorized = false;
  try {
    check(
      (await stale.request('tools/call', {})).failureOrNull is McpAuthFailure,
      'Stale HTTP account remained active',
    );
  } finally {
    await stale.close();
    await stalePeer.close();
  }
  stdout.writeln('PASS: stale account blocks HTTP operations');
  authorized = true;
  for (final sse in [false, true]) {
    final largePeer = await McpHttpPeer.start()
      ..sse = sse
      ..largeText = '${'é' * (170 * 1024)}${McpHttpPeer.secret}tail-marker';
    final session = await connect(largePeer);
    final buffer = McpDiagnosticBuffer();
    try {
      final captured = session.network
          .firstWhere((entry) => entry.body?.contains('tail-marker') ?? false)
          .timeout(const Duration(seconds: 5));
      final response = await session.request('tools/call', {'name': 'large'});
      check(
        response.valueOrNull!['largeText'] == largePeer.largeText,
        'Operation result was changed by diagnostics',
      );
      final entry = await captured;
      check(
        !entry.truncated && !(entry.body ?? '').contains(McpHttpPeer.secret),
        'Full network capture was partial or unredacted',
      );
      buffer.addNetwork(entry);
      check(
        buffer.entries.single.truncated && buffer.entries.single.fullAvailable,
        'Preview/full-body state mismatch',
      );
      final loaded = (await buffer.loadFullJson(0)).valueOrNull;
      final payload = sse ? (loaded as List).single as Map : loaded as Map;
      check(
        (payload['result']['largeText'] as String).endsWith(
          '[REDACTED]tail-marker',
        ),
        'Load full lost the sanitized tail',
      );
      buffer.clear();
      check(
        !buffer.copyText(0).isSuccess,
        'Clear retained full diagnostic body',
      );
    } finally {
      buffer.dispose();
      await session.close();
      await largePeer.close();
    }
  }
  stdout.writeln(
    'PASS: large JSON/SSE diagnostics retain sanitized full bodies, preview truncation, isolate loading and clear',
  );
}
