import 'dart:async';
import 'dart:convert';
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
import 'package:test_point/modules/mcp_lab/repositories/mcp_resource_export_repository.dart';

import '../../../support/load_bundled_test_fonts.dart';

class _Session implements McpSession {
  final calls = <(String, Map<String, dynamic>)>[];
  String text = '{"city":"Lisbon","temperature":19}';
  bool fail = false;
  String binaryMime = 'application/octet-stream';
  String blob = 'AID/AA==';
  String uriTemplate = 'weather://{city}';
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
      return Result.success({
        'resourceTemplates': [
          {
            'name': 'City template',
            'uriTemplate': uriTemplate,
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
          {'uri': 'weather://bytes', 'mimeType': binaryMime, 'blob': blob}
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

class _ExportRepository implements McpResourceExportRepository {
  final calls = <(Uint8List, String, String)>[];
  Future<Result<bool>> Function()? respond;
  @override
  Future<Result<bool>> save(Uint8List bytes, String name, String mime) async {
    calls.add((bytes, name, mime));
    return respond == null ? const Result.success(true) : respond!();
  }
}

void main() {
  late String imageBlob;
  setUpAll(() async {
    await loadBundledTestFonts();
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    canvas.drawRect(
      const Rect.fromLTWH(0, 0, 240, 120),
      Paint()..color = const Color(0xffdff5f1),
    );
    for (var index = 0; index < 6; index++) {
      canvas.drawRect(
        Rect.fromLTWH(
          20 + index * 35,
          100 - (index + 1) * 12,
          20,
          (index + 1) * 12,
        ),
        Paint()..color = const Color(0xff0f9d8a),
      );
    }
    final picture = recorder.endRecording();
    final image = await picture.toImage(240, 120);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    imageBlob = base64Encode(bytes!.buffer.asUint8List());
    image.dispose();
    picture.dispose();
  });
  late McpSessionOwner owner;
  late _Session session;
  late _ExportRepository exports;
  final boundary = GlobalKey();
  setUp(() async {
    session = _Session();
    exports = _ExportRepository();
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
        overrides: [
          mcpSessionOwnerProvider.overrideWithValue(owner),
          mcpResourceExportRepositoryProvider.overrideWithValue(exports),
        ],
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
          (i < 3 ||
              find.byType(LinearProgressIndicator).evaluate().isNotEmpty ||
              find.byType(CircularProgressIndicator).evaluate().isNotEmpty);
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
    await tester.pump();
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
    'template arguments expand without reading and manual editing overrides expansion',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Templates (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City template'));
      await tester.pump();
      await tester.tap(find.text('Include city'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'city'),
        'Lisbon 😀',
      );
      await tester.pump();
      expect(session.calls.where((c) => c.$1 == 'resources/read'), isEmpty);
      expect(
        tester
            .widget<TextField>(find.widgetWithText(TextField, 'Resource URI'))
            .controller!
            .text,
        'weather://Lisbon%20%F0%9F%98%80',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Resource URI'),
        'weather://lisbon',
      );
      await read(tester);
      expect(session.calls.last.$2, {'uri': 'weather://lisbon'});
      expect(find.text('Template arguments'), findsNothing);
    },
  );
  testWidgets(
    'template draft restores and scope changes remove its arguments',
    (tester) async {
      await pump(tester);
      await tester.tap(find.text('Templates (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City template'));
      await tester.pump();
      await tester.tap(find.text('Include city'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextFormField, 'city'),
        'private city',
      );
      await tester.pumpWidget(const SizedBox());
      await pump(tester);
      expect(find.text('Template arguments'), findsOneWidget);
      expect(
        tester
            .widget<TextFormField>(find.widgetWithText(TextFormField, 'city'))
            .initialValue,
        'private city',
      );
      final work = owner.workFor('s')!;
      expect(work.resourceTemplate.state.draft!.values['city'], 'private city');
      await tester.runAsync(() => owner.switchScope('other', 'w'));
      await tester.pumpAndSettle();
      expect(find.text('Template arguments'), findsNothing);
      expect(work.resourceTemplate.state.draft, isNull);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets(
    'omitted and empty query values expand differently and only Read sends',
    (tester) async {
      session.uriTemplate = 'weather://city{?q}';
      await pump(tester);
      await tester.tap(find.text('Templates (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City template'));
      await tester.pump();
      final uri = find.widgetWithText(TextField, 'Resource URI');
      expect(tester.widget<TextField>(uri).controller!.text, 'weather://city');
      await tester.tap(find.text('Include q'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<TextField>(uri).controller!.text,
        'weather://city?q=',
      );
      await tester.enterText(find.widgetWithText(TextFormField, 'q'), 'a&b+c');
      await tester.pump();
      expect(session.calls.where((c) => c.$1 == 'resources/read'), isEmpty);
      await read(tester);
      expect(session.calls.last.$2, {'uri': 'weather://city?q=a%26b%2Bc'});
    },
  );
  testWidgets(
    'invalid template offers manual URI fallback and cannot send unresolved syntax',
    (tester) async {
      session.uriTemplate = 'weather://{city:0}';
      await pump(tester);
      await tester.tap(find.text('Templates (1)'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('City template'));
      await tester.pump();
      expect(
        find.textContaining('Enter a resolved URI instead.'),
        findsOneWidget,
      );
      final button = tester.widget<FilledButton>(
        find.widgetWithText(FilledButton, 'Read resource · Ctrl+Enter'),
      );
      expect(button.onPressed, isNull);
      await tester.enterText(
        find.widgetWithText(TextField, 'Resource URI'),
        'weather://resolved',
      );
      await read(tester);
      expect(session.calls.last.$2, {'uri': 'weather://resolved'});
    },
  );
  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} template form renders without overflow',
      (tester) async {
        session.uriTemplate = 'weather://city/{city}{?units}';
        await pump(tester, light: light);
        await tester.tap(find.text('Templates (1)'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('City template'));
        await tester.pump();
        await tester.tap(find.text('Include city'));
        await tester.pumpAndSettle();
        await tester.enterText(
          find.widgetWithText(TextFormField, 'city'),
          'Lisbon',
        );
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
            await File(
              '.dart_tool/mcp_template_${light ? 'light' : 'dark'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
      },
    );
  }
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
  testWidgets('Save exports exact binary bytes only on explicit action', (
    tester,
  ) async {
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'weather://bytes');
    await read(tester);
    expect(exports.calls, isEmpty);
    await tester.tap(find.text('Save resource'));
    await finish(tester);
    expect(exports.calls.single.$1, [0, 128, 255, 0]);
    expect(exports.calls.single.$2, 'resource.bin');
    expect(find.text('Resource saved.'), findsOneWidget);
  });
  testWidgets('cancel is silent and storage failure allows retry', (
    tester,
  ) async {
    exports.respond = () async => const Result.success(false);
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'weather://bytes');
    await read(tester);
    await tester.tap(find.text('Save resource'));
    await finish(tester);
    expect(find.text('Resource saved.'), findsNothing);
    exports.respond = () async =>
        const Result.failure(StorageFailure('Choose another location.'));
    await tester.tap(find.text('Save resource'));
    await finish(tester);
    expect(find.text('Choose another location.'), findsOneWidget);
    expect(find.text('Save resource'), findsOneWidget);
  });
  testWidgets(
    'scope change removes a pending export and ignores late completion',
    (tester) async {
      final pending = Completer<Result<bool>>();
      exports.respond = () => pending.future;
      await pump(tester);
      await tester.enterText(find.byType(TextField).first, 'weather://bytes');
      await read(tester);
      await tester.tap(find.text('Save resource'));
      for (var i = 0; i < 100 && exports.calls.isEmpty; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
      expect(exports.calls.length, 1);
      expect(find.text('Saving resource…'), findsOneWidget);
      await tester.runAsync(() => owner.switchScope('other', 'w'));
      pending.complete(const Result.success(true));
      await finish(tester);
      expect(find.text('Resource saved.'), findsNothing);
      expect(find.text('Save resource'), findsNothing);
      expect(tester.takeException(), isNull);
    },
  );
  testWidgets('malformed base64 cannot expose a Save action', (tester) async {
    session.blob = '***';
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'weather://bytes');
    await read(tester);
    expect(find.textContaining('invalid base64'), findsOneWidget);
    expect(find.text('Save resource'), findsNothing);
    expect(exports.calls, isEmpty);
  });
  testWidgets('invalid image shows fallback while keeping Save available', (
    tester,
  ) async {
    session.binaryMime = 'image/png';
    await pump(tester);
    await tester.enterText(find.byType(TextField).first, 'weather://bytes');
    await read(tester);
    expect(
      find.textContaining('Could not display this image.'),
      findsOneWidget,
    );
    expect(find.text('Save resource'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} inline image renders and leaves no cached preview on disposal',
      (tester) async {
        session.binaryMime = 'image/png';
        session.blob = imageBlob;
        await pump(tester, light: light);
        await tester.enterText(find.byType(TextField).first, 'weather://bytes');
        await read(tester);
        expect(
          find.textContaining('Could not display this image.'),
          findsNothing,
        );
        expect(find.byType(CircularProgressIndicator), findsNothing);
        final image = tester.widget<Image>(find.byType(Image));
        expect(image.semanticLabel, 'Image resource preview');
        expect(tester.widget<RawImage>(find.byType(RawImage)).image, isNotNull);
        final decoded = tester.widget<RawImage>(find.byType(RawImage)).image!;
        await tester.runAsync(() async {
          final pixels = await decoded.toByteData(
            format: ui.ImageByteFormat.rawRgba,
          );
          final sample =
              ((decoded.height ~/ 2) * decoded.width +
                  (decoded.width * 0.875).floor()) *
              4;
          expect(pixels!.buffer.asUint8List().sublist(sample, sample + 3), [
            15,
            157,
            138,
          ]);
        });
        // Let the raster thread finish the decoded frame before capturing it.
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 50)),
        );
        await tester.pump(const Duration(milliseconds: 100));
        boundary.currentContext!.findRenderObject()!.markNeedsPaint();
        await tester.pump();
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
              '.dart_tool/mcp_resource_image_${light ? 'light' : 'dark'}.png',
            ).writeAsBytes(bytes!.buffer.asUint8List());
            rendered.dispose();
          });
        }
        await tester.pumpWidget(const SizedBox());
        await tester.pump();
        final key = await image.image.obtainKey(ImageConfiguration.empty);
        expect(PaintingBinding.instance.imageCache.containsKey(key), isFalse);
        expect(tester.takeException(), isNull);
      },
    );
  }
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
