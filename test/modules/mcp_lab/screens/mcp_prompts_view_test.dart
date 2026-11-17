import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/ui/theme/app_theme.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/widgets/mcp_prompts_view.dart';

import '../../../support/load_bundled_test_fonts.dart';

class _Session implements McpSession {
  final calls = <(String, Map<String, dynamic>)>[];
  List<Map<String, dynamic>> prompts = [
    {
      'name': 'forecast',
      'title': 'Forecast summary',
      'description': 'Summarize the forecast for a city.',
      'arguments': [
        {'name': 'city', 'required': true},
        {'name': 'tone'},
      ],
    },
  ];
  bool fail = false;
  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) async {
    calls.add((method, params));
    if (method == 'prompts/list') return Result.success({'prompts': prompts});
    if (fail) {
      return const Result.failure(NetworkFailure('Prompt unavailable.'));
    }
    return const Result.success({
      'messages': [
        {
          'role': 'user',
          'content': {'type': 'text', 'text': 'Forecast for Lisbon'},
        },
        {
          'role': 'assistant',
          'content': {'type': 'text', 'text': 'A mild afternoon.'},
        },
        {
          'role': 'user',
          'content': {
            'type': 'resource_link',
            'uri': 'weather://lisbon',
            'name': 'Forecast data',
          },
        },
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
  late _Session session;
  late McpSessionOwner owner;
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
              'capabilities': {'prompts': {}},
            },
          ),
        ),
      ),
    );
  });
  tearDown(() => owner.dispose());
  Future<void> pump(WidgetTester tester, {bool light = false}) async {
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
            child: const Scaffold(body: McpPromptsView(serverId: 's')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Forecast summary').last);
    await tester.pumpAndSettle();
  }

  Future<void> get(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Get prompt · Ctrl+Enter'));
    await tester.tap(find.text('Get prompt · Ctrl+Enter'));
    await tester.pump();
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
    expect(find.text('Could not format this result.'), findsNothing);
    await tester.pumpAndSettle();
  }

  testWidgets('required arguments block sending and messages retain order', (
    tester,
  ) async {
    await pump(tester);
    await select(tester);
    expect(session.calls.where((c) => c.$1 == 'prompts/get'), isEmpty);
    await get(tester);
    expect(find.text('Enter city.'), findsOneWidget);
    expect(session.calls.where((c) => c.$1 == 'prompts/get'), isEmpty);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'city *'),
      'Lisbon',
    );
    await get(tester);
    expect(session.calls.last.$2, {
      'name': 'forecast',
      'arguments': {'city': 'Lisbon'},
    });
    expect(find.text('1. user'), findsOneWidget);
    expect(find.text('2. assistant'), findsOneWidget);
    expect(find.text('3. user'), findsOneWidget);
      expect(find.text('weather://lisbon'), findsOneWidget);
    expect(find.text('Copy result JSON'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  testWidgets('clear preserves arguments and remount restores the draft', (
    tester,
  ) async {
    await pump(tester);
    await select(tester);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'city *'),
      'Lisbon',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'tone'),
      'friendly',
    );
    await get(tester);
    await tester.tap(find.byTooltip('Clear prompt result'));
    await tester.pump();
    expect(find.text('1. user'), findsNothing);
    expect(
      owner.workFor('s')!.prompts.state.draft!.arguments['tone'],
      'friendly',
    );
    await tester.pumpWidget(const SizedBox());
    expect(owner.workFor('s')!.prompts.state.draft!.prompt?.name, 'forecast');
    await pump(tester);
    expect(owner.workFor('s')!.prompts.state.draft!.arguments, {
      'city': 'Lisbon',
      'tone': 'friendly',
    });
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'city *'))
          .initialValue,
      'Lisbon',
    );
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'tone'))
          .initialValue,
      'friendly',
    );
  });
  testWidgets(
    'request failures are visible and scope cleanup removes sensitive drafts',
    (tester) async {
      await pump(tester);
      await select(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'city *'),
        'Lisbon',
      );
      session.fail = true;
      await get(tester);
      expect(find.text('Prompt unavailable.'), findsOneWidget);
      await tester.runAsync(() => owner.switchScope('other', 'w'));
      await tester.pumpAndSettle();
      expect(find.text('Lisbon'), findsNothing);
      expect(find.text('Prompt unavailable.'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
    },
  );
  testWidgets(
    'refresh removes obsolete selections and never gets automatically',
    (tester) async {
      await pump(tester);
      await select(tester);
      session.prompts = [];
      await tester.tap(find.byTooltip('Refresh prompts'));
      await tester.pumpAndSettle();
      expect(
        find.text('This server has no prompts. Refresh to check again.'),
        findsOneWidget,
      );
      expect(owner.workFor('s')!.prompts.state.draft!.prompt, isNull);
      expect(session.calls.where((c) => c.$1 == 'prompts/get'), isEmpty);
    },
  );
  testWidgets(
    'duplicate names show an application failure instead of a broken selector',
    (tester) async {
      session.prompts.add(session.prompts.first);
      await pump(tester);
      expect(
        find.text('The server returned duplicate prompt or argument names.'),
        findsOneWidget,
      );
      expect(find.byType(DropdownButtonFormField<String>), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} prompt view fits and renders messages',
      (tester) async {
        await pump(tester, light: light);
        await select(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'city *'),
          'Lisbon',
        );
        await get(tester);
        expect(find.text('Copy result JSON'), findsOneWidget);
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
            await File('.dart_tool/mcp_prompts_${light ? 'light' : 'dark'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      },
    );
  }
}
