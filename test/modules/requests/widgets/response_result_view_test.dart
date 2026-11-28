import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';
import 'package:api_caffeine/core/ui/theme/app_theme.dart';
import 'package:api_caffeine/core/ui/widgets/code_view.dart';
import 'package:api_caffeine/modules/requests/models/http_response_result.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';
import 'package:api_caffeine/modules/requests/widgets/response_result_view.dart';

const _json = HttpResponseResult(
  statusCode: 400,
  headers: {
    'content-type': ['application/json'],
  },
  body: '{"parent":{"child":"Needle"},"other":"needle"}',
  prettyBody: '{\n  "parent": {"child": "Needle"},\n  "other": "needle"\n}',
  duration: Duration(milliseconds: 42),
  sizeBytes: 52,
);

Future<void> _show(
  WidgetTester tester,
  HttpResponseResult response, {
  double width = 750,
  ThemeData? theme,
  bool settle = true,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: theme ?? AppTheme.dark,
      home: Scaffold(
        body: Align(
          alignment: Alignment.topLeft,
          child: SizedBox(
            width: width,
            height: 470,
            child: ResponseResultView(
              key: ObjectKey(response),
              response: response,
            ),
          ),
        ),
      ),
    ),
  );
  if (settle) await tester.pumpAndSettle();
}

final _find = find.byWidgetPredicate(
  (widget) =>
      widget is TextField && widget.decoration?.hintText == 'Find in body',
);

Future<void> _waitFor(WidgetTester tester, Finder target) async {
  for (var attempt = 0; target.evaluate().isEmpty && attempt < 50; attempt++) {
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 25)),
    );
    await tester.pump(const Duration(milliseconds: 30));
  }
  expect(target, findsOneWidget);
}

void main() {
  for (final theme in [AppTheme.dark, AppTheme.light]) {
    testWidgets(
      'response editor fills the space below the toolbar in ${theme.brightness}',
      (tester) async {
        await _show(tester, _json, theme: theme);
        final panel = tester.getRect(find.byType(ResponseResultView));
        final editor = tester.getRect(find.byType(CodeEditor));
        expect(editor.height, greaterThan(300));
        expect(panel.bottom - editor.bottom, lessThanOrEqualTo(12));
        expect(editor.left - panel.left, 8);
        expect(panel.right - editor.right, 8);
      },
    );
  }

  testWidgets('a short schema status leaves remaining height for the editor', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: const Scaffold(
          body: Align(
            alignment: Alignment.topLeft,
            child: SizedBox(
              width: 750,
              height: 470,
              child: ResponseResultView(
                response: _json,
                schemaTest: SchemaTestResult(
                  status: SchemaTestStatus.passed,
                  schemaSource: 'true',
                ),
                currentSchema: 'true',
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    final editor = tester.getRect(find.byType(CodeEditor));
    expect(editor.height, greaterThan(280));
  });

  testWidgets(
    'the editor follows pane resizing and the response uses theme surfaces',
    (tester) async {
      var height = 350.0;
      late StateSetter update;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: StatefulBuilder(
                builder: (context, setState) {
                  update = setState;
                  return SizedBox(
                    width: 750,
                    height: height,
                    child: const ResponseResultView(response: _json),
                  );
                },
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final before = tester.getSize(find.byType(CodeEditor)).height;
      update(() => height = 500);
      await tester.pumpAndSettle();
      expect(
        tester.getSize(find.byType(CodeEditor)).height - before,
        closeTo(150, 0.1),
      );
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(
        editor.style!.backgroundColor,
        AppTheme.dark.colorScheme.surfaceContainer,
      );
      final colors = tester.widgetList<ColoredBox>(
        find.descendant(
          of: find.byType(ResponseResultView),
          matching: find.byType(ColoredBox),
        ),
      );
      expect(
        colors.any((box) => box.color == AppTheme.dark.colorScheme.surface),
        isTrue,
      );
    },
  );

  test('schema status colors meet text contrast in both themes', () {
    for (final theme in [AppTheme.dark, AppTheme.light]) {
      final background = theme.colorScheme.surfaceContainerLow
          .computeLuminance();
      for (final foreground in [
        theme.colorScheme.error,
        theme.colorScheme.onSurface,
        theme.colorScheme.onSurfaceVariant,
      ]) {
        final luminance = foreground.computeLuminance();
        final lighter = luminance > background ? luminance : background;
        final darker = luminance > background ? background : luminance;
        expect((lighter + 0.05) / (darker + 0.05), greaterThanOrEqualTo(4.5));
      }
    }
  });

  for (final theme in [AppTheme.dark, AppTheme.light]) {
    testWidgets('schema status fits a narrow pane in ${theme.brightness}', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: theme,
          home: const Scaffold(
            body: Align(
              alignment: Alignment.topLeft,
              child: SizedBox(
                width: 220,
                height: 220,
                child: ResponseResultView(
                  response: _json,
                  schemaTest: SchemaTestResult(
                    status: SchemaTestStatus.invalidSchema,
                    schemaSource: 'bad',
                  ),
                  currentSchema: 'bad',
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Edit schema'), findsOneWidget);
    });
  }

  testWidgets('a late schema verdict preserves the selected body view', (
    tester,
  ) async {
    var result = const SchemaTestResult(
      status: SchemaTestStatus.checking,
      schemaSource: 'true',
    );
    late StateSetter update;
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.dark,
        home: Scaffold(
          body: SizedBox(
            width: 500,
            height: 350,
            child: StatefulBuilder(
              builder: (context, setState) {
                update = setState;
                return ResponseResultView(
                  response: _json,
                  schemaTest: result,
                  currentSchema: 'true',
                );
              },
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Body format'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw'));
    await tester.pumpAndSettle();
    update(
      () => result = const SchemaTestResult(
        status: SchemaTestStatus.passed,
        schemaSource: 'true',
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Schema passed'), findsOneWidget);
    expect(
      tester.widget<CodeEditor>(find.byType(CodeEditor)).controller!.text,
      _json.body,
    );
  });

  testWidgets(
    'schema issues navigate to the existing parent and preserve the body mode',
    (tester) async {
      const issue = SchemaIssue(
        path: ['parent', 'missing'],
        anchor: ['parent'],
        condition: 'Required property is missing',
      );
      const failed = SchemaTestResult(
        status: SchemaTestStatus.failed,
        schemaSource: 'true',
        issues: [issue],
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.dark,
          home: const Scaffold(
            body: SizedBox(
              width: 750,
              height: 470,
              child: ResponseResultView(
                response: _json,
                schemaTest: failed,
                currentSchema: 'edited',
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Schema changed since this response'), findsOneWidget);
      expect(find.text(r'$.parent.missing'), findsOneWidget);
      expect(find.textContaining(r'Linked to $.parent'), findsOneWidget);
      await tester.tap(find.text(r'$.parent.missing'));
      await tester.pumpAndSettle();
      final editor = tester.widget<CodeEditor>(find.byType(CodeEditor));
      expect(editor.controller!.selection.baseIndex, 1);
      expect(find.text('Pretty'), findsOneWidget);
    },
  );

  testWidgets('expands a response with Headers selected and restores the tab', (
    tester,
  ) async {
    await _show(tester, _json);
    await tester.tap(find.text('Headers'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Expand response'));
    await tester.pumpAndSettle();
    expect(find.byTooltip('Close expanded response'), findsOneWidget);
    expect(find.byType(SelectableText), findsOneWidget);
    await tester.tap(find.text('Body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Close expanded response'));
    await tester.pumpAndSettle();
    expect(tester.widget<CodeView>(find.byType(CodeView)).syntax, isNull);
  });

  testWidgets(
    'Find scrolls to off-screen text, wraps, and resets for a new result',
    (tester) async {
      final body = List.generate(180, (index) => 'line $index').join('\n');
      final response = _json.copyWith(
        body: 'Needle\n$body\nneedle',
        prettyBody: null,
      );
      await _show(tester, response);
      await tester.tap(find.byType(CodeView));
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyF);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pumpAndSettle();
      await tester.enterText(_find, 'needle');
      await _waitFor(tester, find.text('1 / 2'));
      await tester.tap(find.byTooltip('Next match'));
      await _waitFor(tester, find.text('2 / 2'));
      final scroll = tester
          .widget<CodeView>(find.byType(CodeView))
          .scrollController!;
      expect(scroll.verticalScroller.offset, greaterThan(1000));
      scroll.verticalScroller.jumpTo(600);
      await tester.pump();
      await tester.tap(find.byTooltip('Expand response'));
      await tester.pumpAndSettle();
      await _waitFor(tester, find.text('2 / 2'));
      expect(
        tester
            .widget<CodeView>(find.byType(CodeView))
            .scrollController!
            .verticalScroller
            .offset,
        closeTo(600, 1),
      );
      await tester.tap(find.byTooltip('Next match'));
      await _waitFor(tester, find.text('1 / 2'));
      await tester.tap(find.byTooltip('Close expanded response'));
      await tester.pumpAndSettle();
      await _waitFor(tester, find.text('1 / 2'));
      expect(
        tester
            .widget<CodeView>(find.byType(CodeView))
            .scrollController!
            .verticalScroller
            .offset,
        lessThan(100),
      );
      await _show(tester, response.copyWith(body: 'new response'));
      expect(_find, findsNothing);
    },
  );

  testWidgets('a replaced large source cannot overwrite the latest response', (
    tester,
  ) async {
    final raw = List.filled(12000, 'large response line').join('\n');
    await _show(
      tester,
      _json.copyWith(body: raw, prettyBody: raw),
      settle: false,
    );
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    await tester.tap(find.text('Raw'));
    await tester.pump();
    await _show(tester, _json);
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 150)),
    );
    await tester.pumpAndSettle();
    final editor = tester.widget<CodeView>(find.byType(CodeView)).controller;
    expect(editor.text, _json.prettyBody);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'Mind Map reveals collapsed matches and keeps state across expansion',
    (tester) async {
      await _show(tester, _json);
      await tester.tap(find.text('Mind Map'));
      await tester.pumpAndSettle();
      expect(find.text('child: Needle'), findsNothing);
      await tester.tap(find.byTooltip('Find in response (Ctrl+F)'));
      await tester.pumpAndSettle();
      await tester.enterText(_find, 'needle');
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      final canvas = find.byType(InteractiveViewer);
      final selected = find.text('child: Needle');
      expect(
        tester.getRect(canvas).contains(tester.getCenter(selected)),
        isTrue,
      );
      final viewport = tester
          .widget<InteractiveViewer>(canvas)
          .transformationController!
          .value
          .clone();
      await tester.tap(find.byTooltip('Expand response'));
      await tester.pumpAndSettle();
      expect(find.text('1 / 2'), findsOneWidget);
      expect(
        tester
            .widget<InteractiveViewer>(canvas)
            .transformationController!
            .value,
        viewport,
      );
      await tester.tap(find.byTooltip('Previous match'));
      await tester.pumpAndSettle();
      expect(find.text('2 / 2'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(_find, findsNothing);
      expect(find.byTooltip('Close expanded response'), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byTooltip('Expand response'), findsOneWidget);
      expect(selected, findsOneWidget);
    },
  );

  testWidgets('copies Pretty and Raw source, with Raw copied from Mind Map', (
    tester,
  ) async {
    final copied = <String>[];
    final messenger = tester.binding.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') {
        copied.add(
          (call.arguments as Map<Object?, Object?>)['text']! as String,
        );
      }
      return null;
    });
    addTearDown(
      () => messenger.setMockMethodCallHandler(SystemChannels.platform, null),
    );
    await _show(tester, _json);
    await tester.tap(find.byTooltip('Copy body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Raw'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy body'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Mind Map'));
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Copy body'));
    await tester.pumpAndSettle();
    expect(copied, [_json.prettyBody, _json.body, _json.body]);
  });

  for (final (name, theme) in [
    ('dark', AppTheme.dark),
    ('light', AppTheme.light),
  ]) {
    testWidgets('keeps actions available in a narrow $name pane', (
      tester,
    ) async {
      await _show(tester, _json, width: 160, theme: theme);
      await tester.tap(find.byTooltip('Body format'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Raw'));
      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Find in response (Ctrl+F)'));
      await tester.pumpAndSettle();
      expect(_find, findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  }
}
