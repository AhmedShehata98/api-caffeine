import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';

class _Session implements McpSession {
  final framesController = StreamController<RpcFrame>.broadcast();
  final networkController = StreamController<NetworkEntry>.broadcast();
  final consoleController = StreamController<ConsoleLine>.broadcast();
  @override
  Stream<RpcFrame> get frames => framesController.stream;
  @override
  Stream<NetworkEntry> get network => networkController.stream;
  @override
  Stream<ConsoleLine> get console => consoleController.stream;
  @override
  Future<Result<void>> close() async {
    await Future.wait([
      framesController.close(),
      networkController.close(),
      consoleController.close(),
    ]);
    return const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late _Session session;
  late McpSessionOwner owner;
  late ProviderContainer container;
  setUp(() async {
    session = _Session();
    owner = McpSessionOwner(createDiagnostics: McpSessionDiagnostics.new);
    await owner.switchScope('u', 'w');
    owner.trackOpening(owner.context!, 's', session);
    container = ProviderContainer.test(
      overrides: [mcpSessionOwnerProvider.overrideWithValue(owner)],
    );
    container.listen(mcpMonitorActionsProvider('s'), (_, _) {});
    container.listen(mcpCurrentDiagnosticsProvider('s'), (_, _) {});
    await container.pump();
  });
  tearDown(() => owner.dispose());
  RpcFrame frame(String text) => RpcFrame(
    direction: RpcDirection.outgoing,
    timestamp: DateTime.utc(2026),
    kind: RpcFrameKind.request,
    method: 'tools/call',
    id: 1,
    rawJson: text,
    size: text.length,
  );
  Future<void> publish() async {
    await owner.state.diagnostics['s']!.changes.first;
    await container.pump();
  }

  test(
    'copy reads full sanitized text and loadFull parses beyond the preview',
    () async {
      final text = '{"safe":"${'x' * (300 * 1024)}[REDACTED]"}';
      session.framesController.add(frame(text));
      await publish();
      final entry = container
          .read(mcpCurrentDiagnosticsProvider('s'))!
          .protocol
          .single;
      expect(entry.truncated, isTrue);
      final actions = container.read(mcpMonitorActionsProvider('s'));
      expect(
        actions.copy(McpMonitorKind.protocol, entry.sequence).valueOrNull,
        text,
      );
      expect(
        (await actions.loadFull(McpMonitorKind.protocol, entry)).valueOrNull,
        contains('[REDACTED]'),
      );
    },
  );
  test('clear affects one buffer and invalidates pending full loads', () async {
    session.framesController.add(frame('{"ok":true}'));
    session.consoleController.add(
      ConsoleLine(timestamp: DateTime.utc(2026), text: 'stderr'),
    );
    await publish();
    final snapshot = container.read(mcpCurrentDiagnosticsProvider('s'))!;
    final actions = container.read(mcpMonitorActionsProvider('s'));
    final loading = actions.loadFull(
      McpMonitorKind.protocol,
      snapshot.protocol.single,
    );
    actions.clear(McpMonitorKind.protocol);
    expect((await loading).isSuccess, isFalse);
    expect(owner.state.diagnostics['s']!.console.entries.length, 1);
    expect(
      actions
          .copy(McpMonitorKind.protocol, snapshot.protocol.single.sequence)
          .isSuccess,
      isFalse,
    );
  });
  test(
    'scope cleanup replaces snapshots and rejects captured actions',
    () async {
      session.framesController.add(frame('{"private":"payload"}'));
      await publish();
      final actions = container.read(mcpMonitorActionsProvider('s'));
      await owner.switchScope(null, null);
      await container.pump();
      expect(container.read(mcpCurrentDiagnosticsProvider('s')), isNull);
      expect(actions.copy(McpMonitorKind.protocol, 0).isSuccess, isFalse);
    },
  );
  test('paused diagnostic listeners do not delay cleanup', () async {
    final listener = owner.state.diagnostics['s']!.changes.listen((_) {})
      ..pause();
    await owner.switchScope(null, null).timeout(const Duration(seconds: 1));
    await listener.cancel();
  });
}
