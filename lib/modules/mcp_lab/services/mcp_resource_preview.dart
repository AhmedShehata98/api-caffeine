import 'dart:convert';
import 'dart:isolate';

import '../models/mcp_protocol_models.dart';

class McpResourcePreview {
  const McpResourcePreview({
    this.text,
    this.json = false,
    this.byteLength,
    this.notice,
  });
  final String? text;
  final bool json;
  final int? byteLength;
  final String? notice;
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
    return McpResourcePreview(byteLength: base64Decode(contents.blob!).length);
  } on FormatException {
    return const McpResourcePreview(
      notice: 'The resource contains invalid base64 data.',
    );
  }
});
