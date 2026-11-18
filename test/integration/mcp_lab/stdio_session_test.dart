@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import '../../support/dart_executable.dart';
import 'stdio_session_checks.dart' as checks;

void main() {
  test(
    'live stdio lifecycle and wire-boundary checks',
    () async {
      await checks.runChecks(dart: dartExecutableForTests());
    },
    skip: !const bool.fromEnvironment('MCP_INTEGRATION')
        ? 'Set MCP_INTEGRATION=true for local process fixtures.'
        : null,
  );
}
