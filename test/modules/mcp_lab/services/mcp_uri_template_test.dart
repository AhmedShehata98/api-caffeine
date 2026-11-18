import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';

void main() {
  String expand(String source, Map<String, Object?> values) =>
      McpUriTemplate.parse(source).valueOrNull!.expand(values).valueOrNull!;
  test(
    'RFC scalar operator examples use the correct separators and encoding',
    () {
      const values = {
        'var': 'value',
        'hello': 'Hello World!',
        'path': '/foo/bar',
        'x': '1024',
        'y': '768',
        'empty': '',
      };
      const examples = {
        '{var}': 'value',
        '{hello}': 'Hello%20World%21',
        '{+hello}': 'Hello%20World!',
        '{+path}/here': '/foo/bar/here',
        'X{#hello}': 'X#Hello%20World!',
        'X{.var}': 'X.value',
        '{/var,x}': '/value/1024',
        '{;x,y,empty}': ';x=1024;y=768;empty',
        '{?x,y,empty}': '?x=1024&y=768&empty=',
        '{&x,y,empty}': '&x=1024&y=768&empty=',
        '{var:3}': 'val',
        '{var*}': 'value',
        '{?var*}': '?var=value',
      };
      for (final entry in examples.entries) {
        final plan = McpUriTemplate.parse(entry.key).valueOrNull!;
        expect(
          plan.expand({
            for (final name in plan.variables)
              if (values.containsKey(name)) name: values[name]!,
          }).valueOrNull,
          entry.value,
          reason: entry.key,
        );
      }
    },
  );
  test(
    'Unicode uses UTF-8 and prefix counts code points rather than code units',
    () {
      expect(
        expand('weather://city/{city}', {'city': 'القاهرة 😀'}),
        'weather://city/%D8%A7%D9%84%D9%82%D8%A7%D9%87%D8%B1%D8%A9%20%F0%9F%98%80',
      );
      expect(expand('{x:1}', {'x': '😀abc'}), '%F0%9F%98%80');
    },
  );
  test('reserved expansion preserves valid percent triplets but simple values encode percent', () {
    expect(expand('{x}', {'x': '%2F/'}), '%252F%2F');
    expect(expand('{+x}', {'x': '%2F/'}), '%2F/');
    expect(expand('{+x}', {'x': '%oops'}), '%25oops');
    expect(
      expand('https://example.test/é/%2F{?q}', {'q': 'a&b+c'}),
      'https://example.test/%C3%A9/%2F?q=a%26b%2Bc',
    );
  });
  test('undefined differs from an explicitly empty string', () {
    expect(expand('weather://city{?q}', {}), 'weather://city');
    expect(expand('weather://city{?q}', {'q': ''}), 'weather://city?q=');
    expect(expand('{.x}', {'x': ''}), '.');
    expect(expand('{/x}', {'x': ''}), '/');
  });
  test('variables are unique and retain first occurrence order', () {
    expect(McpUriTemplate.parse('{a,b}/{a:2}/{%41}').valueOrNull!.variables, [
      'a',
      'b',
      '%41',
    ]);
  });
  test(
    'malformed templates produce failures rather than partial expansions',
    () {
      for (final source in [
        '{',
        '}',
        '{}',
        '{{x}}',
        '{ x}',
        '{x,}',
        '{x..y}',
        '{x:0}',
        '{x:10000}',
        '{x:2*}',
        '{!x}',
        'file://bad path/{x}',
        'file://%zz/{x}',
      ]) {
        expect(McpUriTemplate.parse(source).isSuccess, isFalse, reason: source);
      }
    },
  );
  test('template, expression, variable and value budgets are enforced', () {
    expect(McpUriTemplate.parse('x' * 16385).isSuccess, isFalse);
    expect(McpUriTemplate.parse('é' * 8193).isSuccess, isFalse);
    expect(McpUriTemplate.parse('{x}' * 129).isSuccess, isFalse);
    expect(
      McpUriTemplate.parse('{${List.generate(65, (i) => 'x$i').join(',')}}')
          .isSuccess,
      isFalse,
    );
    final plan = McpUriTemplate.parse('{x}').valueOrNull!;
    expect(plan.expand({'x': 'x' * 4097}).isSuccess, isFalse);
    expect(plan.expand({'x': 'é' * 2049}).isSuccess, isFalse);
    expect(plan.expand({'other': 'x'}).isSuccess, isFalse);
  });
  test('repeated values cannot build an unbounded expanded URI', () {
    final plan = McpUriTemplate.parse('{${List.filled(1000, 'x').join(',')}}')
        .valueOrNull!;
    expect(
      plan.expand({'x': 'x' * 4096}).failureOrNull?.message,
      contains('64 KiB'),
    );
  });
  test('RFC list expansion covers every operator with and without explode', () {
    const values = {
      'list': ['red', 'green', 'blue'],
    };
    const examples = {
      '{list}': 'red,green,blue',
      '{list*}': 'red,green,blue',
      '{+list}': 'red,green,blue',
      '{+list*}': 'red,green,blue',
      '{#list}': '#red,green,blue',
      '{#list*}': '#red,green,blue',
      '{.list}': '.red,green,blue',
      '{.list*}': '.red.green.blue',
      '{/list}': '/red,green,blue',
      '{/list*}': '/red/green/blue',
      '{;list}': ';list=red,green,blue',
      '{;list*}': ';list=red;list=green;list=blue',
      '{?list}': '?list=red,green,blue',
      '{?list*}': '?list=red&list=green&list=blue',
      '{&list}': '&list=red,green,blue',
      '{&list*}': '&list=red&list=green&list=blue',
    };
    for (final example in examples.entries) {
      expect(expand(example.key, values), example.value, reason: example.key);
    }
  });
  test(
    'RFC object expansion covers every operator with stable entry order',
    () {
      const values = {
        'keys': {'semi': ';', 'dot': '.', 'comma': ','},
      };
      const examples = {
        '{keys}': 'semi,%3B,dot,.,comma,%2C',
        '{keys*}': 'semi=%3B,dot=.,comma=%2C',
        '{+keys}': 'semi,;,dot,.,comma,,',
        '{+keys*}': 'semi=;,dot=.,comma=,',
        '{#keys}': '#semi,;,dot,.,comma,,',
        '{#keys*}': '#semi=;,dot=.,comma=,',
        '{.keys}': '.semi,%3B,dot,.,comma,%2C',
        '{.keys*}': '.semi=%3B.dot=..comma=%2C',
        '{/keys}': '/semi,%3B,dot,.,comma,%2C',
        '{/keys*}': '/semi=%3B/dot=./comma=%2C',
        '{;keys}': ';keys=semi,%3B,dot,.,comma,%2C',
        '{;keys*}': ';semi=%3B;dot=.;comma=%2C',
        '{?keys}': '?keys=semi,%3B,dot,.,comma,%2C',
        '{?keys*}': '?semi=%3B&dot=.&comma=%2C',
        '{&keys}': '&keys=semi,%3B,dot,.,comma,%2C',
        '{&keys*}': '&semi=%3B&dot=.&comma=%2C',
      };
      for (final example in examples.entries) {
        expect(expand(example.key, values), example.value, reason: example.key);
      }
    },
  );
  test('empty composites are omitted while empty members remain defined', () {
    for (final op in ['', '+', '#', '.', '/', ';', '?', '&']) {
      expect(
        expand(
          'x{$op'
          'list,keys}',
          {'list': <String>[], 'keys': <String, String>{}},
        ),
        'x',
      );
      expect(
        expand(
          'x{$op'
          'list*,keys*}',
          {'list': <String>[], 'keys': <String, String>{}},
        ),
        'x',
      );
    }
    expect(
      expand('{;list}', {
        'list': [''],
      }),
      ';list=',
    );
    expect(
      expand('{;list*}', {
        'list': ['', 'blue'],
      }),
      ';list;list=blue',
    );
    expect(
      expand('{?list*}', {
        'list': ['', 'blue'],
      }),
      '?list=&list=blue',
    );
    expect(
      expand('{keys*}', {
        'keys': {'empty': ''},
      }),
      'empty',
    );
    expect(
      expand('{/keys*}', {
        'keys': {'empty': ''},
      }),
      '/empty',
    );
    expect(
      expand('{?keys*}', {
        'keys': {'empty': ''},
      }),
      '?empty=',
    );
  });
  test(
    'composite values encode Unicode, reserved characters and percent triplets',
    () {
      expect(
        expand('{/list*}', {
          'list': ['雪', '%2F/a'],
        }),
        '/%E9%9B%AA/%252F%2Fa',
      );
      expect(
        expand('{+list*}', {
          'list': ['雪', '%2F/a'],
        }),
        '%E9%9B%AA,%2F/a',
      );
      expect(
        expand('{?keys*}', {
          'keys': {'a&b': 'x=y', '雪': '+'},
        }),
        '?a%26b=x%3Dy&%E9%9B%AA=%2B',
      );
    },
  );
  test(
    'prefix modifiers reject nonempty composites instead of truncating them',
    () {
      final plan = McpUriTemplate.parse('{list:2}').valueOrNull!;
      expect(
        plan
            .expand({
              'list': ['red'],
            })
            .failureOrNull!
            .message,
        contains('only to text'),
      );
      expect(
        plan.expand({
          'list': {'key': 'value'},
        }).isSuccess,
        isFalse,
      );
      expect(plan.expand({'list': <String>[]}).valueOrNull, '');
    },
  );
  test(
    'composite types, element counts and combined byte budgets are enforced',
    () {
      final plan = McpUriTemplate.parse('{x*}').valueOrNull!;
      for (final value in [
        1,
        true,
        null,
        ['text', 1],
        [
          ['nested'],
        ],
        {'key': []},
        {1: 'value'},
        List.filled(129, ''),
        {for (var i = 0; i < 129; i++) '$i': ''},
        ['é' * 1024, 'é' * 1025],
        {'key': 'a' * 4096},
      ]) {
        expect(plan.expand({'x': value}).isSuccess, isFalse);
      }
      expect(plan.expand({'x': List.filled(128, '')}).isSuccess, isTrue);
    },
  );
  test('exploded composites cannot exceed the full URI budget', () {
    final source = '{?${List.filled(100, 'list*').join(',')}}';
    final plan = McpUriTemplate.parse(source).valueOrNull!;
    expect(
      plan.expand({'list': List.filled(128, 'x' * 30)}).failureOrNull!.message,
      contains('64 KiB'),
    );
  });
  test(
    'explicit input kinds preserve text and produce immutable composites',
    () {
      final text = McpUriTemplate.parseInput(const McpUriTemplateInput('["a"]'))
          .valueOrNull;
      expect(text, '["a"]');
      final list =
          McpUriTemplate.parseInput(
                const McpUriTemplateInput(
                  '["a", "b"]',
                  kind: McpUriTemplateInputKind.list,
                ),
              ).valueOrNull
              as List<String>;
      expect(() => list.add('c'), throwsUnsupportedError);
      final object =
          McpUriTemplate.parseInput(
                const McpUriTemplateInput(
                  '{"a":"b"}',
                  kind: McpUriTemplateInputKind.object,
                ),
              ).valueOrNull
              as Map<String, String>;
      expect(() => object['a'] = 'c', throwsUnsupportedError);
    },
  );
  test('invalid typed JSON cannot expand or silently reuse an older value', () {
    final plan = McpUriTemplate.parse('weather://city{?x*}').valueOrNull!;
    for (final input in [
      const McpUriTemplateInput('["a",', kind: McpUriTemplateInputKind.list),
      const McpUriTemplateInput('[1]', kind: McpUriTemplateInputKind.list),
      const McpUriTemplateInput(
        '{"a":null}',
        kind: McpUriTemplateInputKind.object,
      ),
      const McpUriTemplateInput('[]', kind: McpUriTemplateInputKind.object),
      const McpUriTemplateInput('{}', kind: McpUriTemplateInputKind.list),
      McpUriTemplateInput('é' * 2049),
    ]) {
      expect(plan.expandInputs({'x': input}).isSuccess, isFalse);
    }
    expect(
      plan.expandInputs({
        'x': const McpUriTemplateInput(
          '["a","b"]',
          kind: McpUriTemplateInputKind.list,
        ),
      }).valueOrNull,
      'weather://city?x=a&x=b',
    );
  });
}
