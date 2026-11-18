import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:test_point/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_http_connection_repository.dart';

import '../../fixtures/mcp/http_peer.dart';

void check(bool condition, String message) {
  if (!condition) throw StateError(message);
}

Future<void> main() async {
  Future<McpSession> connect(McpHttpPeer peer) async {
    final repository = McpHttpConnectionRepository(
      isAuthorized: (_, _) => true,
      clientVersion: 'test',
    );
    return (await repository.connect(
      McpConnectTarget(
        context: const McpAccessContext(
          userId: 'u',
          workspaceId: 'w',
          generation: 1,
        ),
        server: McpServer(
          id: 's',
          workspaceId: 'w',
          draft: McpServerDraft(
            name: 'notifications',
            transport: McpTransport.http,
            url: peer.url.toString(),
            headers: {
              'authorization': 'Bearer ${McpHttpPeer.secret}',
              'last-event-id': 'must-not-send',
            },
            secretKeys: ['header.authorization'],
          ),
          secretStates: {'header.authorization': SecretValueState.present},
        ),
        timeout: const Duration(seconds: 2),
      ),
    )).valueOrNull!;
  }

  const negotiation = McpNegotiationService(clientVersion: 'test');
  for (final deleteStatus in [405, 500]) {
    final peer = await McpHttpPeer.start()
      ..deleteStatus = deleteStatus;
    final session = await connect(peer);
    try {
      final captured = session.network.firstWhere(
        (entry) => entry.method == 'GET',
      );
      check(
        (await negotiation.negotiate(session)).isSuccess,
        'GET 405 blocked negotiation',
      );
      check(
        (await captured).status == 405 && peer.gets == 1,
        'Optional GET 405 not captured',
      );
      final headers = peer.notificationHeaders.single;
      check(
        headers['mcp-session-id'] == 'fixture-session' &&
            headers['mcp-protocol-version'] == '2025-11-25' &&
            headers['accept'] == 'text/event-stream' &&
            !headers.containsKey('last-event-id'),
        'Optional GET headers incorrect',
      );
      check(
        (await session.request('tools/call', {'name': 'test'})).isSuccess,
        'GET 405 disabled calls',
      );
      check(
        (await session.close()).isSuccess == (deleteStatus == 405),
        'DELETE failure was hidden',
      );
      check(peer.deletes == 1, 'DELETE cleanup missing');
    } finally {
      await session.close();
      await peer.close();
    }
  }
  stdout.writeln(
    'PASS: optional GET 405 tolerance, session headers and visible DELETE cleanup failures',
  );

  final peer = await McpHttpPeer.start()
    ..notificationStream = true;
  final session = await connect(peer);
  try {
    check(
      (await negotiation.negotiate(session)).isSuccess,
      'Notification stream negotiation failed',
    );
    final notification = session.frames.firstWhere(
      (frame) => frame.method == 'notifications/message',
    );
    final capture = session.network.firstWhere(
      (entry) => entry.method == 'GET',
    );
    await peer.sendNotification({
      'jsonrpc': '2.0',
      'method': 'notifications/message',
      'params': {'message': McpHttpPeer.secret},
    });
    final frame = await notification.timeout(const Duration(seconds: 2));
    check(
      frame.rawJson.contains('[REDACTED]') &&
          !frame.rawJson.contains(McpHttpPeer.secret),
      'Notification credentials leaked',
    );
    await peer.sendNotification({
      'jsonrpc': '2.0',
      'id': 'optional-ask',
      'method': 'sampling/createMessage',
      'params': {},
    });
    check(
      await peer.notificationReply.future.timeout(const Duration(seconds: 2)) ==
          -32601,
      'Unsupported server request was not rejected',
    );
    check(
      (await session.request('tools/call', {
            'name': 'parallel',
          })).valueOrNull?['content'][0]['text'] ==
          McpHttpPeer.secret,
      'Notification listener changed an ordinary result',
    );
    final warning = session.console.firstWhere(
      (line) => line.text.contains('stream ended'),
    );
    await peer.finishNotifications();
    await warning.timeout(const Duration(seconds: 2));
    check(
      !jsonEncode((await capture).toJson()).contains(McpHttpPeer.secret),
      'GET capture leaked credentials',
    );
    check(
      (await session.request('tools/call', {'name': 'after-eof'})).isSuccess,
      'Notification EOF disabled calls',
    );
  } finally {
    await session.close();
    await peer.close();
  }
  stdout.writeln(
    'PASS: live sanitized notifications, method-not-found replies, independent calls and visible EOF',
  );

  final idlePeer = await McpHttpPeer.start()
    ..notificationStream = true;
  final idleSession = await connect(idlePeer);
  try {
    check(
      (await negotiation.negotiate(idleSession)).isSuccess,
      'Idle GET did not connect',
    );
    final watch = Stopwatch()..start();
    check(
      (await idleSession.close()).isSuccess,
      'Idle listener prevented local close',
    );
    check(
      watch.elapsedMilliseconds < 3000 && idlePeer.deletes == 1,
      'Idle GET cleanup exceeded bound',
    );
  } finally {
    await idleSession.close();
    await idlePeer.close();
  }
  stdout.writeln(
    'PASS: an idle notification GET cancels during bounded session cleanup',
  );

  for (final status in [401, 403, 404]) {
    final rejectedPeer = await McpHttpPeer.start()
      ..notificationStream = true
      ..notificationStatus = status;
    final rejected = await connect(rejectedPeer);
    try {
      check(
        !(await negotiation.negotiate(rejected)).isSuccess,
        'Terminal GET $status was hidden',
      );
      check(
        !(await rejected.request('tools/call', {})).isSuccess,
        'Rejected session remained callable',
      );
    } finally {
      await rejected.close();
      await rejectedPeer.close();
    }
  }
  stdout.writeln(
    'PASS: optional GET auth rejection and expired sessions invalidate negotiation',
  );

  final modernPeer = await McpHttpPeer.start()
    ..notificationStream = true;
  final modern = await connect(modernPeer);
  try {
    check(
      (await negotiation.negotiate(
        modern,
        era: McpProtocolEra.modern,
      )).isSuccess,
      'Modern negotiation failed',
    );
    check(modernPeer.gets == 0, 'Modern session opened a legacy GET listener');
  } finally {
    await modern.close();
    await modernPeer.close();
  }
  stdout.writeln(
    'PASS: modern connections do not open the legacy optional notification stream',
  );
}
