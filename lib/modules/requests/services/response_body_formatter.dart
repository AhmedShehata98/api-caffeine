import 'dart:isolate';

import 'package:xml/xml.dart';
import 'package:api_caffeine/modules/requests/models/http_response_result.dart';
import 'package:api_caffeine/modules/requests/services/json_formatter.dart';

enum ResponseSource { json, xml, html }

ResponseSource? responseSource(HttpResponseResult response) {
  final type = response.headers.entries
      .where((entry) => entry.key.toLowerCase() == 'content-type')
      .expand((entry) => entry.value)
      .firstOrNull
      ?.split(';')
      .first
      .trim()
      .toLowerCase();
  if (type == 'application/json' ||
      type == 'text/json' ||
      (type?.endsWith('+json') ?? false)) {
    return ResponseSource.json;
  }
  if (type == 'application/xml' ||
      type == 'text/xml' ||
      (type?.endsWith('+xml') ?? false)) {
    return ResponseSource.xml;
  }
  if (type == 'text/html') return ResponseSource.html;
  if ((type == null || type.isEmpty || type == 'text/plain') &&
      looksLikeJson(response.body)) {
    return ResponseSource.json;
  }
  return null;
}

Future<String?> formatResponseBody(HttpResponseResult response) async {
  final body = response.body;
  return switch (responseSource(response)) {
    ResponseSource.json => prettyPrintJson(body),
    ResponseSource.xml when body.length > 64 * 1024 => Isolate.run(
      () => _formatXml(body),
    ),
    ResponseSource.xml => _formatXml(body),
    ResponseSource.html when body.isNotEmpty => body,
    _ => null,
  };
}

String? _formatXml(String body) {
  try {
    final document = XmlDocument.parse(body);
    if (document.children.whereType<XmlElement>().length != 1) return null;
    return document.toXmlString(
      pretty: true,
      preserveWhitespace: (node) {
        if (node is XmlElement &&
            node.getAttribute('xml:space') == 'preserve') {
          return true;
        }
        final hasElements = node.children.any((child) => child is XmlElement);
        return node.children.any(
          (child) =>
              child is XmlCDATA ||
              (child is XmlText &&
                  (!hasElements || child.value.trim().isNotEmpty)),
        );
      },
    );
  } on XmlException {
    return null;
  } on StackOverflowError {
    return null;
  }
}
