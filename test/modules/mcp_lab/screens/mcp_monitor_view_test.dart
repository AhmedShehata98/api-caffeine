import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/ui/theme/app_theme.dart';
import 'package:test_point/core/ui/widgets/code_view.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_diagnostic_sanitizer.dart';
import 'package:test_point/modules/mcp_lab/widgets/mcp_monitor_view.dart';

import '../../../support/load_bundled_test_fonts.dart';

class _Session implements McpSession {
  final frameEvents = StreamController<RpcFrame>.broadcast();
  final networkEvents = StreamController<NetworkEntry>.broadcast();
  final consoleEvents = StreamController<ConsoleLine>.broadcast();
  final sanitizer = McpDiagnosticSanitizer(secretValues: ['secret-canary']);
  int clock = 0;
  @override
  Stream<RpcFrame> get frames => frameEvents.stream;
  @override
  Stream<NetworkEntry> get network => networkEvents.stream;
  @override
  Stream<ConsoleLine> get console => consoleEvents.stream;
  @override
  Stream<ConnectionStatus> get status => Stream.value(
    const ConnectionStatus.connected(era: NegotiatedEra.modern, serverInfo: {}),
  );
  void frame(
    String wire, {
    RpcFrameKind kind = RpcFrameKind.request,
    RpcDirection direction = RpcDirection.outgoing,
  }) {
    final clean = sanitizer.frame(wire);
    final value = kind == RpcFrameKind.warning
        ? <String, dynamic>{}
        : jsonDecode(clean.text) as Map;
    frameEvents.add(
      RpcFrame(
        direction: direction,
        timestamp: DateTime.utc(2026).add(Duration(milliseconds: clock++ * 20)),
        kind: kind,
        id: value['id'],
        method: value['method'] as String?,
        rawJson: clean.text,
        size: clean.text.length,
        redacted: clean.redacted,
      ),
    );
  }

  @override
  Future<Result<void>> close() async {
    sanitizer.dispose();
    await Future.wait([
      frameEvents.close(),
      networkEvents.close(),
      consoleEvents.close(),
    ]);
    return const Result.success(null);
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(loadBundledTestFonts);
  late _Session session;
  late McpSessionOwner owner;
  String? copied;
  final boundary = GlobalKey();
  setUp(() async {
    session = _Session();
    owner = McpSessionOwner(createDiagnostics: McpSessionDiagnostics.new);
    await owner.switchScope('u', 'w');
    await owner.run('s', (context) async {
      owner.trackOpening(context, 's', session);
      return Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.modern,
            version: '2026-07-28',
            discovery: {'capabilities': {}},
          ),
        ),
      );
    });
    copied = null;
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, (call) async {
          if (call.method == 'Clipboard.setData') {
            copied = (call.arguments as Map)['text'] as String;
          }
          return null;
        });
  });
  tearDown(() async {
    await owner.dispose();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform, null);
  });
  Future<void> pump(
    WidgetTester tester, {
    McpMonitorKind kind = McpMonitorKind.protocol,
    bool light = false,
  }) async {
    tester.view.physicalSize = const Size(800, 1000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [mcpSessionOwnerProvider.overrideWithValue(owner)],
        child: MaterialApp(
          theme: (light ? AppTheme.light : AppTheme.dark).copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: McpMonitorView(serverId: 's', kind: kind),
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 40));
    await tester.pumpAndSettle();
  }

  Future<void> settle(WidgetTester tester) async {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 40));
    for (
      var i = 0;
      i < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, int sequence) async {
    await tester.tap(find.byKey(ValueKey(sequence)));
    await tester.pump();
  }

  void pair() {
    session.frame(
      '{"id":1,"method":"tools/call","_meta":{"clientInfo":{"name":"API Caffeine"}}}',
    );
    session.frame(
      '{"id":1,"result":{"_meta":{"serverInfo":{"name":"Fixture"}},"token":"secret-canary"}}',
      kind: RpcFrameKind.response,
      direction: RpcDirection.incoming,
    );
  }

  testWidgets(
    'frames pair and selected detail exposes metadata and sanitized Copy',
    (tester) async {
      pair();
      await pump(tester);
      expect(find.textContaining('paired #1'), findsOneWidget);
      expect(find.text('modern era'), findsOneWidget);
      await select(tester, 0);
      expect(
        tester.widget<CodeView>(find.byType(CodeView)).controller.text,
        contains('clientInfo'),
      );
      await tester.tap(find.text('View paired frame #1'));
      await tester.pump();
      expect(
        tester.widget<CodeView>(find.byType(CodeView)).controller.text,
        contains('serverInfo'),
      );
      await tester.tap(find.text('Copy capture'));
      await tester.pump();
      expect(copied, contains('[REDACTED]'));
      expect(copied, isNot(contains('secret-canary')));
    },
  );
  testWidgets(
    'Ctrl+F targets filtering and kind/direction controls narrow rows',
    (tester) async {
      pair();
      await pump(tester);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      expect(
        tester
            .widget<TextField>(
              find.widgetWithText(TextField, 'Filter captures'),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Filter captures'),
        'tools/call',
      );
      await tester.pump();
      expect(find.text('1 / 2 captures'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextField, 'Filter captures'),
        '',
      );
      await tester.pump();
      await tester.tap(find.byType(DropdownButton<RpcDirection>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('incoming').last);
      await tester.pumpAndSettle();
      expect(find.text('1 / 2 captures'), findsOneWidget);
      await tester.tap(find.byType(DropdownButton<RpcFrameKind>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('notification').last);
      await tester.pumpAndSettle();
      expect(find.text('No captures match this filter.'), findsOneWidget);
    },
  );
  testWidgets('truncated detail loads and copies the complete sanitized frame', (
    tester,
  ) async {
    session.frame(
      '{"id":1,"method":"tools/call","value":"${'x' * (300 * 1024)}secret-canary"}',
    );
    await pump(tester);
    await select(tester, 0);
    expect(find.textContaining('Truncated preview'), findsOneWidget);
    expect(
      tester.widget<CodeView>(find.byType(CodeView)).controller.text.length,
      lessThan(300 * 1024),
    );
    await tester.tap(find.text('Load full'));
    await settle(tester);
    expect(
      tester.widget<CodeView>(find.byType(CodeView)).controller.text,
      contains('[REDACTED]'),
    );
    await tester.tap(find.text('Copy capture'));
    await tester.pump();
    expect(copied!.length, greaterThan(300 * 1024));
    expect(copied, isNot(contains('secret-canary')));
  });
  void network({bool partial = false}) {
    final sentinel =
        '=?base64?${base64Encode(utf8.encode('team/é secret-canary'))}?=';
    session.networkEvents.add(
      NetworkEntry(
        method: 'POST',
        url: 'https://example.test/mcp?token=[REDACTED]',
        status: 200,
        requestHeaders: session.sanitizer.headers({
          'Mcp-Method': ['tools/call'],
          'Mcp-Param-Team': [sentinel],
          'Authorization': ['Bearer secret-canary'],
        }),
        responseHeaders: {
          'content-type': ['application/json'],
        },
        body: '{"safe":true}',
        truncated: partial,
        duration: const Duration(milliseconds: 35),
      ),
    );
  }

  testWidgets('Network displays sanitized headers and decodes safe sentinels', (
    tester,
  ) async {
    network();
    await pump(tester, kind: McpMonitorKind.network);
    await select(tester, 0);
    await tester.tap(find.text('Request headers'));
    await tester.pump();
    expect(find.text('Mcp-Method'), findsOneWidget);
    expect(find.text('team/é [REDACTED]'), findsOneWidget);
    expect(find.text('[REDACTED]'), findsOneWidget);
    expect(find.textContaining('secret-canary'), findsNothing);
    await tester.tap(find.text('Response headers'));
    await tester.pump();
    expect(find.text('application/json'), findsOneWidget);
  });
  testWidgets(
    'partial bodies cannot offer Load full or imply complete copying',
    (tester) async {
      network(partial: true);
      await pump(tester, kind: McpMonitorKind.network);
      await select(tester, 0);
      expect(find.textContaining('Partial transport body'), findsOneWidget);
      expect(find.text('Load full'), findsNothing);
      expect(find.text('Copy retained body'), findsOneWidget);
    },
  );
  testWidgets('Console updates live and clear affects only its own buffer', (
    tester,
  ) async {
    pair();
    await pump(tester, kind: McpMonitorKind.console);
    session.consoleEvents.add(
      ConsoleLine(timestamp: DateTime.utc(2026), text: 'stderr [REDACTED]'),
    );
    await settle(tester);
    expect(find.text('stderr [REDACTED]'), findsOneWidget);
    await select(tester, 0);
    await tester.tap(find.text('Clear captures'));
    await settle(tester);
    expect(find.byType(CodeView), findsNothing);
    expect(owner.state.diagnostics['s']!.protocol.entries.length, 2);
  });
  testWidgets(
    'warnings remain visible without invalid JSON rendering or disconnect',
    (tester) async {
      session.frame('hello secret-canary', kind: RpcFrameKind.warning);
      await pump(tester);
      await select(tester, 0);
      expect(find.textContaining('Protocol warning:'), findsOneWidget);
      expect(
        tester.widget<CodeView>(find.byType(CodeView)).controller.text,
        'hello [REDACTED]',
      );
      expect(owner.state.sessions['s'], isA<McpConnected>());
    },
  );
  testWidgets(
    'scope changes clear selected payload and reject late Load full',
    (tester) async {
      session.frame(
        '{"id":1,"method":"tools/call","private":"${'x' * (300 * 1024)}"}',
      );
      await pump(tester);
      await select(tester, 0);
      await tester.tap(find.text('Load full'));
      await tester.runAsync(() => owner.switchScope('other', 'w'));
      await settle(tester);
      expect(find.byType(CodeView), findsNothing);
      expect(find.text('Copy capture'), findsNothing);
      expect(
        find.text('No diagnostics are retained for this session.'),
        findsOneWidget,
      );
    },
  );
  testWidgets('10001 frames show eviction count and build only visible rows', (
    tester,
  ) async {
    for (var i = 0; i < 10001; i++) {
      session.frame('{"id":$i,"method":"method_$i"}');
    }
    await pump(tester);
    expect(find.text('1 older entries dropped'), findsOneWidget);
    expect(find.byType(ListTile).evaluate().length, lessThan(30));
    await tester.enterText(
      find.widgetWithText(TextField, 'Filter captures'),
      'method_9999',
    );
    await tester.pump();
    expect(find.text('1 / 10000 captures'), findsOneWidget);
  });
  for (final light in [false, true]) {
    testWidgets('${light ? 'light' : 'dark'} monitor layout fits and renders', (
      tester,
    ) async {
      pair();
      await pump(tester, light: light);
      await select(tester, 0);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
      if (const bool.fromEnvironment('MCP_UI_SCREENSHOTS')) {
        await tester.runAsync(() async {
          final rendered =
              await (boundary.currentContext!.findRenderObject()
                      as RenderRepaintBoundary)
                  .toImage();
          final bytes = await rendered.toByteData(
            format: ui.ImageByteFormat.png,
          );
          await File('.dart_tool/mcp_monitor_${light ? 'light' : 'dark'}.png')
              .writeAsBytes(bytes!.buffer.asUint8List());
          rendered.dispose();
        });
      }
    });
  }
}
