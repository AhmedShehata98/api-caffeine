import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/ui/theme/app_theme.dart';
import 'package:test_point/core/ui/widgets/code_view.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/widgets/mcp_resources_view.dart';

import '../../../support/load_bundled_test_fonts.dart';

class _Session implements McpSession {
  final calls = <(String, Map<String, dynamic>)>[];
  String text = '{"city":"Lisbon","temperature":19}';
  bool fail = false;
  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) async {
    calls.add((method, params));
    if (method == 'resources/list') {
      return Result.success(
        params['cursor'] == null
            ? {
                'resources': [
                  {
                    'name': 'Forecast',
                    'uri': 'weather://lisbon',
                    'mimeType': 'application/json',
                    'description': 'Current forecast.',
                  },
                ],
                'nextCursor': 'second',
              }
            : {
                'resources': [
                  {
                    'name': 'Binary data',
                    'uri': 'weather://bytes',
                    'mimeType': 'application/octet-stream',
                  },
                ],
              },
      );
    }
    if (method == 'resources/templates/list') {
      return const Result.success({
        'resourceTemplates': [
          {
            'name': 'City template',
            'uriTemplate': 'weather://{city}',
            'mimeType': 'application/json',
          },
        ],
      });
    }
    if (fail) {
      return const Result.failure(
        NetworkFailure('Resource not found: weather://missing'),
      );
    }
    return Result.success({
      'contents': [
        if (params['uri'] == 'weather://bytes')
          {
            'uri': 'weather://bytes',
            'mimeType': 'application/octet-stream',
            'blob': 'AID/AA==',
          }
        else
          {'uri': params['uri'], 'mimeType': 'application/json', 'text': text},
      ],
    });
  }

  @override
  Future<Result<void>> close() async => const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  setUpAll(loadBundledTestFonts);
  late McpSessionOwner owner;
  late _Session session;
  final boundary = GlobalKey();
  setUp(() async {
    session = _Session();
    owner = McpSessionOwner();
    await owner.switchScope('u', 'w');
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {
              'capabilities': {'resources': {}},
            },
          ),
        ),
      ),
    );
  });
  tearDown(() => owner.dispose());
  Future<void> pump(WidgetTester tester, {bool light = false}) async {
    tester.view.physicalSize = const Size(800, 1100);
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
            child: const Scaffold(body: McpResourcesView(serverId: 's')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> finish(WidgetTester tester) async {
    await tester.pump();
    for (
      var i = 0;
      i < 100 &&
          (i < 3 || find.byType(LinearProgressIndicator).evaluate().isNotEmpty);
      i++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
    expect(find.text('Could not prepare this resource.'), findsNothing);
    expect(find.text('Could not format this result.'), findsNothing);
  }

  Future<void> read(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Read resource · Ctrl+Enter'));
    await tester.tap(find.text('Read resource · Ctrl+Enter'));
    await finish(tester);
  }

  testWidgets(
    'lists metadata, appends only on request and does not auto-read',
    (tester) async {
      await pump(tester);
      expect(find.text('Resources (1)'), findsOneWidget);
      expect(find.text('Templates (1)'), findsOneWidget);
      expect(find.text('Current forecast.'), findsOneWidget);
      await tester.tap(find.text('Forecast'));
      await tester.pump();
      expect(session.calls.where((c) => c.$1 == 'resources/read'), isEmpty);
      await tester.tap(find.text('Load next page'));
      await tester.pumpAndSettle();
      expect(find.text('Resources (2)'), findsOneWidget);
      expect(find.text('Binary data'), findsOneWidget);
      expect(find.text('Load next page'), findsNothing);
      expect(session.calls.last.$1, 'resources/list');
      expect(session.calls.last.$2, {'cursor': 'second'});
    },
  );
  testWidgets(
    'Ctrl+Enter reads typed URI and JSON viewer formats the resource',
    (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'weather://lisbon');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await finish(tester);
      expect(session.calls.last.$1, 'resources/read');
      expect(session.calls.last.$2, {'uri': 'weather://lisbon'});
      expect(find.text('Copy resource text'), findsOneWidget);
      final editor = tester.widget<CodeView>(find.byType(CodeView).first);
      expect(editor.controller.text, contains('\n  "city": "Lisbon"'));
      expect(editor.readOnly, isTrue);
      await tester.tap(find.byTooltip('Clear resource result'));
      await tester.pump();
      expect(find.text('Copy resource text'), findsNothing);
      expect(owner.workFor('s')!.resources.state.draft, 'weather://lisbon');
    },
  );
  testWidgets(
    'templates require a resolved URI and invalid input never sends',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Templates (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City template'));
      await tester.pump();
      await read(tester);
      expect(
        find.textContaining('no unresolved template expressions'),
        findsOneWidget,
      );
      expect(session.calls.where((c) => c.$1 == 'resources/read'), isEmpty);
      await tester.enterText(find.byType(TextField).first, 'weather://lisbon');
      await read(tester);
      expect(session.calls.last.$2, {'uri': 'weather://lisbon'});
    },
  );
  testWidgets(
    'draft restores on remount and account change clears the URI and result',
    (tester) async {
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'weather://lisbon');
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        'weather://lisbon',
      );
      await read(tester);
      await tester.runAsync(() => owner.switchScope('other', 'w'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(find.byType(TextField).first).controller!.text,
        isEmpty,
      );
      expect(find.text('Copy resource text'), findsNothing);
      expect(find.text('Forecast'), findsNothing);
    },
  );
  testWidgets('resource failures display the supplied application message', (
    tester,
  ) async {
    await pump(tester);
    session.fail = true;
    await tester.enterText(find.byType(TextField).first, 'weather://missing');
    await read(tester);
    expect(find.text('Resource not found: weather://missing'), findsOneWidget);
  });
  testWidgets('binary results expose MIME and decoded size', (tester) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'weather://bytes');
    await read(tester);
    expect(owner.workFor('s')!.resources.state.outcome!.isSuccess, isTrue);
    expect(
      owner.workFor('s')!.resources.state.outcome!.valueOrNull!.single.blob,
      'AID/AA==',
    );
    expect(find.textContaining('invalid base64'), findsNothing);
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Binary resource · 4 bytes'), findsOneWidget);
    expect(find.text('application/octet-stream'), findsOneWidget);
  });
  testWidgets('large text is bounded until Load full content is clicked', (
    tester,
  ) async {
    session.text = 'x' * (256 * 1024 + 10);
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'weather://large');
    await read(tester);
    expect(
      tester
          .widget<CodeView>(find.byType(CodeView).first)
          .controller
          .text
          .length,
      256 * 1024,
    );
    await tester.tap(find.text('Load full content'));
    await tester.pump();
    expect(
      tester.widget<CodeView>(find.byType(CodeView).first).controller.text,
      session.text,
    );
  });
  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} resource view renders without overflow',
      (tester) async {
        await pump(tester, light: light);
        await tester.tap(find.text('Forecast'));
        await tester.pump();
        await read(tester);
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
            await File(
              '.dart_tool/mcp_resources_${light ? 'light' : 'dark'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      },
    );
  }
}
