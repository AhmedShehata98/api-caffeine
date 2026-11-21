import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:api_caffeine/app/di/app_overrides.dart';
import 'package:api_caffeine/app/router/app_router.dart';
import 'package:api_caffeine/core/ui/theme/app_theme.dart';
import 'package:api_caffeine/modules/auth/auth.dart';
import 'package:api_caffeine/modules/collections/collections.dart';
import 'package:api_caffeine/modules/requests/requests.dart';
import 'package:api_caffeine/modules/settings/settings.dart';

import 'fake_backend.dart';

/// Sample workspace: two collections, three requests.
FakeStore sampleStore() => FakeStore(
  collections: [
    const Collection(id: 'c1', workspaceId: 'ws-1', name: 'Users API'),
    const Collection(
      id: 'c2',
      workspaceId: 'ws-1',
      name: 'Billing',
      position: 1,
    ),
  ],
  requests: [
    const SavedRequest(
      id: 'r1',
      collectionId: 'c1',
      name: 'List users',
      draft: HttpRequestDraft(url: 'https://a.test/users'),
    ),
    const SavedRequest(
      id: 'r2',
      collectionId: 'c1',
      name: 'Create user',
      position: 1,
      draft: HttpRequestDraft(
        method: HttpMethod.post,
        url: 'https://a.test/users',
      ),
    ),
    const SavedRequest(
      id: 'r3',
      collectionId: 'c2',
      name: 'List invoices',
      draft: HttpRequestDraft(url: 'https://a.test/invoices'),
    ),
  ],
);

/// Pumps the whole app (router, shell, sidebar) on top of [store].
/// Returns the container so tests can inspect state.
Future<ProviderContainer> pumpApp(
  WidgetTester tester,
  FakeStore store, {
  ThemeData? theme,
  List<Override> extraOverrides = const [],
  SettingsRepository? settings,
  AuthRepository? auth,
}) async {
  tester.view.physicalSize = const Size(1280, 800);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        ...fakeBackend(store: store, settings: settings, auth: auth),
        ...appOverrides(preferences),
        ...extraOverrides,
      ],
      child: Consumer(
        builder: (context, ref, _) => MaterialApp.router(
          theme: theme ?? AppTheme.dark,
          routerConfig: ref.watch(appRouterProvider),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
  return ProviderScope.containerOf(tester.element(find.byType(MaterialApp)));
}
