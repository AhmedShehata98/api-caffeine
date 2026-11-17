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
import 'package:test_point/modules/mcp_lab/widgets/mcp_tools_view.dart';
import 'package:test_point/modules/mcp_lab/services/schema_form_values.dart';
import 'package:test_point/modules/mcp_lab/widgets/mcp_schema_form.dart';

import '../../../support/load_bundled_test_fonts.dart';

class _Session implements McpSession {
  final calls = <(String, Map<String, dynamic>)>[];
  bool includeStructured = false;
  Object? structured;
  final tools = <Map<String, dynamic>>[
    {
      'name': 'add',
      'title': 'Add numbers',
      'description': 'Add two integers.',
      'inputSchema': {
        'type': 'object',
        'required': ['a', 'b'],
        'properties': {
          'a': {'type': 'integer', 'default': 2},
          'b': {'type': 'integer', 'default': 3},
        },
      },
    },
    {
      'name': 'raw',
      'inputSchema': {r'$ref': 'https://invalid.test/schema'},
    },
    {
      'name': 'destroy',
      'inputSchema': {'type': 'object'},
      'annotations': {'destructiveHint': true},
    },
    {
      'name': 'fail',
      'inputSchema': {'type': 'object'},
    },
  ];
  @override
  Future<Result<Map<String, dynamic>>> request(
    String method,
    Map<String, dynamic> params, {
    Object? id,
    Duration? timeout,
  }) async {
    calls.add((method, params));
    if (method == 'tools/list') return Result.success({'tools': tools});
    final args = params['arguments'] as Map;
    return Result.success({
      'content': [
        {
          'type': 'text',
          'text': params['name'] == 'add'
              ? '${(args['a'] as num) + (args['b'] as num)}'
              : 'Tool message',
        },
      ],
      'isError': params['name'] == 'fail',
      if (includeStructured) 'structuredContent': structured,
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
              'capabilities': {'tools': {}},
            },
          ),
        ),
      ),
    );
  });
  tearDown(() => owner.dispose());
  Future<void> pump(WidgetTester tester, {bool light = false}) async {
    tester.view.physicalSize = const Size(800, 900);
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
            child: const Scaffold(body: McpToolsView(serverId: 's')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> select(WidgetTester tester, String name) async {
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text(name).last);
    await tester.pumpAndSettle();
  }

  Future<void> call(WidgetTester tester) async {
    await tester.ensureVisible(find.text('Call tool · Ctrl+Enter'));
    await tester.tap(find.text('Call tool · Ctrl+Enter'));
    await tester.pump();
  }

  Future<void> finishFormatting(WidgetTester tester) async {
    for (
      var index = 0;
      index < 100 && find.byType(LinearProgressIndicator).evaluate().isNotEmpty;
      index++
    ) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump(const Duration(milliseconds: 16));
    }
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);
    expect(find.text('Could not format this result.'), findsNothing);
    expect(find.text('Copy result JSON'), findsOneWidget);
  }

  for (final valid in [true, false]) {
    testWidgets(
      '${valid ? 'valid' : 'invalid'} output schema is diagnostic and leaves the call successful',
      (tester) async {
        session.tools.first['outputSchema'] = {
          'type': 'object',
          'required': ['n'],
          'properties': {
            'n': {'type': 'integer'},
          },
        };
        session.includeStructured = true;
        session.structured = {'n': valid ? 5 : 'five'};
        await pump(tester);
        tester.view.physicalSize = const Size(800, 1800);
        await select(tester, 'Add numbers');
        await call(tester);
        for (var index = 0; index < 100; index++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pump();
          if (find.text('Checking output schema…').evaluate().isEmpty &&
              find.byType(LinearProgressIndicator).evaluate().isEmpty &&
              find.text('Copy structured content').evaluate().isNotEmpty) {
            break;
          }
        }
        expect(
          find.text(
            valid
                ? 'Output schema: valid within the supported subset.'
                : 'Output schema diagnostic: structuredContent does not match.',
          ),
          findsOneWidget,
        );
        expect(find.text('Success'), findsOneWidget);
        expect(owner.workFor('s')!.tools.state.outcome!.isSuccess, isTrue);
        expect(find.text('Copy structured content'), findsOneWidget);
        await tester.tap(find.text('Clear result'));
        await tester.pump();
        expect(find.text('Structured content'), findsNothing);
      },
    );
  }

  testWidgets(
    'defaults, required validation and explicit call send typed arguments',
    (tester) async {
      await pump(tester);
      await select(tester, 'Add numbers');
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'a *'))
            .controller!
            .text,
        '2',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'b *'), '');
      await call(tester);
      expect(find.text('Required'), findsOneWidget);
      expect(session.calls.where((call) => call.$1 == 'tools/call'), isEmpty);
      await tester.enterText(find.widgetWithText(TextFormField, 'b *'), '4');
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      await finishFormatting(tester);
      expect(session.calls.last.$2['arguments'], {'a': 2, 'b': 4});
      expect(find.text('Success'), findsOneWidget);
      expect(find.text('Result · add'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('form JSON round trip preserves typed edits', (tester) async {
    await pump(tester);
    await select(tester, 'Add numbers');
    await tester.tap(find.text('JSON'));
    await tester.pumpAndSettle();
    final editor = tester.widget<CodeView>(find.byType(CodeView)).controller;
    expect(editor.text, '{"a":2,"b":3}');
    editor.text = '{"a":9,"b":5}';
    await tester.pump();
    await tester.tap(find.text('Form'));
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'a *'))
          .controller!
          .text,
      '9',
    );
    expect(owner.workFor('s')!.tools.state.draft!.arguments, '{"a":9,"b":5}');
  });
  testWidgets(
    'edits from different fields before a frame do not overwrite each other',
    (tester) async {
      await pump(tester);
      await select(tester, 'Add numbers');
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'a *'))
          .onChanged!('7');
      tester
          .widget<TextFormField>(find.widgetWithText(TextFormField, 'b *'))
          .onChanged!('8');
      await tester.pump();
      expect(
        owner.workFor('s')!.tools.state.draft!.arguments,
        '{"a":"7","b":"8"}',
      );
    },
  );
  testWidgets(
    'unsupported schema starts in raw mode and invalid JSON never sends',
    (tester) async {
      await pump(tester);
      await select(tester, 'raw');
      expect(find.text('External \$ref not supported'), findsOneWidget);
      tester.widget<CodeView>(find.byType(CodeView)).controller.text = '{';
      await tester.pump();
      await call(tester);
      expect(find.textContaining('Invalid JSON at offset'), findsOneWidget);
      expect(session.calls.where((call) => call.$1 == 'tools/call'), isEmpty);
    },
  );
  testWidgets(
    'destructive hint requires confirmation and cancel sends nothing',
    (tester) async {
      await pump(tester);
      await select(tester, 'destroy');
      await call(tester);
      await tester.pumpAndSettle();
      expect(find.text('Call destructive tool?'), findsOneWidget);
      expect(session.calls.where((call) => call.$1 == 'tools/call'), isEmpty);
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(session.calls.where((call) => call.$1 == 'tools/call'), isEmpty);
    },
  );
  testWidgets('tool errors remain results and result clear preserves draft', (
    tester,
  ) async {
    await pump(tester);
    await select(tester, 'fail');
    await call(tester);
    await finishFormatting(tester);
    expect(find.text('Tool error'), findsOneWidget);
    await tester.ensureVisible(find.text('Clear result'));
    await tester.tap(find.text('Clear result'));
    await tester.pumpAndSettle();
    expect(find.text('Tool error'), findsNothing);
    expect(owner.workFor('s')!.tools.state.draft!.tool!.name, 'fail');
  });
  testWidgets('account boundary removes form and result state', (tester) async {
    await pump(tester);
    await select(tester, 'Add numbers');
    await tester.runAsync(() => owner.switchScope(null, null));
    await tester.pumpAndSettle();
    expect(find.text('Call tool · Ctrl+Enter'), findsNothing);
    expect(find.byType(TextFormField), findsNothing);
  });
  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} tool view renders without overflow',
      (tester) async {
        await pump(tester, light: light);
        await select(tester, 'Add numbers');
        await call(tester);
        await finishFormatting(tester);
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('MCP_UI_SCREENSHOTS')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final bytes = await image.toByteData(
              format: ui.ImageByteFormat.png,
            );
            await File('.dart_tool/mcp_tools_${light ? 'light' : 'dark'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
  testWidgets(
    'nested controls, array removal, optional fields and variants retain values',
    (tester) async {
      final spec = const SchemaFormBuilder().build({
        'type': 'object',
        'required': ['name', 'settings', 'mode'],
        'properties': {
          'name': {'type': 'string'},
          'settings': {
            'type': 'object',
            'required': ['enabled'],
            'properties': {
              'enabled': {'type': 'boolean', 'default': true},
            },
          },
          'unit': {
            'type': 'string',
            'enum': ['a', 'b'],
            'default': 'b',
          },
          'tags': {
            'type': 'array',
            'items': {'type': 'string'},
            'default': ['first', 'second'],
          },
          'mode': {
            'oneOf': [
              {
                'type': 'object',
                'required': ['city'],
                'properties': {
                  'city': {'type': 'string', 'default': 'Cairo'},
                },
              },
              {
                'type': 'object',
                'required': ['count'],
                'properties': {
                  'count': {'type': 'integer', 'default': 3},
                },
              },
            ],
          },
        },
      }) as FormSpec;
      Object? value = const SchemaFormValues().initial(spec);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark.copyWith(splashFactory: InkRipple.splashFactory),
          home: Scaffold(
            body: SingleChildScrollView(
              child: StatefulBuilder(
                builder: (_, update) => McpSchemaForm(
                  spec: spec,
                  value: value,
                  onChanged: (next) => update(() => value = next),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'name *'),
        'Ada',
      );
      await tester.ensureVisible(find.byTooltip('Remove item 1'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Remove item 1'));
      await tester.pump();
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'Item 1'))
            .controller!
            .text,
        'second',
      );
      await tester.ensureVisible(find.text('Include unit'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Include unit'));
      await tester.pump();
      await tester.ensureVisible(
        find.widgetWithText(DropdownButtonFormField<int>, 'mode *'),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<int>, 'mode *'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Variant 2').last);
      await tester.pumpAndSettle();
      expect(
        const SchemaFormBuilder()
            .arguments(spec, value, coerce: true)
            .valueOrNull,
        {
          'name': 'Ada',
          'settings': {'enabled': true},
          'tags': ['second'],
          'mode': {'count': 3},
        },
      );
      expect(tester.takeException(), isNull);
    },
  );

  test('default and variant values survive serialization and restoration', () {
    const values = SchemaFormValues();
    final plan = const SchemaFormBuilder().build({
      'oneOf': [
        {
          'type': 'object',
          'required': ['a'],
          'properties': {
            'a': {'type': 'integer', 'default': 3},
          },
        },
        {
          'type': 'object',
          'required': ['b'],
          'properties': {
            'b': {'type': 'string', 'default': 'text'},
          },
        },
      ],
    }) as FormSpec;
    expect(values.jsonValue(values.initial(plan)), {'a': 3});
    final restored =
        values.restore(plan, {'b': 'changed'}) as SchemaVariantValue;
    expect(restored.index, 1);
    expect(values.jsonValue(restored), {'b': 'changed'});
  });
}
