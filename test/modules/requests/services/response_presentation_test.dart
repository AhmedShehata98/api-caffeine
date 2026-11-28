import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:api_caffeine/modules/requests/models/http_response_result.dart';
import 'package:api_caffeine/modules/requests/services/response_body_formatter.dart';
import 'package:api_caffeine/modules/requests/services/response_mind_map.dart';

HttpResponseResult _response(String body, [String? mediaType]) =>
    HttpResponseResult(
      statusCode: 200,
      headers: {
        if (mediaType != null) 'CoNtEnT-TyPe': [mediaType],
      },
      body: body,
      duration: Duration.zero,
      sizeBytes: utf8.encode(body).length,
    );

void main() {
  test(
    'recognizes structured types and only sniffs absent or plain text types',
    () async {
      expect(
        await formatResponseBody(
          _response('[1]', 'APPLICATION/problem+JSON; charset=utf-8'),
        ),
        '[\n  1\n]',
      );
      expect(
        await formatResponseBody(_response('[1]', 'text/plain')),
        '[\n  1\n]',
      );
      expect(await formatResponseBody(_response('[1]', 'text/csv')), isNull);
      expect(
        await formatResponseBody(_response('false', 'application/json')),
        'false',
      );
      expect(
        await formatResponseBody(_response('{oops', 'application/json')),
        isNull,
      );
    },
  );

  test('preserves the original HTML source', () async {
    const html = '<p>hi  <em>there</em>  </p>\r\n';
    expect(
      await formatResponseBody(_response(html, 'Text/HTML; charset=utf-8')),
      html,
    );
  });

  test('indents XML and keeps mixed, leaf and xml:space text', () async {
    const xml =
        '<root><mixed> hi  <b/>  there </mixed><leaf>  </leaf>'
        '<keep xml:space="preserve">  <b/>  </keep></root>';
    expect(
      await formatResponseBody(_response(xml, 'application/vendor+xml')),
      '<root>\n  <mixed> hi  <b/>  there </mixed>\n  <leaf>  </leaf>\n'
      '  <keep xml:space="preserve">  <b/>  </keep>\n</root>',
    );
    expect(
      await formatResponseBody(_response('<root>', 'application/xml')),
      isNull,
    );
    expect(
      await formatResponseBody(_response('<!-- comment -->', 'text/xml')),
      isNull,
    );
  });

  test(
    'builds and searches JSON in document order, including scalar roots',
    () async {
      const body = '{"Match":{"nested":"match"},"array":[true,null,"[0]"]}';
      final map = await buildResponseMindMap(body, body.length);
      expect(map.nodes[0].children, [1, 3]);
      expect(map.nodes[2].parentId, 1);
      expect(map.find('MATCH'), [1, 2]);
      expect(map.find('[0]'), [4, 6]);
      expect(
        (await buildResponseMindMap('null', 4)).nodes.single.value,
        'null',
      );
      expect(
        (await buildResponseMindMap('{oops', 5)).unavailableReason,
        contains('valid JSON'),
      );
    },
  );

  test('limits JSON maps by bytes, node count, and depth', () async {
    const bytes = responseMindMapMaxBytes;
    expect((await buildResponseMindMap('{}', bytes)).unavailableReason, isNull);
    expect(
      (await buildResponseMindMap('{}', bytes + 1)).unavailableReason,
      contains('256 KiB'),
    );
    for (final length in [999, 1000]) {
      final body = jsonEncode(List.filled(length, 0));
      final map = await buildResponseMindMap(body, body.length);
      expect(map.unavailableReason, length == 999 ? isNull : contains('1,000'));
    }
    for (final depth in [63, 64]) {
      final body = '${'[' * depth}0${']' * depth}';
      final map = await buildResponseMindMap(body, body.length);
      expect(
        map.unavailableReason,
        depth == 63 ? isNull : contains('64 levels'),
      );
    }
  });
}
