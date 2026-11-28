import 'dart:convert';

/// Finds the beginning of a JSON value, using typed object keys and indices.
int? responseJsonLocation(String source, List<Object> target) {
  try {
    return _Scanner(source, target).find();
  } on FormatException {
    return null;
  }
}

class _Scanner {
  _Scanner(this.source, this.target);
  final String source;
  final List<Object> target;
  int index = 0;
  int? location;

  int? find() {
    _value(0, true);
    return location;
  }

  void _space() {
    while (index < source.length && ' \t\r\n'.contains(source[index])) {
      index++;
    }
  }

  String _string() {
    final start = index++;
    var escaped = false;
    while (index < source.length) {
      final code = source.codeUnitAt(index++);
      if (escaped) {
        escaped = false;
      } else if (code == 92) {
        escaped = true;
      } else if (code == 34) {
        return jsonDecode(source.substring(start, index)) as String;
      }
    }
    throw const FormatException();
  }

  void _value(int depth, bool matches) {
    _space();
    if (index >= source.length || depth > 64) throw const FormatException();
    if (matches && depth == target.length) location = index;
    final start = source[index];
    if (start == '{') {
      index++;
      _space();
      while (index < source.length && source[index] != '}') {
        _space();
        if (source[index] != '"') throw const FormatException();
        final key = _string();
        _space();
        if (index >= source.length || source[index++] != ':') {
          throw const FormatException();
        }
        _value(
          depth + 1,
          matches && depth < target.length && target[depth] == key,
        );
        _space();
        if (index < source.length && source[index] == ',') {
          index++;
        } else {
          break;
        }
      }
      if (index >= source.length || source[index++] != '}') {
        throw const FormatException();
      }
    } else if (start == '[') {
      index++;
      _space();
      var child = 0;
      while (index < source.length && source[index] != ']') {
        _value(
          depth + 1,
          matches && depth < target.length && target[depth] == child,
        );
        child++;
        _space();
        if (index < source.length && source[index] == ',') {
          index++;
        } else {
          break;
        }
      }
      if (index >= source.length || source[index++] != ']') {
        throw const FormatException();
      }
    } else if (start == '"') {
      _string();
    } else {
      while (index < source.length && !',]} \t\r\n'.contains(source[index])) {
        index++;
      }
    }
  }
}
