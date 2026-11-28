import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:api_caffeine/core/error/failure.dart';
import 'package:api_caffeine/core/error/result.dart';

import '../models/mcp_protocol_models.dart';
import '../repositories/mcp_resource_export_repository.dart';

Future<Uint8List> _decode(String blob) => Isolate.run(() => base64Decode(blob));

class McpResourceExportService {
  const McpResourceExportService(this.repository);
  final McpResourceExportRepository repository;

  static String suggestedName(ResourceContents contents) {
    final mime = contents.mimeType?.split(';').first.trim().toLowerCase();
    final extension = switch (mime) {
      'image/png' => 'png',
      'image/jpeg' => 'jpg',
      'image/gif' => 'gif',
      'image/webp' => 'webp',
      'image/bmp' => 'bmp',
      'application/pdf' => 'pdf',
      'audio/wav' || 'audio/x-wav' => 'wav',
      'audio/mpeg' => 'mp3',
      'audio/ogg' => 'ogg',
      'audio/flac' => 'flac',
      _ => 'bin',
    };
    return 'resource.$extension';
  }

  Future<Result<bool>> save(
    ResourceContents contents, {
    required bool Function() isCurrent,
  }) async {
    if (!isCurrent()) return const Result.failure(_stale);
    final blob = contents.blob;
    if (blob == null) {
      return const Result.failure(
        ValidationFailure('This resource has no binary data.'),
      );
    }
    try {
      final bytes = await _decode(blob);
      if (!isCurrent()) return const Result.failure(_stale);
      // Once opened, the native dialog owns this explicitly requested export.
      // Its platform API combines destination selection and writing.
      final result = await repository.save(
        bytes,
        suggestedName(contents),
        contents.mimeType ?? 'application/octet-stream',
      );
      return isCurrent() ? result : const Result.failure(_stale);
    } on FormatException {
      return const Result.failure(
        ValidationFailure('The resource contains invalid base64 data.'),
      );
    } on Object {
      return const Result.failure(
        StorageFailure('Could not prepare the resource for saving.'),
      );
    }
  }

  static const _stale = ValidationFailure(
    'This resource result is no longer active.',
  );
}
