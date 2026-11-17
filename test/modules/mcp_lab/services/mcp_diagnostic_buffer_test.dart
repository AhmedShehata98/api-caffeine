import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_diagnostic_sanitizer.dart';

class _Session extends Mock implements McpSession {}

RpcFrame frame({
  Object? id = 1,
  RpcDirection direction = RpcDirection.outgoing,
  RpcFrameKind kind = RpcFrameKind.request,
  String text = '{}',
  int millis = 0,
}) => RpcFrame(
  direction: direction,
  timestamp: DateTime.utc(2026).add(Duration(milliseconds: millis)),
  kind: kind,
  id: id,
  rawJson: text,
  size: utf8.encode(text).length,
);

void main() {
  test('pairs opposite directions and preserves string versus integer IDs', () {
    final buffer = McpDiagnosticBuffer();
    buffer.addFrame(frame());
    buffer.addFrame(frame(id: '1', direction: RpcDirection.incoming));
    buffer.addFrame(
      frame(
        kind: RpcFrameKind.response,
        direction: RpcDirection.incoming,
        millis: 12,
      ),
    );
    expect(buffer.entries[0].pairedSequence, 2);
    expect(buffer.entries[2].pairedSequence, 0);
    expect(buffer.entries[2].duration, const Duration(milliseconds: 12));
    expect(buffer.entries[1].pairedSequence, isNull);
    buffer.addFrame(frame(id: '1', kind: RpcFrameKind.response));
    expect(buffer.entries[1].pairedSequence, 3);
  });

  test('10,000 entry ring evicts oldest full bodies and tracks drops', () {
    final buffer = McpDiagnosticBuffer();
    for (var i = 0; i < 10002; i++) {
      buffer.addFrame(frame(id: i));
    }
    expect(buffer.entries.length, 10000);
    expect(buffer.entries.first.sequence, 2);
    expect(buffer.dropped, 2);
    expect(buffer.copyText(0).isSuccess, isFalse);
  });

  test(
    'body budget evicts full text and pairing does not retain evicted entries',
    () {
      final buffer = McpDiagnosticBuffer(capacity: 2, bodyBudgetBytes: 8);
      buffer.addFrame(frame(text: '1234'));
      buffer.addFrame(
        frame(
          text: '1234',
          kind: RpcFrameKind.response,
          direction: RpcDirection.incoming,
        ),
      );
      buffer.addFrame(frame(id: 3, text: '1234'));
      expect(buffer.entries.first.pairedSequence, isNull);
      expect(buffer.retainedBodyBytes, 8);
      buffer.addFrame(frame(text: 'too-large-for-the-budget'));
      expect(buffer.dropped, 2);
    },
  );

  test('preview truncates UTF-8 safely; copy and isolate parse use sanitized full text', () async {
    final sanitizer = McpDiagnosticSanitizer(secretValues: ['canary']);
    final safe = sanitizer.frame(jsonEncode({'text': 'é😀canary'}));
    final buffer = McpDiagnosticBuffer(previewBytes: 12);
    buffer.addFrame(frame(text: safe.text).copyWith(redacted: safe.redacted));
    expect(buffer.entries.single.truncated, isTrue);
    expect(
      utf8.encode(buffer.entries.single.text).length,
      lessThanOrEqualTo(12),
    );
    expect(buffer.entries.single.text, isNot(contains('�')));
    expect(buffer.entries.single.frame!.redacted, isTrue);
    expect(buffer.copyText(0).valueOrNull, isNot(contains('canary')));
    expect((await buffer.loadFullJson(0)).valueOrNull, {
      'text': 'é😀[REDACTED]',
    });
    sanitizer.dispose();
  });

  test(
    'clear invalidates full loads in progress and resets counters',
    () async {
      final buffer = McpDiagnosticBuffer(capacity: 1);
      buffer.addFrame(frame());
      buffer.addFrame(frame());
      final pending = buffer.loadFullJson(1);
      buffer.clear();
      expect((await pending).isSuccess, isFalse);
      expect(buffer.dropped, 0);
      expect(buffer.retainedBodyBytes, 0);
    },
  );

  test('partial transport bodies cannot masquerade as complete JSON', () async {
    final buffer = McpDiagnosticBuffer();
    buffer.addNetwork(
      const NetworkEntry(
        method: 'POST',
        url: 'https://example.test',
        body: '{}',
        truncated: true,
        duration: Duration.zero,
      ),
    );
    expect(buffer.entries.single.truncated, isTrue);
    expect(buffer.entries.single.fullAvailable, isFalse);
    expect((await buffer.loadFullJson(0)).isSuccess, isFalse);
  });

  test(
    'malformed bodies fail explicitly; disposal releases cached text',
    () async {
      final buffer = McpDiagnosticBuffer();
      buffer.addConsole(
        ConsoleLine(timestamp: DateTime.utc(2026), text: 'not JSON'),
      );
      expect((await buffer.loadFullJson(0)).isSuccess, isFalse);
      buffer.dispose();
      buffer.addFrame(frame());
      expect(buffer.entries, isEmpty);
      expect(buffer.copyText(0).isSuccess, isFalse);
    },
  );

  test('provider captures opening handshake and scope change releases all monitors', () async {
    final session = _Session();
    final frames = StreamController<RpcFrame>();
    final network = StreamController<NetworkEntry>();
    final console = StreamController<ConsoleLine>();
    when(() => session.frames).thenAnswer((_) => frames.stream);
    when(() => session.network).thenAnswer((_) => network.stream);
    when(() => session.console).thenAnswer((_) => console.stream);
    when(() => session.close()).thenAnswer((_) async {
      await frames.close();
      await network.close();
      await console.close();
      return const Result.success(null);
    });
    final owner = McpSessionOwner(createDiagnostics: McpSessionDiagnostics.new);
    await owner.switchScope('u', 'w');
    final container = ProviderContainer(
      overrides: [mcpSessionOwnerProvider.overrideWithValue(owner)],
    );
    container.listen(mcpDiagnosticsProvider('s'), (_, _) {});
    owner.trackOpening(owner.context!, 's', session);
    frames.add(frame(text: '{"method":"initialize"}'));
    console.add(ConsoleLine(timestamp: DateTime.utc(2026), text: '[REDACTED]'));
    network.addError(StateError('secret-canary'));
    final monitor = owner.state.diagnostics['s']!;
    await monitor.changes.first;
    await container.pump();
    expect(monitor.protocol.entries.single.text, contains('initialize'));
    expect(monitor.console.entries.single.text, '[REDACTED]');
    expect(monitor.streamErrors, 1);
    final snapshot = await container.read(mcpDiagnosticsProvider('s').future);
    expect(snapshot!.protocol, hasLength(1));
    await owner.switchScope(null, null);
    await container.pump();
    expect(monitor.protocol.entries, isEmpty);
    expect(monitor.protocol.copyText(0).isSuccess, isFalse);
    expect(owner.state.diagnostics, isEmpty);
    container.dispose();
    await owner.dispose();
  });
}
