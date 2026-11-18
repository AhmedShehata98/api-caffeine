import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/repositories/mcp_sse_parser.dart';

void main() {
  test(
    'event types apply to one completed block and default back to message',
    () async {
      final events = await mcpSseEvents(
        Stream.value(
          utf8.encode(
            'event: ignored\nevent: endpoint\ndata: /messages\n\ndata: {}\n\nevent:\ndata: {}\n\n',
          ),
        ),
      ).toList();
      expect(events.map((event) => event.type), [
        'endpoint',
        'message',
        'message',
      ]);
      expect(events.first.data, '/messages');
    },
  );
  test(
    'fragmented blocks publish event IDs, priming data and retry metadata',
    () async {
      final wire = utf8.encode(
        '\uFEFFid: first\r\nretry: 42\r\ndata:\r\n\r\n'
        'data: {"text":\ndata: "雪"}\n\nid:\n\n',
      );
      final events = await mcpSseEvents(
        Stream.fromIterable(wire.map((byte) => [byte])),
      ).toList();
      expect(events, hasLength(3));
      expect(events[0].id, 'first');
      expect(events[0].data, '');
      expect(events[0].retryMilliseconds, 42);
      expect(jsonDecode(events[1].data!), {'text': '雪'});
      expect(events[1].id, isNull);
      expect(events[2].id, '');
      expect(events[2].data, isNull);
    },
  );
  test(
    'NUL IDs and invalid retry values do not override valid metadata',
    () async {
      final events = await mcpSseEvents(
        Stream.value(
          utf8.encode(
            'id: valid\nid: bad\u0000id\nretry: 3\nretry: -1\nretry: 1.5\ndata: {}\n\n',
          ),
        ),
      ).toList();
      expect(events.single.id, 'valid');
      expect(events.single.retryMilliseconds, 3);
    },
  );
  test(
    'oversized retry delay remains a delay rather than an immediate retry',
    () async {
      final events = await mcpSseEvents(
        Stream.value(utf8.encode('retry: ${'9' * 100}\n\n')),
      ).toList();
      expect(events.single.retryMilliseconds, 0x7fffffff);
    },
  );
  test('incomplete blocks cannot publish a replacement cursor', () async {
    final ids = <String?>[];
    await expectLater(() async {
      await for (final event in mcpSseEvents(
        Stream.value(
          utf8.encode('id: safe\ndata:\n\nid: partial\ndata: unfinished'),
        ),
      )) {
        ids.add(event.id);
      }
    }(), throwsA(isA<McpSseIncompleteEvent>()));
    expect(ids, ['safe']);
  });
}
