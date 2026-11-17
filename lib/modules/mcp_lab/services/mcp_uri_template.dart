import 'dart:convert';

import 'package:test_point/core/error/failure.dart';
import 'package:test_point/core/error/result.dart';

/// Bounded RFC 6570 expansion for string variables. Composite list/map editors
/// belong to a later slice; scalar explode modifiers have no effect per RFC.
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
          if (spec.endsWith('*')) {
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
          specs.add(_Variable(spec, prefix));
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

  Result<String> expand(Map<String, String> values) {
    if (values.keys.any((key) => !variables.contains(key))) {
      return const Result.failure(
        ValidationFailure('Provide values only for this template’s variables.'),
      );
    }
    if (values.values.any(
      (value) => value.length > 4096 || utf8.encode(value).length > 4096,
    )) {
      return const Result.failure(
        ValidationFailure('Template values must be at most 4 KiB each.'),
      );
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
          final value = values[spec.name];
          if (value == null) continue;
          final limited = spec.prefix == null
              ? value
              : String.fromCharCodes(value.runes.take(spec.prefix!));
          final encoded = _encode(limited, reserved: op == '+' || op == '#');
          segmentLength += encoded.length + spec.name.length + 2;
          if (output.length + segmentLength > 65536) {
            return const Result.failure(
              ValidationFailure(
                'The expanded resource URI exceeds the 64 KiB limit.',
              ),
            );
          }
          segments.add(
            op == ';'
                ? '${spec.name}${encoded.isEmpty ? '' : '=$encoded'}'
                : op == '?' || op == '&'
                ? '${spec.name}=$encoded'
                : encoded,
          );
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
  const _Variable(this.name, this.prefix);
  final String name;
  final int? prefix;
}

class _Expression {
  const _Expression(this.operator, this.variables);
  final String operator;
  final List<_Variable> variables;
}
