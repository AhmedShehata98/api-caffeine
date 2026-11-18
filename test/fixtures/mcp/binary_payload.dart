import 'dart:convert';
import 'dart:typed_data';

const fixtureBinarySize = 20 * 1024 * 1024;

Map<String, dynamic> binaryToolResult() {
  final bytes = Uint8List(fixtureBinarySize);
  bytes[0] = 85;
  bytes[bytes.length ~/ 2] = 127;
  bytes[bytes.length - 1] = 170;
  return {
    'content': [
      {
        'type': 'resource',
        'resource': {
          'uri': 'fixture://large.bin',
          'mimeType': 'application/octet-stream',
          'blob': base64Encode(bytes),
        },
      },
    ],
  };
}
