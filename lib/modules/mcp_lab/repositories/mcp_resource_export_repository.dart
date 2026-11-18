import 'dart:typed_data';

import 'package:test_point/core/error/result.dart';

abstract interface class McpResourceExportRepository {
  /// Opens the native save dialog; false means the user cancelled.
  Future<Result<bool>> save(Uint8List bytes, String fileName, String mimeType);
}
