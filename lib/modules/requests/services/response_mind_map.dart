import 'dart:convert';
import 'dart:isolate';

const responseMindMapMaxBytes = 256 * 1024;
const _maxNodes = 1000;
const _maxDepth = 64;

class ResponseMindMapNode {
  ResponseMindMapNode({
    required this.id,
    required this.parentId,
    required this.label,
    required this.value,
    required this.isScalar,
  });

  final int id;
  final int? parentId;
  final String label;
  final String value;
  final bool isScalar;
  final children = <int>[];

  String get caption => '$label: $value';
}

class ResponseMindMap {
  const ResponseMindMap(this.nodes) : unavailableReason = null;

  const ResponseMindMap.unavailable(this.unavailableReason) : nodes = const [];

  final List<ResponseMindMapNode> nodes;
  final String? unavailableReason;

  List<int> find(String query) {
    if (query.isEmpty) return const [];
    final pattern = RegExp(RegExp.escape(query), caseSensitive: false);
    return [
      for (final node in nodes)
        if ((node.parentId != null && pattern.hasMatch(node.label)) ||
            (node.isScalar && pattern.hasMatch(node.value)))
          node.id,
    ];
  }
}

bool couldBeJson(String body) {
  final text = body.trimLeft();
  return text.isNotEmpty && '{["-0123456789tfn'.contains(text[0]);
}

Future<ResponseMindMap> buildResponseMindMap(String body, int sizeBytes) {
  if (sizeBytes > responseMindMapMaxBytes ||
      body.length > responseMindMapMaxBytes) {
    return Future.value(
      const ResponseMindMap.unavailable('Mind Map supports up to 256 KiB.'),
    );
  }
  if (body.length > 64 * 1024) {
    return Isolate.run(() => _parseMap(body));
  }
  return Future.value(_parseMap(body));
}

ResponseMindMap _parseMap(String body) {
  final Object? decoded;
  try {
    decoded = jsonDecode(body);
  } on FormatException {
    return const ResponseMindMap.unavailable('Mind Map requires valid JSON.');
  } on StackOverflowError {
    return const ResponseMindMap.unavailable(
      'Mind Map supports up to 64 levels.',
    );
  }

  final nodes = <ResponseMindMapNode>[];
  String? add(Object? value, String label, int? parent, int depth) {
    if (depth > _maxDepth) return 'Mind Map supports up to 64 levels.';
    if (nodes.length == _maxNodes) {
      return 'Mind Map supports up to 1,000 nodes.';
    }

    final id = nodes.length;
    nodes.add(
      ResponseMindMapNode(
        id: id,
        parentId: parent,
        label: label,
        isScalar: value is! Map && value is! List,
        value: switch (value) {
          Map() => '{${value.length}}',
          List() => '[${value.length}]',
          String() => value,
          _ => value.toString(),
        },
      ),
    );
    if (parent != null) nodes[parent].children.add(id);

    final children = switch (value) {
      Map<String, dynamic>() => value.entries.map(
        (entry) => (entry.key, entry.value),
      ),
      List<dynamic>() => value.asMap().entries.map(
        (entry) => ('[${entry.key}]', entry.value),
      ),
      _ => const <(String, dynamic)>[],
    };
    for (final (childLabel, child) in children) {
      final reason = add(child, childLabel, id, depth + 1);
      if (reason != null) return reason;
    }
    return null;
  }

  final reason = add(decoded, 'JSON', null, 1);
  return reason == null
      ? ResponseMindMap(nodes)
      : ResponseMindMap.unavailable(reason);
}
