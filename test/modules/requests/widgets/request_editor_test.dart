import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/modules/requests/models/send_state.dart';
import 'package:api_caffeine/modules/requests/models/schema_test_result.dart';
import 'package:api_caffeine/modules/requests/widgets/response_schema_tab.dart';
import 'package:re_editor/re_editor.dart';
import 'package:api_caffeine/modules/requests/requests.dart';

import '../../../support/pump_app.dart';

void main() {
  testWidgets(
    'schema editor retains its source when disabled and recovery focuses it',
    (tester) async {
      final container = await pumpApp(tester, sampleStore());
      await tester.tap(find.text('New request').first);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Test').last);
      await tester.pumpAndSettle();
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      final editor = tester.widget<CodeEditor>(
        find.descendant(
          of: find.byType(ResponseSchemaTab),
          matching: find.byType(CodeEditor),
        ),
      );
      editor.controller!.text = '{"type":"object"}';
      await tester.pumpAndSettle();
      expect(
        container.read(requestDraftProvider).responseSchemaEnabled,
        isTrue,
      );
      await tester.tap(find.byType(SwitchListTile));
      await tester.pumpAndSettle();
      expect(
        container.read(requestDraftProvider).responseSchemaSource,
        '{"type":"object"}',
      );
      final tabs = container.read(requestTabsProvider.notifier);
      tabs.setSendState(
        container.read(requestTabsProvider).activeId!,
        const SendSuccess(
          HttpResponseResult(
            statusCode: 200,
            headers: {},
            body: '{}',
            duration: Duration.zero,
            sizeBytes: 2,
          ),
          schemaTest: SchemaTestResult(
            status: SchemaTestStatus.invalidSchema,
            schemaSource: '{"type":"object"}',
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Params'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit schema'));
      await tester.pumpAndSettle();
      expect(find.byType(ResponseSchemaTab), findsOneWidget);
      expect(
        tester
            .widget<CodeEditor>(
              find.descendant(
                of: find.byType(ResponseSchemaTab),
                matching: find.byType(CodeEditor),
              ),
            )
            .focusNode!
            .hasFocus,
        isTrue,
      );
    },
  );

  testWidgets('Send shows the Ctrl+Enter hint', (tester) async {
    await pumpApp(tester, sampleStore());
    await tester.tap(find.text('New request').first);
    await tester.pumpAndSettle();

    expect(find.text('Ctrl+Enter'), findsOneWidget);
  });

  testWidgets('Params and Headers tabs count their enabled rows', (
    tester,
  ) async {
    final container = await pumpApp(tester, sampleStore());
    await tester.tap(find.text('New request').first);
    await tester.pumpAndSettle();
    expect(
      find.descendant(of: find.byType(Tab), matching: find.text('0')),
      findsNothing,
    );

    container.read(requestDraftProvider.notifier).setParams(const [
      KeyValue(key: 'limit', value: '20'),
      KeyValue(key: 'off', value: '1', enabled: false),
      KeyValue(key: '', value: 'ignored'),
    ]);
    container.read(requestDraftProvider.notifier).setHeaders(const [
      KeyValue(key: 'Accept', value: 'json'),
    ]);
    await tester.pumpAndSettle();

    expect(
      find.descendant(
        of: find.widgetWithText(Tab, 'Params'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
    expect(
      find.descendant(
        of: find.widgetWithText(Tab, 'Headers'),
        matching: find.text('1'),
      ),
      findsOneWidget,
    );
  });

  testWidgets('a failed request shows the reason and a Retry button', (
    tester,
  ) async {
    final container = await pumpApp(tester, sampleStore());
    await tester.tap(find.text('New request').first);
    await tester.pumpAndSettle();
    final tabs = container.read(requestTabsProvider.notifier);
    tabs.setSendState(
      container.read(requestTabsProvider).activeId!,
      const SendFailed(NetworkFailure('Request timed out.')),
    );
    await tester.pumpAndSettle();

    expect(find.text('Request failed'), findsOneWidget);
    expect(find.text('Request timed out.'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('Save preselects the first collection when one exists', (
    tester,
  ) async {
    await pumpApp(tester, sampleStore());
    await tester.tap(find.text('New request').first);
    await tester.pumpAndSettle();
    await tester.tap(find.byTooltip('Save (Ctrl+S)'));
    await tester.pumpAndSettle();

    final dialog = find.byType(AlertDialog);
    expect(
      find.descendant(of: dialog, matching: find.text('Users API')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: dialog, matching: find.text('Collection name')),
      findsNothing,
    );
  });

  testWidgets('Bulk Edit edits the rows as text and back', (tester) async {
    final container = await pumpApp(tester, sampleStore());
    await tester.tap(find.text('New request').first);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Bulk Edit'));
    await tester.pumpAndSettle();
    await tester.enterText(
      find.byType(TextField).last,
      'limit: 20\n# debug: 1',
    );
    await tester.pumpAndSettle();

    expect(container.read(requestDraftProvider).params, const [
      KeyValue(key: 'limit', value: '20'),
      KeyValue(key: 'debug', value: '1', enabled: false),
    ]);

    await tester.tap(find.text('Key-Value Edit'));
    await tester.pumpAndSettle();
    expect(find.text('limit'), findsOneWidget);
    expect(find.text('debug'), findsOneWidget);
  });
}
