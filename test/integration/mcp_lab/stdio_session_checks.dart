import 'dart:async';
import 'dart:io';

import 'package:test_point/modules/mcp_lab/mcp_lab_protocol.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_stdio_connection_repository.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_stdio_launcher.dart';

Future<void> main() => runChecks();

Future<void> runChecks({String? dart}) async {
  void check(bool value, String message) {
    if (!value) throw StateError(message);
  }

  const context = McpAccessContext(
    userId: 'user',
    workspaceId: 'workspace',
    generation: 1,
  );
  const secret = 'stdio-canary+private';
  final launcher = McpStdioLauncher();
  var authorized = true;
  final repository = McpStdioConnectionRepository(
    launcher,
    isAuthorized: (_, _) => authorized,
    clientVersion: '1.0.0-test',
  );
  final fixture = File('test/fixtures/mcp/stdio_peer.dart').absolute.path;
  Future<McpSession> connect(String mode, {bool modern = false}) async {
    final snapshot = (await launcher.resolve(
      command: dart ?? Platform.resolvedExecutable,
      args: [
        mode == 'sdk'
            ? File('test/fixtures/mcp/fixture_server.dart').absolute.path
            : fixture,
        '--fixture=$mode',
        'with spaces',
        '&',
        '^',
        'quote"value',
        '--help',
      ],
      environment: {'MCP_TEST_SECRET': secret, 'FOO': 'bar'},
      inheritedEnvironment: {
        ...Platform.environment,
        'UNRELATED_PRIVATE_KEY': 'parent-canary',
      },
    )).valueOrNull;
    check(snapshot != null, 'Fixture executable resolution failed');
    final server = McpServer(
      id: mode,
      workspaceId: context.workspaceId,
      draft: McpServerDraft(
        name: mode,
        transport: McpTransport.stdio,
        command: snapshot!.command,
        env: {'MCP_TEST_SECRET': secret},
        secretKeys: ['env.MCP_TEST_SECRET'],
      ),
      secretStates: {'env.MCP_TEST_SECRET': SecretValueState.present},
    );
    final opened = await repository.connect(
      McpConnectTarget(
        context: context,
        server: server,
        launch: snapshot,
        timeout: const Duration(seconds: 5),
      ),
    );
    check(
      opened.isSuccess,
      'Fixture launch failed: ${opened.failureOrNull?.message}',
    );
    return opened.valueOrNull!;
  }

  Future<void> negotiate(McpSession session, {bool modern = false}) async {
    final result = await session.request(
      modern ? 'server/discover' : 'initialize',
      modern
          ? {}
          : {
              'protocolVersion': '2025-11-25',
              'capabilities': {},
              'clientInfo': {'name': 'API Caffeine', 'version': '1'},
            },
    );
    check(result.isSuccess, 'Fixture negotiation failed');
    check(
      session
          .configureProtocol(
            era: modern ? NegotiatedEra.modern : NegotiatedEra.legacy,
            version: modern ? '2026-07-28' : '2025-11-25',
          )
          .isSuccess,
      'Protocol configuration failed',
    );
    if (!modern) {
      check(
        (await session.notify('notifications/initialized', {})).isSuccess,
        'Initialized notification failed',
      );
    }
  }

  final session = await connect('noisy');
  final frames = <RpcFrame>[];
  final console = <ConsoleLine>[];
  final frameSubscription = session.frames.listen(frames.add);
  final consoleSubscription = session.console.listen(console.add);
  try {
    check(
      !(await session.request('tools/call', {})).isSuccess,
      'Ordinary calls accepted before negotiation',
    );
    await negotiate(session);
    final result = await session.request('tools/call', {
      'name': 'echo',
      'arguments': {},
    }, id: 777);
    check(
      result.isSuccess && result.valueOrNull!['content'][0]['text'] == secret,
      'Operation result mutated',
    );
    final value = result.valueOrNull!;
    check(
      value['foo'] == 'bar' && value['parentLeaked'] == false,
      'Child environment isolation failed',
    );
    check(
      (value['args'] as List).contains('quote"value') &&
          (value['args'] as List).contains('&'),
      'Native argument fidelity failed',
    );
    final follow = await session.request('tools/call', {
      'name': 'ask',
      'arguments': {},
    });
    check(
      follow.valueOrNull?['clientErrorCode'] == -32601,
      'Unsupported server request was not rejected',
    );
    check(
      frames.any((frame) => frame.kind == RpcFrameKind.warning),
      'Noisy output did not emit warnings',
    );
    check(
      frames.any(
        (frame) =>
            frame.id == 777 && frame.rawJson.contains('x-wire-extension'),
      ),
      'Raw extension/ID lost',
    );
    check(
      !frames.map((frame) => frame.rawJson).join().contains(secret),
      'Secret leaked into protocol frames',
    );
    // Console callbacks are ordered by the process stream; wait for the marker, not a fixed delay.
    if (console.isEmpty) {
      await session.console.first.timeout(const Duration(seconds: 3));
    }
    check(
      !console.map((line) => line.text).join().contains(secret),
      'Secret leaked into stderr',
    );
    check(
      !(await session.request('tools/call', {}, id: 777)).isSuccess,
      'Reused ID accepted',
    );
    final timedOut = await session.request('tools/call', {
      'name': 'never',
    }, timeout: const Duration(milliseconds: 50));
    check(
      timedOut.failureOrNull is McpNetworkFailure,
      'Timeout did not complete request',
    );
  } finally {
    check((await session.close()).isSuccess, 'Native session cleanup failed');
    await frameSubscription.cancel();
    await consoleSubscription.cancel();
  }
  stdout.writeln(
    'PASS: live legacy stdio, native argv/env, raw diagnostics, server-request rejection and timeout',
  );

  final modern = await connect('basic');
  try {
    await negotiate(modern, modern: true);
    final result = (await modern.request('tools/call', {
      'name': 'needs-input',
    })).valueOrNull!;
    check(
      result['resultType'] == 'input_required',
      'Intermediate result consumed',
    );
    check(
      (result['methods'] as List).length == 2,
      'Automatic MRTR/retry detected',
    );
    check(
      result['observedMeta']['io.modelcontextprotocol/protocolVersion'] ==
          '2026-07-28',
      'Modern metadata absent',
    );
    check(
      result['observedMeta']['io.modelcontextprotocol/clientInfo']['name'] ==
          'API Caffeine',
      'Client metadata absent',
    );
  } finally {
    await modern.close();
  }
  stdout.writeln(
    'PASS: live modern stdio and caller-controlled intermediate result',
  );

  final crashing = await connect('crash');
  try {
    await negotiate(crashing);
    final result = await crashing.request('tools/call', {'name': 'echo'});
    final failure = result.failureOrNull;
    check(
      failure is McpUnexpectedFailure &&
          failure.exitCode == 7 &&
          !(failure.stderrTail ?? '').contains(secret),
      'Process exit metadata/redaction failed',
    );
  } finally {
    await crashing.close();
  }
  stdout.writeln(
    'PASS: unexpected process exit fails pending request with sanitized metadata',
  );

  final hanging = await connect('hang');
  await negotiate(hanging);
  final pending = hanging.request('tools/call', {'name': 'never'});
  final stopwatch = Stopwatch()..start();
  final close = await hanging.close();
  check(
    close.isSuccess && stopwatch.elapsed < const Duration(seconds: 5),
    'Stubborn process shutdown exceeded bound',
  );
  check((await pending).failureOrNull != null, 'Close left a request pending');
  check((await hanging.close()).isSuccess, 'Close was not idempotent');
  stdout.writeln(
    'PASS: pending-request cancellation and bounded stubborn-process shutdown',
  );

  final startup = await connect('startup');
  try {
    await negotiate(startup);
    final warning = await startup.frames.firstWhere(
      (frame) => frame.kind == RpcFrameKind.warning,
    );
    final console = await startup.console.first;
    check(
      warning.rawJson.contains('[REDACTED]') &&
          !warning.rawJson.contains(secret),
      'Startup frame capture/redaction failed',
    );
    check(
      console.text.contains('[REDACTED]') && !console.text.contains(secret),
      'Startup stderr capture/redaction failed',
    );
  } finally {
    await startup.close();
  }
  stdout.writeln(
    'PASS: bounded startup diagnostics survive late listener attachment',
  );

  final sdk = await connect('sdk');
  try {
    await negotiate(sdk);
    final result = await sdk.request('tools/call', {
      'name': 'echo',
      'arguments': {'text': secret},
    });
    check(
      result.valueOrNull?['content'][0]['text'] == secret,
      'SDK peer interoperability failed',
    );
    check(
      await sdk.status.first is ConnectionConnected,
      'Current connection status was not replayed',
    );
  } finally {
    await sdk.close();
  }
  stdout.writeln(
    'PASS: SDK server interoperability and replayed connection status',
  );

  final stale = await connect('basic');
  await negotiate(stale);
  authorized = false;
  check(
    (await stale.request('tools/call', {'name': 'echo'})).failureOrNull
        is McpAuthFailure,
    'Stale account request did not fail closed',
  );
  await stale.close();
  stdout.writeln(
    'PASS: account-generation authorization prevents stale session operations',
  );
}

