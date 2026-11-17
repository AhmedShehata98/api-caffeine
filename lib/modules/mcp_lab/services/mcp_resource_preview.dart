import 'dart:convert';
import 'dart:isolate';
import 'dart:typed_data';

import '../models/mcp_protocol_models.dart';

class McpResourcePreview {
  const McpResourcePreview({
    this.text,
    this.json = false,
    this.byteLength,
    this.notice,
    this.imageBytes,
  });
  final String? text;
  final bool json;
  final int? byteLength;
  final String? notice;
  final Uint8List? imageBytes;
}

/// Decode only explicitly viewed content, outside Flutter's UI isolate.
Future<McpResourcePreview> prepareMcpResourcePreview(
  ResourceContents contents,
) => Isolate.run(() {
  final text = contents.text;
  if (text != null) {
    final mime = contents.mimeType?.split(';').first.trim().toLowerCase();
    if (mime == 'application/json' || (mime?.endsWith('+json') ?? false)) {
      try {
        return McpResourcePreview(
          text: const JsonEncoder.withIndent('  ').convert(jsonDecode(text)),
          json: true,
        );
      } on FormatException {
        return McpResourcePreview(
          text: text,
          notice: 'Invalid JSON. Showing the original text.',
        );
      }
    }
    return McpResourcePreview(text: text);
  }
  try {
    final bytes = base64Decode(contents.blob!);
    final mime = contents.mimeType?.split(';').first.trim().toLowerCase();
    final image = const {
      'image/png',
      'image/jpeg',
      'image/gif',
      'image/webp',
      'image/bmp',
    }.contains(mime);
    const previewLimit = 8 * 1024 * 1024;
    return McpResourcePreview(
      byteLength: bytes.length,
      imageBytes: image && bytes.length <= previewLimit ? bytes : null,
      notice: image && bytes.length > previewLimit
          ? 'Image preview is limited to 8 MiB. Save the resource to view it.'
          : !image && (mime?.startsWith('image/') ?? false)
          ? 'Inline preview is unavailable for this image type. Save the resource to view it.'
          : null,
    );
  } on FormatException {
    return const McpResourcePreview(
      notice: 'The resource contains invalid base64 data.',
    );
  }
});
