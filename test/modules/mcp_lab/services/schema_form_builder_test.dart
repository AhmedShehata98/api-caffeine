import 'package:flutter_test/flutter_test.dart';
import 'package:test_point/modules/mcp_lab/mcp_lab.dart';

void main() {
  const builder = SchemaFormBuilder();
  FormSpec form(Map<String, dynamic> schema) =>
      builder.build(schema) as FormSpec;
  const object = <String, dynamic>{
    'type': 'object',
    'additionalProperties': false,
    'required': ['count', 'enabled', 'profile'],
    'properties': {
      'count': {'type': 'integer', 'default': 2},
      'enabled': {'type': 'boolean'},
      'profile': {
        'type': 'object',
        'required': ['city'],
        'properties': {
          'city': {'type': 'string'},
        },
      },
      'tags': {
        'type': 'array',
        'items': {
          'type': 'string',
          'enum': ['a', 'b'],
        },
      },
    },
  };
  test(
    'immutable nested form plans preserve defaults and required markers',
    () {
      final spec = form(object);
      expect(spec.properties['count']!.defaultValue, 2);
      expect(spec.properties['count']!.hasDefault, isTrue);
      expect(spec.required, {'count', 'enabled', 'profile'});
      expect(spec.properties['tags']!.items!.enumValues, ['a', 'b']);
      expect(() => spec.properties.clear(), throwsUnsupportedError);
    },
  );
  test('local definitions resolve escaped JSON pointer tokens', () {
    final spec = form({
      r'$defs': {
        'a/b~c': {'type': 'integer'},
      },
      'type': 'object',
      'properties': {
        'value': {r'$ref': r'#/$defs/a~1b~0c'},
      },
    });
    expect(spec.properties['value']!.type, SchemaFieldType.integer);
  });
  test('external, recursive, missing and anchor references fall back', () {
    for (final ref in [
      'https://invalid.test/schema',
      '#',
      r'#/$defs/missing',
      '#anchor',
    ]) {
      expect(builder.build({r'$ref': ref}), isA<RawJsonOnly>());
    }
  });
  test('unsupported constraints are named rather than ignored', () {
    for (final key in [
      'minimum',
      'pattern',
      'allOf',
      'unevaluatedProperties',
    ]) {
      expect(
        (builder.build({'type': 'object', key: 1}) as RawJsonOnly).reason,
        contains(key),
      );
    }
    expect(
      builder.build({
        'type': ['object', 'null'],
      }),
      isA<RawJsonOnly>(),
    );
  });
  test('deep and wide schemas hit bounded traversal', () {
    Map<String, dynamic> deep = {'type': 'string'};
    for (var i = 0; i < 200; i++) {
      deep = {
        'type': 'object',
        'properties': {'child': deep},
      };
    }
    expect((builder.build(deep) as RawJsonOnly).reason, contains('32'));
    expect(
      builder.build({
        'type': 'object',
        'properties': {
          for (var i = 0; i < 11000; i++) 'f$i': {'type': 'string'},
        },
      }),
      isA<RawJsonOnly>(),
    );
  });
  test(
    'JSON then schema coercion preserves zero and false in nested values',
    () {
      final spec = form(object);
      final input = {
        'count': '0',
        'enabled': 'false',
        'profile': {'city': 'Cairo'},
        'tags': '["a","b"]',
      };
      expect(builder.arguments(spec, input, coerce: true).valueOrNull, {
        'count': 0,
        'enabled': false,
        'profile': {'city': 'Cairo'},
        'tags': ['a', 'b'],
      });
      expect(builder.arguments(spec, input).isSuccess, isFalse);
    },
  );
  test('required, type, enum and unknown-property errors have field paths', () {
    final result = builder.arguments(form(object), {
      'count': '',
      'enabled': 'wrong',
      'profile': {},
      'tags': ['invalid'],
      'extra': 'secret',
    }, coerce: true);
    final errors = (result.failureOrNull as SchemaArgumentFailure).fields;
    expect(errors[r'$.count'], 'Required');
    expect(errors[r'$.profile.city'], 'Required');
    expect(errors[r'$.tags[0]'], 'Choose an enum value');
    expect(errors[r'$.extra'], 'Unknown property');
    expect(errors.values.join(), isNot(contains('secret')));
  });
  test(
    'strict required means present; form required strings cannot be blank',
    () {
      final spec = form({
        'type': 'object',
        'required': ['name'],
        'properties': {
          'name': {'type': 'string'},
        },
      });
      expect(builder.arguments(spec, '{"name":""}').isSuccess, isTrue);
      expect(
        builder.arguments(spec, {'name': ''}, coerce: true).isSuccess,
        isFalse,
      );
    },
  );
  test('oneOf enforces exclusivity even with explicit picker choice', () {
    final spec = form({
      'type': 'object',
      'oneOf': [
        {
          'type': 'object',
          'required': ['a'],
          'properties': {
            'a': {'type': 'integer'},
          },
        },
        {
          'type': 'object',
          'required': ['b'],
          'properties': {
            'b': {'type': 'string'},
          },
        },
      ],
    });
    expect(
      builder
          .arguments(
            spec,
            const SchemaVariantValue(0, {'a': '2'}),
            coerce: true,
          )
          .valueOrNull,
      {'a': 2},
    );
    expect(builder.arguments(spec, {'a': 2, 'b': 'both'}).isSuccess, isFalse);
    expect(
      builder
          .arguments(spec, const SchemaVariantValue(0, {'a': 2, 'b': 'both'}))
          .isSuccess,
      isFalse,
    );
    expect(
      builder.arguments(spec, const SchemaVariantValue(10, {})).isSuccess,
      isFalse,
    );
  });
  test('anyOf accepts overlap and removes picker wrappers', () {
    final spec = form({
      'anyOf': [
        {'type': 'object'},
        {'type': 'object'},
      ],
    });
    expect(
      builder
          .arguments(spec, const SchemaVariantValue(1, {'a': 1}))
          .valueOrNull,
      {'a': 1},
    );
  });
  test('numeric enums and null preserve JSON types', () {
    final spec = form({
      'type': 'object',
      'properties': {
        'n': {'type': 'null'},
        'i': {
          'type': 'integer',
          'enum': [1],
        },
      },
    });
    expect(builder.arguments(spec, {'n': null, 'i': 1.0}).isSuccess, isTrue);
    expect(builder.arguments(spec, {'i': 1.5}).isSuccess, isFalse);
    expect(builder.arguments(spec, {'i': double.nan}).isSuccess, isFalse);
  });
  test(
    'malformed schemas, invalid JSON and oversized input fail explicitly',
    () {
      expect(builder.build({'type': 'object', 'title': 1}), isA<RawJsonOnly>());
      expect(
        builder.build({'type': 'object', 'required': null}),
        isA<RawJsonOnly>(),
      );
      expect(
        builder.arguments(form({'type': 'object'}), '{').isSuccess,
        isFalse,
      );
      expect(
        builder
            .arguments(form({'type': 'object'}), 'x' * (256 * 1024 + 1))
            .isSuccess,
        isFalse,
      );
    },
  );
  test('default annotations do not silently inject arguments', () {
    final spec = form({
      'type': 'object',
      'properties': {
        'name': {'type': 'string', 'default': 'value'},
      },
    });
    expect(builder.arguments(spec, {}).valueOrNull, isEmpty);
    expect(spec.properties['name']!.defaultValue, 'value');
  });
}
