import 'dart:convert';

import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

import '../models/mcp_uri_template_input.dart';

/// Bounded RFC 6570 expansion for text, string lists and string-keyed objects.
class McpUriTemplate {
  McpUriTemplate._(this.source, this._parts, this.variables);
  final String source;
  final List<Object> _parts;
  final List<String> variables;
  static final _name = RegExp(
    r'^(?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2})(?:\.?(?:[a-zA-Z0-9_]|%[0-9a-fA-F]{2}))*$',
  );
  static final _hex = RegExp(r'^[0-9A-Fa-f]{2}$');
  static const _reserved = ":/?#[]@!\u0024&'()*+,;=";

  static Result<McpUriTemplate> parse(String source) {
    if (source.length > 16384 || utf8.encode(source).length > 16384) {
      return const Result.failure(
        ValidationFailure(
          'This URI template exceeds the 16 KiB limit. Enter a resolved URI instead.',
        ),
      );
    }
    try {
      final parts = <Object>[];
      final names = <String>{};
      var expressions = 0;
      var index = 0;
      while (index < source.length) {
        if (source[index] == '}') throw const FormatException();
        if (source[index] != '{') {
          final end = source.indexOf('{', index);
          final literal = source.substring(
            index,
            end < 0 ? source.length : end,
          );
          if (literal.contains('}') ||
              RegExp(r'[\x00-\x20\x7F-\x9F"<>\\^`|]').hasMatch(literal)) {
            throw const FormatException();
          }
          for (var i = 0; i < literal.length; i++) {
            if (literal[i] == '%') {
              if (i + 2 >= literal.length ||
                  !_hex.hasMatch(literal.substring(i + 1, i + 3))) {
                throw const FormatException();
              }
              i += 2;
            }
          }
          parts.add(literal);
          index += literal.length;
          continue;
        }
        final end = source.indexOf('}', index + 1);
        if (end < 0 || ++expressions > 128) throw const FormatException();
        var expression = source.substring(index + 1, end);
        if (expression.isEmpty) throw const FormatException();
        final operator = '+#./;?&'.contains(expression[0]) ? expression[0] : '';
        expression = expression.substring(operator.length);
        final specs = <_Variable>[];
        for (var spec in expression.split(',')) {
          int? prefix;
          var explode = false;
          if (spec.endsWith('*')) {
            explode = true;
            spec = spec.substring(0, spec.length - 1);
          } else if (spec.contains(':')) {
            final pair = spec.split(':');
            if (pair.length != 2 ||
                !RegExp(r'^[1-9][0-9]{0,3}$').hasMatch(pair[1])) {
              throw const FormatException();
            }
            prefix = int.parse(pair[1]);
            spec = pair[0];
          }
          if (!_name.hasMatch(spec)) throw const FormatException();
          names.add(spec);
          if (names.length > 64) throw const FormatException();
          specs.add(_Variable(spec, prefix, explode));
        }
        parts.add(_Expression(operator, specs));
        index = end + 1;
      }
      return Result.success(
        McpUriTemplate._(
          source,
          List.unmodifiable(parts),
          List.unmodifiable(names),
        ),
      );
    } on FormatException {
      return const Result.failure(
        ValidationFailure(
          'This URI template is invalid or exceeds the 128-expression/64-variable limit. Enter a resolved URI instead.',
        ),
      );
    }
  }

  static Result<Object> parseInput(McpUriTemplateInput input) {
    if (input.text.length > 4096 || utf8.encode(input.text).length > 4096) {
      return const Result.failure(
        ValidationFailure('Template inputs must be at most 4 KiB each.'),
      );
    }
    if (input.kind == McpUriTemplateInputKind.text) {
      return Result.success(input.text);
    }
    try {
      final value = jsonDecode(input.text);
      final problem = _valueProblem(value);
      if (problem == null &&
          input.kind == McpUriTemplateInputKind.list &&
          value is List) {
        return Result.success(List<String>.unmodifiable(value.cast<String>()));
      }
      if (problem == null &&
          input.kind == McpUriTemplateInputKind.object &&
          value is Map) {
        return Result.success(
          Map<String, String>.unmodifiable(value.cast<String, String>()),
        );
      }
      return Result.failure(
        ValidationFailure(
          problem ??
              (input.kind == McpUriTemplateInputKind.list
                  ? 'Enter a JSON list of strings.'
                  : 'Enter a JSON object with string values.'),
        ),
      );
    } on FormatException {
      return Result.failure(
        ValidationFailure(
          input.kind == McpUriTemplateInputKind.list
              ? 'Enter a JSON list of strings.'
              : 'Enter a JSON object with string values.',
        ),
      );
    }
  }

  Result<String> expandInputs(Map<String, McpUriTemplateInput> inputs) {
    final values = <String, Object>{};
    for (final entry in inputs.entries) {
      final parsed = parseInput(entry.value);
      if (!parsed.isSuccess) {
        return Result.failure(
          ValidationFailure('${entry.key}: ${parsed.failureOrNull!.message}'),
        );
      }
      values[entry.key] = parsed.valueOrNull!;
    }
    return expand(values);
  }

  static String? _valueProblem(Object? value) {
    Iterable<String> strings;
    if (value is String) {
      strings = [value];
    } else if (value is List) {
      if (value.length > 128) {
        return 'Template lists must contain at most 128 items.';
      }
      if (value.any((item) => item is! String)) {
        return 'Template lists must contain only strings.';
      }
      strings = value.cast<String>();
    } else if (value is Map) {
      if (value.length > 128) {
        return 'Template objects must contain at most 128 entries.';
      }
      if (value.keys.any((key) => key is! String) ||
          value.values.any((item) => item is! String)) {
        return 'Template objects must contain string keys and string values.';
      }
      strings = value.entries.expand(
        (entry) => [entry.key as String, entry.value as String],
      );
    } else {
      return 'Use text, a list of strings or an object with string values; nested and non-string values are unsupported.';
    }
    var bytes = 0;
    for (final text in strings) {
      if (text.length > 4096) {
        return 'Template values must be at most 4 KiB each.';
      }
      bytes += utf8.encode(text).length;
      if (bytes > 4096) return 'Template values must be at most 4 KiB each.';
    }
    return null;
  }

  Result<String> expand(Map<String, Object?> values) {
    if (values.keys.any((key) => !variables.contains(key))) {
      return const Result.failure(
        ValidationFailure('Provide values only for this template’s variables.'),
      );
    }
    for (final value in values.values) {
      final problem = _valueProblem(value);
      if (problem != null) return Result.failure(ValidationFailure(problem));
    }
    final output = StringBuffer();
    for (final part in _parts) {
      if (part is String) {
        output.write(_encode(part, literal: true));
      } else {
        final expression = part as _Expression;
        final op = expression.operator;
        final segments = <String>[];
        var segmentLength = 0;
        for (final spec in expression.variables) {
          if (!values.containsKey(spec.name)) continue;
          final value = values[spec.name]!;
          if (value is! String &&
              spec.prefix != null &&
              !(value is List && value.isEmpty) &&
              !(value is Map && value.isEmpty)) {
            return Result.failure(
              ValidationFailure(
                '${spec.name}: Prefix modifiers apply only to text values.',
              ),
            );
          }
          for (final segment in _segments(spec, value, op)) {
            segmentLength += segment.length + 1;
            if (output.length + segmentLength > 65536) {
              return const Result.failure(
                ValidationFailure(
                  'The expanded resource URI exceeds the 64 KiB limit.',
                ),
              );
            }
            segments.add(segment);
          }
        }
        if (segments.isNotEmpty) {
          final prefix = op == '+' ? '' : op;
          final separator = op == '?' || op == '&'
              ? '&'
              : op == '.' || op == '/' || op == ';'
              ? op
              : ',';
          output.write('$prefix${segments.join(separator)}');
        }
      }
      if (output.length > 65536) {
        return const Result.failure(
          ValidationFailure(
            'The expanded resource URI exceeds the 64 KiB limit.',
          ),
        );
      }
    }
    return Result.success(output.toString());
  }

  static Iterable<String> _segments(
    _Variable spec,
    Object value,
    String op,
  ) sync* {
    final named = op == ';' || op == '?' || op == '&';
    final query = op == '?' || op == '&';
    String encode(String text) =>
        _encode(text, reserved: op == '+' || op == '#');
    String pair(String key, String text) =>
        text.isEmpty && !query ? key : '$key=$text';
    String composite(String text) => named ? '${spec.name}=$text' : text;
    if (value is String) {
      final limited = spec.prefix == null
          ? value
          : String.fromCharCodes(value.runes.take(spec.prefix!));
      final encoded = encode(limited);
      yield named ? pair(spec.name, encoded) : encoded;
    } else if (value is List) {
      if (value.isEmpty) return;
      if (spec.explode) {
        for (final item in value.cast<String>()) {
          final encoded = encode(item);
          yield named ? pair(spec.name, encoded) : encoded;
        }
      } else {
        yield composite(value.cast<String>().map(encode).join(','));
      }
    } else if (value is Map) {
      if (value.isEmpty) return;
      final entries = value.cast<String, String>().entries;
      if (spec.explode) {
        for (final entry in entries) {
          yield pair(encode(entry.key), encode(entry.value));
        }
      } else {
        yield composite(
          entries
              .expand((entry) => [encode(entry.key), encode(entry.value)])
              .join(','),
        );
      }
    }
  }

  static String _encode(
    String value, {
    bool reserved = false,
    bool literal = false,
  }) {
    final runes = value.runes.toList();
    final result = StringBuffer();
    for (var index = 0; index < runes.length; index++) {
      final rune = runes[index];
      final char = String.fromCharCode(rune);
      if (rune == 37 &&
          (reserved || literal) &&
          index + 2 < runes.length &&
          _hex.hasMatch(
            String.fromCharCodes(runes.sublist(index + 1, index + 3)),
          )) {
        result.write(String.fromCharCodes(runes.sublist(index, index + 3)));
        index += 2;
      } else if ((rune >= 65 && rune <= 90) ||
          (rune >= 97 && rune <= 122) ||
          (rune >= 48 && rune <= 57) ||
          '-._~'.contains(char) ||
          ((reserved || literal) && _reserved.contains(char))) {
        result.write(char);
      } else {
        for (final byte in utf8.encode(char)) {
          result.write(
            '%${byte.toRadixString(16).toUpperCase().padLeft(2, '0')}',
          );
        }
      }
    }
    return result.toString();
  }
}

class _Variable {
  const _Variable(this.name, this.prefix, this.explode);
  final String name;
  final int? prefix;
  final bool explode;
}

class _Expression {
  const _Expression(this.operator, this.variables);
  final String operator;
  final List<_Variable> variables;
}
