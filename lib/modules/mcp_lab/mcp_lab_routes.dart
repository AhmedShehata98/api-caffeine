import 'package:go_router/go_router.dart';

import 'screens/mcp_lab_screen.dart';

final mcpLabRoutes = <RouteBase>[
  GoRoute(path: '/mcp-lab', builder: (context, state) => const McpLabScreen()),
];
