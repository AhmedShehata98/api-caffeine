import 'package:flutter_test/flutter_test.dart';

import 'model_checks.dart' as checks;

void main() {
  test('MCP model round trips, defaults and failure kinds', checks.main);
}
