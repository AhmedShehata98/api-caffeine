import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:api_caffeine/app/app.dart';
import 'package:api_caffeine/app/di/app_overrides.dart';
import 'package:api_caffeine/app/services/desktop_close_handler.dart';
import 'package:api_caffeine/core/database/supabase_config.dart';
import 'package:window_manager/window_manager.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    _configureWindow();
  }

  if (!SupabaseConfig.isConfigured) {
    runApp(const _MissingConfigApp());
    return;
  }
  await Supabase.initialize(
    url: SupabaseConfig.url,
    publishableKey: SupabaseConfig.anonKey,
  );
  final preferences = await SharedPreferences.getInstance();
  final container = ProviderContainer(overrides: appOverrides(preferences));
  if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
    installDesktopCloseHandler(container);
  }
  runApp(UncontrolledProviderScope(container: container, child: const App()));
}

void _configureWindow() {
  final window = WindowManager.instance.getCurrent();
  if (window == null) return;
  window.title = 'API Caffeine';
  window.minimumSize = const Size(1024, 640).toNative();
  window.setSize(const Size(1280, 800).toNative(), false);
  window.center();
  window.show();
}

/// Shown when the app is started without the Supabase `--dart-define` values.
class _MissingConfigApp extends StatelessWidget {
  const _MissingConfigApp();

  @override
  Widget build(BuildContext context) {
    return const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: Scaffold(
        body: Center(
          child: Text(
            'Missing SUPABASE_URL / SUPABASE_ANON_KEY. '
            'Run with --dart-define (see agents.md).',
          ),
        ),
      ),
    );
  }
}
