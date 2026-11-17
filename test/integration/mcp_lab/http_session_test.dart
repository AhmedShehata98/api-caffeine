@Tags(['integration'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'http_session_checks.dart' as checks;

void main() {
  test(
    'live HTTP lifecycle and diagnostic checks',
    checks.main,
    skip: !const bool.fromEnvironment('MCP_INTEGRATION')
        ? 'Set MCP_INTEGRATION=true for local HTTP fixtures.'
        : null,
  );
}
