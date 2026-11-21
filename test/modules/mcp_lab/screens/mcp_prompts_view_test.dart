import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/ui/theme/app_theme.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';
import 'package:api_caffeine/modules/mcp_lab/widgets/mcp_prompts_view.dart';

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
  Future<Result<Map<String, dynamic>>> Function()? complete;
  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) async {
    calls.add((method, params));
    if (method == 'prompts/list') return Result.success({'prompts': prompts});
    if (method == 'completion/complete') {
      return complete == null
          ? const Result.success({
              'completion': {
                'values': ['Lisbon', 'Lille'],
                'total': 8,
                'hasMore': true,
              },
            })
          : complete!();
    }
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

  Future<void> enableCompletions() async {
    await owner.disconnect('s');
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          session,
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {
              'capabilities': {'prompts': {}, 'completions': {}},
            },
          ),
        ),
      ),
    );
  }

  Future<void> suggest(WidgetTester tester, {bool settle = true}) async {
    await tester.ensureVisible(find.text('Suggest city'));
    await tester.tap(find.text('Suggest city'));
    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} prompt suggestions select without getting the prompt',
      (tester) async {
        await enableCompletions();
        await pump(tester, light: light);
        await select(tester);
        await tester.enterText(
          find.widgetWithText(TextFormField, 'city *'),
          'Li',
        );
        await tester.enterText(
          find.widgetWithText(TextFormField, 'tone'),
          'friendly',
        );
        await tester.pump();
        expect(
          session.calls.where((call) => call.$1 == 'completion/complete'),
          isEmpty,
        );
        await suggest(tester);
        expect(session.calls.last.$2, {
          'ref': {'type': 'ref/prompt', 'name': 'forecast'},
          'argument': {'name': 'city', 'value': 'Li'},
          'context': {
            'arguments': {'tone': 'friendly'},
          },
        });
        expect(find.text('2 suggestions of 8'), findsOneWidget);
        expect(
          find.textContaining('More matches are available.'),
          findsOneWidget,
        );
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
              '.dart_tool/mcp_prompt_completion_${light ? 'light' : 'dark'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        if (light) {
          await tester.tap(find.text('Lisbon'));
        } else {
          Focus.of(tester.element(find.text('Lisbon'))).requestFocus();
          await tester.pump();
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        }
        await tester.pumpAndSettle();
        expect(
          tester
              .widget<TextFormField>(
                find.widgetWithText(TextFormField, 'city *'),
              )
              .controller!
              .text,
          'Lisbon',
        );
        expect(owner.workFor('s')!.prompts.state.draft!.arguments, {
          'city': 'Lisbon',
          'tone': 'friendly',
        });
        expect(
          session.calls.where((call) => call.$1 == 'prompts/get'),
          isEmpty,
        );
        await get(tester);
        expect(session.calls.last.$1, 'prompts/get');
        expect(session.calls.last.$2, {
          'name': 'forecast',
          'arguments': {'city': 'Lisbon', 'tone': 'friendly'},
        });
        expect(tester.takeException(), isNull);
      },
    );
  }
  testWidgets('prompt completion is hidden unless the server advertises it', (
    tester,
  ) async {
    await pump(tester);
    await select(tester);
    expect(find.text('Suggest city'), findsNothing);
    expect(
      session.calls.where((call) => call.$1 == 'completion/complete'),
      isEmpty,
    );
  });
  testWidgets(
    'completion helps an empty required field while Get remains validated',
    (tester) async {
      await enableCompletions();
      await pump(tester);
      await select(tester);
      await get(tester);
      expect(find.text('Enter city.'), findsOneWidget);
      await suggest(tester);
      expect(session.calls.last.$2['argument'], {'name': 'city', 'value': ''});
      expect(find.text('Lisbon'), findsOneWidget);
      expect(session.calls.where((call) => call.$1 == 'prompts/get'), isEmpty);
    },
  );
  testWidgets('prompt completion supports failure retry and empty results', (
    tester,
  ) async {
    await enableCompletions();
    await pump(tester);
    await select(tester);
    session.complete = () async =>
        const Result.failure(NetworkFailure('Suggestions unavailable.'));
    await suggest(tester);
    expect(find.text('Suggestions unavailable.'), findsOneWidget);
    session.complete = () async => const Result.success({
      'completion': {'values': []},
    });
    await suggest(tester);
    expect(find.text('No suggestions returned.'), findsOneWidget);
    expect(find.text('Suggestions unavailable.'), findsNothing);
  });
  testWidgets(
    'another argument edit discards pending completion and updates context',
    (tester) async {
      await enableCompletions();
      await pump(tester);
      await select(tester);
      final pending = Completer<Result<Map<String, dynamic>>>();
      session.complete = () => pending.future;
      await suggest(tester, settle: false);
      expect(find.text('Loading suggestions…'), findsOneWidget);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'tone'),
        'formal',
      );
      await tester.pump();
      pending.complete(
        const Result.success({
          'completion': {
            'values': ['stale city'],
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('stale city'), findsNothing);
      session.complete = null;
      await suggest(tester);
      expect(session.calls.last.$2['context'], {
        'arguments': {'tone': 'formal'},
      });
      await tester.enterText(
        find.widgetWithText(TextFormField, 'city *'),
        'fresh',
      );
      await tester.pump();
      expect(find.text('Lisbon'), findsNothing);
    },
  );
  testWidgets(
    'remount retains prompt drafts and drops suggestions without requesting again',
    (tester) async {
      await enableCompletions();
      await pump(tester);
      await select(tester);
      await tester.enterText(
        find.widgetWithText(TextFormField, 'city *'),
        'Li',
      );
      await tester.pump();
      await suggest(tester);
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.text('Lisbon'), findsNothing);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'city *'))
            .controller!
            .text,
        'Li',
      );
      expect(
        session.calls.where((call) => call.$1 == 'completion/complete'),
        hasLength(1),
      );
    },
  );
  testWidgets('removing the selected prompt discards a pending suggestion', (
    tester,
  ) async {
    await enableCompletions();
    await pump(tester);
    await select(tester);
    final pending = Completer<Result<Map<String, dynamic>>>();
    session.complete = () => pending.future;
    await suggest(tester, settle: false);
    session.prompts = [];
    await tester.tap(find.byTooltip('Refresh prompts'));
    await tester.pumpAndSettle();
    pending.complete(
      const Result.success({
        'completion': {
          'values': ['removed city'],
        },
      }),
    );
    await tester.pumpAndSettle();
    expect(find.text('removed city'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
  testWidgets(
    'scope replacement removes pending suggestions and prompt inputs',
    (tester) async {
      await enableCompletions();
      await pump(tester);
      await select(tester);
      final pending = Completer<Result<Map<String, dynamic>>>();
      session.complete = () => pending.future;
      await suggest(tester, settle: false);
      await tester.runAsync(() => owner.switchScope('other', 'w'));
      await tester.pump();
      pending.complete(
        const Result.success({
          'completion': {
            'values': ['private city'],
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('private city'), findsNothing);
      expect(find.byType(TextFormField), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'switching prompts discards pending suggestions for matching field names',
    (tester) async {
      await enableCompletions();
      session.prompts.add({
        'name': 'other',
        'title': 'Other prompt',
        'arguments': [
          {'name': 'city'},
        ],
      });
      await pump(tester);
      await select(tester);
      final pending = Completer<Result<Map<String, dynamic>>>();
      session.complete = () => pending.future;
      await suggest(tester, settle: false);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      await tester.tap(find.text('Other prompt').last);
      await tester.pump();
      pending.complete(
        const Result.success({
          'completion': {
            'values': ['old prompt city'],
          },
        }),
      );
      await tester.pumpAndSettle();
      expect(find.text('old prompt city'), findsNothing);
      expect(owner.workFor('s')!.prompts.state.draft!.prompt!.name, 'other');
      expect(owner.workFor('s')!.prompts.state.draft!.arguments, isEmpty);
    },
  );
  testWidgets(
    'large manual prompt values can still be sent while completion rejects them locally',
    (tester) async {
      await enableCompletions();
      await pump(tester);
      await select(tester);
      final text = 'x' * 4097;
      await tester.enterText(
        find.widgetWithText(TextFormField, 'city *'),
        text,
      );
      await tester.pump();
      await suggest(tester);
      expect(
        find.textContaining('keep completion inputs within their size limits'),
        findsOneWidget,
      );
      expect(
        session.calls.where((call) => call.$1 == 'completion/complete'),
        isEmpty,
      );
      await get(tester);
      expect(session.calls.last.$2['arguments'], {'city': text});
    },
  );
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
