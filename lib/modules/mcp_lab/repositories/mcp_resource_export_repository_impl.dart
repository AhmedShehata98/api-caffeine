import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

import 'mcp_resource_export_repository.dart';

class McpResourceExportRepositoryImpl implements McpResourceExportRepository {
  const McpResourceExportRepositoryImpl();
  @override
  Future<Result<bool>> save(
    Uint8List bytes,
    String fileName,
    String mimeType,
  ) async {
    try {
      final destination = await FilePicker.saveFile(
        fileName: fileName,
        bytes: bytes,
        mimeType: mimeType,
        dialogTitle: 'Save resource',
      );
      return Result.success(destination != null);
    } on Object {
      return const Result.failure(
        StorageFailure(
          'Could not save the resource. Choose another location and try again.',
        ),
      );
    }
  }
}
