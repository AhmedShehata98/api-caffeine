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
import 'package:test_point/modules/mcp_lab/repositories/mcp_resource_export_repository.dart';
import 'package:test_point/modules/mcp_lab/widgets/mcp_content_block_view.dart';

import '../../../support/load_bundled_test_fonts.dart';

class _Session implements McpSession {
  @override
  Future<Result<void>> close() async => const Result.success(null);
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _Exports implements McpResourceExportRepository {
  final bytes = <Uint8List>[];
  @override
  Future<Result<bool>> save(Uint8List data, String name, String mime) async {
    bytes.add(data);
    return const Result.success(true);
  }
}

void main() {
  late String png;
  setUpAll(() async {
    await loadBundledTestFonts();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 200, 100),
      Paint()..color = const Color(0xffff6a00),
    );
    canvas.drawCircle(const Offset(100, 50), 30, Paint()..color = Colors.white);
    final picture = recorder.endRecording();
    final image = await picture.toImage(200, 100);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    png = base64Encode(data!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  late McpSessionOwner owner;
  late _Exports exports;
  bool opened = false;
  String? copied;
  final boundary = GlobalKey();
  setUp(() async {
    owner = McpSessionOwner();
    await owner.switchScope('u', 'w');
    await owner.run(
      's',
      (_) async => Result.success(
        McpConnected(
          _Session(),
          McpNegotiation(
            era: NegotiatedEra.legacy,
            version: '2025-11-25',
            discovery: {
              'capabilities': {'tools': {}, 'prompts': {}, 'resources': {}},
            },
          ),
        ),
      ),
    );
    exports = _Exports();
    opened = false;
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
  Future<void> finish(WidgetTester tester) async {
    await tester.pump();
    for (var i = 0; i < 100; i++) {
      if (i > 2 &&
          find.byType(LinearProgressIndicator).evaluate().isEmpty &&
          find.byType(CircularProgressIndicator).evaluate().isEmpty) {
        break;
      }
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  Future<void> pump(
    WidgetTester tester,
    ContentBlock block, {
    McpContentOrigin origin = McpContentOrigin.tool,
    bool light = false,
    bool resources = true,
  }) async {
    final work = owner.workFor('s')!;
    await tester.runAsync(() async {
      if (origin == McpContentOrigin.tool) {
        await work.tools.run(
          (_) async => Result.success(
            McpToolCall(ToolCallResult(content: [block]), {
              'content': [block.toJson()],
            }),
          ),
        );
      } else {
        await work.prompts.run(
          (_) async => Result.success(
            McpPromptResult([
              PromptMessage(role: PromptRole.user, content: block),
            ], null),
          ),
        );
      }
    });
    tester.view.physicalSize = const Size(800, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpSessionOwnerProvider.overrideWithValue(owner),
          mcpResourceExportRepositoryProvider.overrideWithValue(exports),
          if (!resources)
            mcpCanOpenResourceProvider('s').overrideWithValue(false),
        ],
        child: MaterialApp(
          theme: (light ? AppTheme.light : AppTheme.dark).copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: Scaffold(
              body: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: McpContentBlockView(
                  serverId: 's',
                  origin: origin,
                  block: block,
                  onOpenResources: () => opened = true,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await finish(tester);
  }

  for (final origin in [McpContentOrigin.tool, McpContentOrigin.prompt]) {
    testWidgets(
      '${origin.name} audio exposes MIME, decoded size and an owned Save action',
      (tester) async {
        await pump(
          tester,
          const ContentBlock.audio(data: 'AID/AA==', mimeType: 'audio/wav'),
          origin: origin,
        );
        expect(find.text('Audio'), findsOneWidget);
        expect(find.text('audio/wav'), findsOneWidget);
        expect(find.text('Binary resource · 4 bytes'), findsOneWidget);
        expect(exports.bytes, isEmpty);
        await tester.tap(find.text('Save resource'));
        await finish(tester);
        expect(exports.bytes.single, [0, 128, 255, 0]);
        expect(find.text('Resource saved.'), findsOneWidget);
      },
    );
  }
  testWidgets(
    'embedded JSON is formatted while Copy preserves the original text',
    (tester) async {
      await pump(
        tester,
        const ContentBlock.resource(
          resource: ResourceContents(
            uri: 'fixture://json',
            mimeType: 'application/json',
            text: '{"v":1}',
          ),
        ),
      );
      expect(
        tester.widget<CodeView>(find.byType(CodeView)).controller.text,
        '{\n  "v": 1\n}',
      );
      await tester.tap(find.text('Copy resource text'));
      await tester.pump();
      expect(copied, '{"v":1}');
    },
  );
  testWidgets('embedded prompt binary is saved with prompt ownership', (
    tester,
  ) async {
    await pump(
      tester,
      const ContentBlock.resource(
        resource: ResourceContents(uri: 'fixture://bytes', blob: 'AID/AA=='),
      ),
      origin: McpContentOrigin.prompt,
    );
    await tester.tap(find.text('Save resource'));
    await finish(tester);
    expect(exports.bytes.single, [0, 128, 255, 0]);
  });
  testWidgets(
    'resource link opens a URI draft without reading or replacing the result',
    (tester) async {
      await pump(
        tester,
        const ContentBlock.resourceLink(
          uri: 'weather://lisbon',
          name: 'Forecast',
        ),
      );
      final outcome = owner.workFor('s')!.tools.state.outcome;
      await tester.tap(find.text('Open in Resources'));
      await tester.pump();
      expect(opened, isTrue);
      expect(owner.workFor('s')!.resources.state.draft, 'weather://lisbon');
      expect(owner.workFor('s')!.resources.state.outcome, isNull);
      expect(
        identical(owner.workFor('s')!.tools.state.outcome, outcome),
        isTrue,
      );
    },
  );
  testWidgets(
    'resource link is disabled when the server cannot read resources',
    (tester) async {
      await pump(
        tester,
        const ContentBlock.resourceLink(
          uri: 'weather://lisbon',
          name: 'Forecast',
        ),
        resources: false,
      );
      expect(
        tester
            .widget<TextButton>(
              find.widgetWithText(TextButton, 'Open in Resources'),
            )
            .onPressed,
        isNull,
      );
      expect(opened, isFalse);
    },
  );
  testWidgets('cleared tool content cannot be exported by a lingering widget', (
    tester,
  ) async {
    await pump(
      tester,
      const ContentBlock.audio(data: 'AID/AA==', mimeType: 'audio/wav'),
    );
    owner.workFor('s')!.tools.clearResult();
    await tester.tap(find.text('Save resource'));
    await finish(tester);
    expect(exports.bytes, isEmpty);
    expect(find.text('Resource saved.'), findsNothing);
  });
  testWidgets(
    'large text previews avoid splitting Unicode and offer a read-only full inspector',
    (tester) async {
      final text = '${'x' * 4095}😀';
      await pump(tester, ContentBlock.text(text: text));
      expect(
        tester.widget<SelectableText>(find.byType(SelectableText)).data!.length,
        4095,
      );
      await tester.ensureVisible(find.text('Inspect full text'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Inspect full text'));
      await finish(tester);
      expect(
        tester.widget<CodeView>(find.byType(CodeView)).controller.text,
        text,
      );
    },
  );
  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} result image renders with the current theme',
      (tester) async {
        await pump(
          tester,
          ContentBlock.image(data: png, mimeType: 'image/png'),
          light: light,
        );
        expect(find.byType(Image), findsOneWidget);
        expect(find.byType(CircularProgressIndicator), findsNothing);
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
            await File('.dart_tool/mcp_rich_${light ? 'light' : 'dark'}.png')
                .writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.tap(find.text('Save resource'));
        await finish(tester);
        expect(base64Encode(exports.bytes.single), png);
      },
    );
  }
}
