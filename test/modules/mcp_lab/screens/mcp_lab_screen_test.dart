import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:test_point/core/error/result.dart';
import 'package:test_point/core/ui/theme/app_theme.dart';
import 'package:test_point/core/ui/widgets/code_view.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';
import 'package:test_point/modules/mcp_lab/screens/mcp_lab_screen.dart';
import 'package:test_point/modules/mcp_lab/services/mcp_catalog_service.dart';

import '../../../support/pump_app.dart';
import '../../../support/load_bundled_test_fonts.dart';

class _Catalog extends Mock implements McpCatalogService {}

class _Actions extends Mock implements McpSessionActions {}

class _Trust extends Mock implements McpTrustRepository {}

class _Connections extends Mock implements McpConnectionRepository {}

class _LiveSession extends Mock implements McpSession {}

void main() {
  const server = McpServer(
    id: 's',
    workspaceId: 'w',
    draft: McpServerDraft(
      name: 'Weather server',
      transport: McpTransport.stdio,
      command: 'dart',
      args: ['server.dart'],
      env: {'TOKEN': 'secret-canary'},
      secretKeys: ['env.TOKEN'],
    ),
    secretStates: {'env.TOKEN': SecretValueState.present},
  );
  late McpSessionOwner owner;
  late _Catalog catalog;
  late _Actions actions;
  late List<McpServer> rows;
  final boundary = GlobalKey();

  setUpAll(() async {
    registerFallbackValue(server.draft);
    await loadBundledTestFonts();
  });
  setUp(() async {
    owner = McpSessionOwner();
    await owner.switchScope('u', 'w');
    catalog = _Catalog();
    actions = _Actions();
    rows = [server];
    when(() => catalog.list(owner.context!))
        .thenAnswer((_) async => Result.success(List.of(rows)));
  });
  tearDown(() async {
    await owner.dispose();
  });

  Future<void> pump(
    WidgetTester tester, {
    ThemeData? theme,
    double width = 1208,
  }) async {
    tester.view.physicalSize = Size(width, 760);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          mcpSessionOwnerProvider.overrideWithValue(owner),
          mcpCatalogServiceProvider.overrideWithValue(catalog),
          mcpSessionActionsProvider.overrideWithValue(actions),
          mcpLifecycleProvider.overrideWith((_) {}),
        ],
        child: MaterialApp(
          theme: (theme ?? AppTheme.dark).copyWith(
            splashFactory: InkRipple.splashFactory,
          ),
          home: RepaintBoundary(
            key: boundary,
            child: const Scaffold(body: McpLabScreen()),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'server selection, filtering and Ctrl+K work without exposing secrets',
    (tester) async {
      await pump(tester);
      expect(find.text('No servers yet'), findsNothing);
      await tester.tap(find.text('Weather server'));
      await tester.pumpAndSettle();
      expect(find.text('Connection'), findsOneWidget);
      expect(find.textContaining('secret-canary'), findsNothing);
      await tester.sendKeyDownEvent(LogicalKeyboardKey.controlLeft);
      await tester.sendKeyEvent(LogicalKeyboardKey.keyK);
      await tester.sendKeyUpEvent(LogicalKeyboardKey.controlLeft);
      await tester.pump();
      final filter = tester.widget<TextField>(find.byType(TextField).first);
      expect(filter.focusNode!.hasFocus, isTrue);
      await tester.enterText(find.byType(TextField).first, 'missing');
      await tester.pumpAndSettle();
      expect(find.text('No matching servers'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('create requires valid fields and saving never connects', (
    tester,
  ) async {
    when(
      () => catalog.create(
        owner.context!,
        any(),
        confirmedPlaintextHeaders: const {},
      ),
    ).thenAnswer((invocation) async {
      final created = server.copyWith(
        id: 'new',
        draft: invocation.positionalArguments[1] as McpServerDraft,
      );
      rows.add(created);
      return Result.success(created);
    });
    await pump(tester);
    await tester.tap(find.text('Add server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save server'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsWidgets);
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Server name'),
      'Local fixture',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Command'),
      'dart',
    );
    await tester.tap(find.text('Save server'));
    await tester.pumpAndSettle();
    expect(find.text('Add MCP server'), findsNothing);
    expect(rows.last.draft.name, 'Local fixture');
    expect(rows.last.draft.settings.protocolEra, McpProtocolEra.legacy);
    verifyZeroInteractions(actions);
    expect(tester.takeException(), isNull);
  });

  testWidgets('editing masks secrets and account changes close the editor', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Weather server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Edit server'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(
      tester
          .widgetList<TextField>(find.byType(TextField))
          .any((field) => field.obscureText),
      isTrue,
    );
    await tester.runAsync(() => owner.switchScope(null, null));
    await tester.pumpAndSettle();
    expect(find.text('Edit MCP server'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'stdio waits for approval and masks configured secret arguments',
    (tester) async {
      final trust = _Trust();
      final connections = _Connections();
      final target = McpConnectTarget(
        context: owner.context!,
        server: server,
        timeout: const Duration(seconds: 3),
        launch: McpLaunchSnapshot(
          command: 'dart',
          executable: '/bin/dart',
          cwd: '/work',
          args: ['server.dart', 'secret-canary'],
          environment: {'TOKEN': 'secret-canary'},
        ),
      );
      when(() => trust.check(target.context, server.id, target.launch!))
          .thenAnswer(
            (_) async => Result.success(
              McpTrustCheck(approved: false, changedFields: ['args']),
            ),
          );
      final ticket = (await McpConnectService(
        connections,
        trust,
        const McpNegotiationService(clientVersion: '1'),
        isAuthorized: owner.isAuthorized,
      ).connect(target)).valueOrNull!;
      when(() => actions.connect('s'))
          .thenAnswer((_) async => Result.success(ticket));
      when(() => actions.approve('s', remember: false)).thenAnswer(
        (_) async => const Result.failure(
          McpAuthFailure('Fixture stopped after approval'),
        ),
      );
      await pump(tester);
      await tester.tap(find.text('Weather server'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Connect'));
      await tester.pumpAndSettle();
      expect(find.text('Allow local server launch?'), findsOneWidget);
      expect(find.textContaining('secret-canary'), findsNothing);
      expect(find.textContaining('[REDACTED]'), findsOneWidget);
      verifyNever(() => actions.approve('s', remember: false));
      verifyZeroInteractions(connections);
      await tester.tap(find.text('Approve and connect'));
      await tester.pumpAndSettle();
      verify(() => actions.approve('s', remember: false)).called(1);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('delete confirmation cancel does not change the catalog', (
    tester,
  ) async {
    await pump(tester);
    await tester.tap(find.text('Weather server'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(find.text('Delete MCP server'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    verifyNever(() => catalog.delete(owner.context!, 's'));
  });

  testWidgets('app rail navigates to the MCP Lab route', (tester) async {
    await pumpApp(
      tester,
      sampleStore(),
      theme: AppTheme.dark.copyWith(splashFactory: InkRipple.splashFactory),
      extraOverrides: [
        mcpSessionOwnerProvider.overrideWithValue(owner),
        mcpCatalogServiceProvider.overrideWithValue(catalog),
        mcpSessionActionsProvider.overrideWithValue(actions),
        mcpLifecycleProvider.overrideWith((_) {}),
      ],
    );
    await tester.tap(find.text('MCP Lab'));
    await tester.pumpAndSettle();
    expect(find.byType(McpLabScreen), findsOneWidget);
    expect(find.text('MCP servers'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets(
    'connected server exposes Tools and only lists after the tab opens',
    (tester) async {
      final session = _LiveSession();
      when(() => session.status).thenAnswer(
        (_) => Stream.value(
          const ConnectionStatus.connected(
            era: NegotiatedEra.legacy,
            serverInfo: {'name': 'Fixture'},
          ),
        ),
      );
      when(() => session.close())
          .thenAnswer((_) async => const Result.success(null));
      when(() => session.request('tools/list', any())).thenAnswer(
        (_) async => const Result.success({
          'tools': [
            {
              'name': 'add',
              'inputSchema': {'type': 'object'},
            },
          ],
        }),
      );
      await tester.runAsync(
        () => owner.run(
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
        ),
      );
      await pump(tester);
      await tester.tap(find.text('Weather server'));
      await tester.pumpAndSettle();
      verifyNever(() => session.request('tools/list', any()));
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      verify(() => session.request('tools/list', any())).called(1);
      expect(find.text('Select tool'), findsOneWidget);
      await tester.tap(find.byType(DropdownButtonFormField<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('add').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('JSON'));
      await tester.pumpAndSettle();
      tester.widget<CodeView>(find.byType(CodeView)).controller.text = '{';
      await tester.pump();
      await tester.tap(find.text('Settings'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Tools'));
      await tester.pumpAndSettle();
      expect(
        tester.widget<CodeView>(find.byType(CodeView)).controller.text,
        '{',
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'prompt-only server exposes Prompts without requesting until opened',
    (tester) async {
      final session = _LiveSession();
      when(() => session.status).thenAnswer(
        (_) => Stream.value(
          const ConnectionStatus.connected(
            era: NegotiatedEra.legacy,
            serverInfo: {},
          ),
        ),
      );
      when(() => session.close())
          .thenAnswer((_) async => const Result.success(null));
      when(() => session.request('prompts/list', any()))
          .thenAnswer((_) async => const Result.success({'prompts': []}));
      await tester.runAsync(
        () => owner.run(
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
        ),
      );
      await pump(tester);
      await tester.tap(find.text('Weather server'));
      await tester.pumpAndSettle();
      expect(find.text('Tools'), findsNothing);
      verifyNever(() => session.request('prompts/list', any()));
      await tester.tap(find.text('Prompts'));
      await tester.pumpAndSettle();
      verify(() => session.request('prompts/list', any())).called(1);
      expect(
        find.text('This server has no prompts. Refresh to check again.'),
        findsOneWidget,
      );
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets(
    'resource-only server lists resources only after opening the tab',
    (tester) async {
      final session = _LiveSession();
      when(() => session.status).thenAnswer(
        (_) => Stream.value(
          const ConnectionStatus.connected(
            era: NegotiatedEra.legacy,
            serverInfo: {},
          ),
        ),
      );
      when(() => session.close())
          .thenAnswer((_) async => const Result.success(null));
      when(() => session.request('resources/list', any()))
          .thenAnswer((_) async => const Result.success({'resources': []}));
      when(() => session.request('resources/templates/list', any())).thenAnswer(
        (_) async => const Result.success({'resourceTemplates': []}),
      );
      await tester.runAsync(
        () => owner.run(
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
        ),
      );
      await pump(tester);
      await tester.tap(find.text('Weather server'));
      await tester.pumpAndSettle();
      verifyNever(() => session.request('resources/list', any()));
      await tester.tap(find.text('Resources'));
      await tester.pumpAndSettle();
      verify(() => session.request('resources/list', any())).called(1);
      verify(() => session.request('resources/templates/list', any()))
          .called(1);
      expect(find.text('Resources (0)'), findsOneWidget);
      expect(find.text('Templates (0)'), findsOneWidget);
      expect(tester.takeException(), isNull);
    },
  );

  testWidgets('HTTP summary hides credential query values', (tester) async {
    rows = [
      server.copyWith(
        draft: const McpServerDraft(
          name: 'Remote server',
          transport: McpTransport.http,
          url: 'https://example.test/mcp?token=query-canary',
        ),
      ),
    ];
    await pump(tester);
    await tester.tap(find.text('Remote server'));
    await tester.pumpAndSettle();
    expect(find.textContaining('query-canary'), findsNothing);
    expect(find.textContaining('[REDACTED]'), findsOneWidget);
  });

  for (final light in [false, true]) {
    testWidgets(
      '${light ? 'light' : 'dark'} settings fit desktop minimum width',
      (tester) async {
        await pump(
          tester,
          theme: light ? AppTheme.light : AppTheme.dark,
          width: 952,
        );
        await tester.tap(find.text('Weather server'));
        await tester.pumpAndSettle();
        expect(tester.takeException(), isNull);
        if (const bool.fromEnvironment('MCP_UI_SCREENSHOTS')) {
          await tester.runAsync(() async {
            final image =
                await (boundary.currentContext!.findRenderObject()
                        as RenderRepaintBoundary)
                    .toImage();
            final data = await image.toByteData(format: ui.ImageByteFormat.png);
            await File('.dart_tool/mcp_ui_${light ? 'light' : 'dark'}.png')
                .writeAsBytes(data!.buffer.asUint8List());
            image.dispose();
          });
        }
      },
    );
  }
}
