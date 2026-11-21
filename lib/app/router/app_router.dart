import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:api_caffeine/app/screens/collection_overview_screen.dart';
import 'package:api_caffeine/app/screens/welcome_screen.dart';
import 'package:api_caffeine/app/shell/app_shell.dart';
import 'package:api_caffeine/modules/environments/environments.dart';
import 'package:api_caffeine/modules/requests/requests.dart';
import 'package:api_caffeine/modules/settings/settings.dart';
import 'package:api_caffeine/modules/mcp_lab/mcp_lab.dart';

final appRouterProvider = Provider<GoRouter>(
  (ref) => GoRouter(
    initialLocation: '/collections',
    routes: [
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: '/collections',
            builder: (context, state) => const WelcomeScreen(),
            routes: [
              GoRoute(
                path: ':id',
                builder: (context, state) => CollectionOverviewScreen(
                  collectionId: state.pathParameters['id']!,
                ),
              ),
            ],
          ),
          ...requestsRoutes,
          ...environmentsRoutes,
          ...mcpLabRoutes,
          ...settingsRoutes,
        ],
      ),
    ],
  ),
);
