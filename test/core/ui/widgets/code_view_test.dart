import 'package:api_caffeine/core/ui/theme/app_theme.dart';
import 'package:api_caffeine/core/ui/widgets/code_view.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:re_editor/re_editor.dart';

void main() {
  for (final theme in [AppTheme.dark, AppTheme.light]) {
    testWidgets(
      'colors JSON as it is edited in ${theme.brightness.name} mode',
      (tester) async {
        const tokens = {'"name"', '"coffee"', '42', 'true', 'false', 'null'};
        final colors = <String, Color>{};
        final controller = CodeLineEditingController(
          spanBuilder:
              ({
                required context,
                required index,
                required codeLine,
                required textSpan,
                required style,
              }) {
                textSpan.visitChildren((span) {
                  if (span is TextSpan && tokens.contains(span.text)) {
                    final color = span.style?.color;
                    if (color != null) colors[span.text!] = color;
                  }
                  return true;
                });
                return textSpan;
              },
        );
        addTearDown(controller.dispose);
        await tester.pumpWidget(
          MaterialApp(
            theme: theme,
            home: Scaffold(
              body: CodeView(controller: controller, highlightJson: true),
            ),
          ),
        );

        controller.text =
            '{"name":"coffee","count":42,"flags":[true,false,null]}';
        // ReEditor's worker isolate returns the styled spans asynchronously.
        for (
          var attempt = 0;
          attempt < 100 && colors.length < tokens.length;
          attempt++
        ) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 20)),
          );
          await tester.pump();
        }

        expect(colors.keys, unorderedEquals(tokens));
        expect({
          colors['"name"'],
          colors['"coffee"'],
          colors['42'],
          colors['true'],
        }, hasLength(4));
        expect(colors['false'], colors['true']);
        expect(colors['null'], colors['true']);
        await tester.pumpWidget(const SizedBox.shrink());
      },
    );
  }
}
