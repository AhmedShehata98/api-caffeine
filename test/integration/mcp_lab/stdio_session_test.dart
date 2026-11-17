@Tags(['integration'])
library;

import 'dart:io';
import 'dart:isolate';

import 'package:flutter_test/flutter_test.dart';

import 'stdio_session_checks.dart' as checks;

void main() {
  test(
    'live stdio lifecycle and wire-boundary checks',
    () async {
      final uri = await Isolate.resolvePackageUri(
        Uri.parse('package:flutter/widgets.dart'),
      );
      final root = File.fromUri(uri!).parent.parent.parent.parent;
      await checks.runChecks(
        dart:
            '${root.path}/bin/cache/dart-sdk/bin/${Platform.isWindows ? 'dart.exe' : 'dart'}',
      );
    },
    skip: !const bool.fromEnvironment('MCP_INTEGRATION')
        ? 'Set MCP_INTEGRATION=true for local process fixtures.'
        : null,
  );
}
