import 'dart:io';

/// Finds the Dart SDK alongside the Flutter test runner for process fixtures.
String dartExecutableForTests() {
  final override = Platform.environment['DART_EXECUTABLE'];
  if (override != null && override.isNotEmpty) return override;

  final executable = File(Platform.resolvedExecutable);
  final dartName = Platform.isWindows ? 'dart.exe' : 'dart';
  if (executable.uri.pathSegments.last == dartName) return executable.path;

  var directory = executable.parent;
  while (true) {
    final dart = File('${directory.path}/bin/cache/dart-sdk/bin/$dartName');
    if (dart.existsSync()) return dart.path;

    final parent = directory.parent;
    if (parent.path == directory.path) break;
    directory = parent;
  }
  throw StateError(
    'Dart SDK not found. Set DART_EXECUTABLE to its executable.',
  );
}
