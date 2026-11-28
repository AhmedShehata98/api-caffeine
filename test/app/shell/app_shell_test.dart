import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:api_caffeine/app/router/app_router.dart';
import 'package:api_caffeine/app/shell/nav_rail.dart';
import 'package:api_caffeine/app/shell/sidebar/sidebar.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';
import 'package:api_caffeine/core/ui/theme/app_theme.dart';
import 'package:api_caffeine/modules/auth/auth.dart';
import 'package:api_caffeine/modules/workspaces/workspaces.dart';

import '../../support/fake_backend.dart';

Widget _app(ThemeData theme, {List<Override>? overrides}) => ProviderScope(
  overrides: overrides ?? fakeBackend(),
  child: Consumer(
    builder: (context, ref, _) => MaterialApp.router(
      theme: theme,
      routerConfig: ref.watch(appRouterProvider),
    ),
  ),
);

void _useDesktopSize(WidgetTester tester) {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

void main() {
  for (final entry in {
    'dark': AppTheme.dark,
    'light': AppTheme.light,
  }.entries) {
    testWidgets('shell shows welcome screen (${entry.key})', (tester) async {
      _useDesktopSize(tester);

      await tester.pumpWidget(_app(entry.value));
      await tester.pumpAndSettle();

      expect(find.text('Welcome to API Caffeine'), findsOneWidget);
      for (final section in [ShellNavRail, ShellSidebar]) {
        expect(
          find.descendant(
            of: find.byType(section),
            matching: find.text('Collections'),
          ),
          findsOneWidget,
        );
      }
      expect(find.text('Proxy: Off'), findsOneWidget);
    });
  }

  testWidgets('nav rail navigates to Settings', (tester) async {
    _useDesktopSize(tester);

    await tester.pumpWidget(_app(AppTheme.dark));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Settings'));
    await tester.pumpAndSettle();

    expect(find.byType(SegmentedButton<ThemeMode>), findsOneWidget);
    expect(find.text('Follow redirects'), findsOneWidget);
  });

  testWidgets('shows a spinner while the workspace loads', (tester) async {
    _useDesktopSize(tester);
    final pending = Completer<Result<Workspace>>();
    final workspaces = MockWorkspaceRepository();
    when(() => workspaces.loadDefault()).thenAnswer((_) => pending.future);

    await tester.pumpWidget(
      _app(AppTheme.dark, overrides: fakeBackend(workspaces: workspaces)),
    );
    await tester.pump();

    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Welcome to API Caffeine'), findsNothing);
  });

  testWidgets('shows the failure and retries loading the workspace', (
    tester,
  ) async {
    _useDesktopSize(tester);
    final workspaces = stubWorkspaces(
      const Result.failure(NetworkFailure('Cannot reach the server.')),
    );

    await tester.pumpWidget(
      _app(AppTheme.dark, overrides: fakeBackend(workspaces: workspaces)),
    );
    await tester.pumpAndSettle();

    expect(find.text('Cannot reach the server.'), findsOneWidget);

    when(() => workspaces.loadDefault())
        .thenAnswer((_) async => const Result.success(testWorkspace));
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Welcome to API Caffeine'), findsOneWidget);
  });

  testWidgets('avatar shows a guest icon, then the initial when signed in', (
    tester,
  ) async {
    _useDesktopSize(tester);

    await tester.pumpWidget(_app(AppTheme.dark));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.person_outline), findsOneWidget);

    const account = AuthUser(id: 'u2', isAnonymous: false, email: 'ann@x.co');
    await tester.pumpWidget(
      _app(
        AppTheme.dark,
        overrides: fakeBackend(auth: stubAuth(user: account)),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('A'), findsOneWidget);
  });
}
