/// Recursive camelCase ↔ snake_case for JSON-like structures.
library;

String _camelToSnakeToken(String input) {
  // Walk the code units directly. Going via `input[i]` + `c.toLowerCase()`
  // allocates a fresh single-char String per iteration; for an API request
  // body with hundreds of keys this dominates the JSON-encode hot path.
  // ASCII uppercase is folded inline; keys containing any non-ASCII
  // character are returned unchanged so non-English keys keep their previous
  // shape (e.g. `caféName` stays `caféName`, not `café_name`).
  final b = StringBuffer();
  for (var i = 0; i < input.length; i++) {
    final code = input.codeUnitAt(i);
    if (code >= 0x80) return input;
    final isUpperAscii = code >= 0x41 && code <= 0x5A;
    if (isUpperAscii && i > 0) {
      b.write('_');
    }
    b.writeCharCode(isUpperAscii ? code + 0x20 : code);
  }
  return b.toString();
}

String _snakeToCamelToken(String input) {
  final parts = input.split('_');
  if (parts.isEmpty) return input;
  final b = StringBuffer(parts.first);
  for (var i = 1; i < parts.length; i++) {
    final p = parts[i];
    if (p.isEmpty) continue;
    final firstCode = p.codeUnitAt(0);
    b.writeCharCode(
      firstCode >= 0x61 && firstCode <= 0x7A ? firstCode - 0x20 : firstCode,
    );
    if (p.length > 1) {
      b.write(p.substring(1));
    }
  }
  return b.toString();
}

dynamic _convertKeysRecursive(
  dynamic value,
  String Function(String) transform,
) {
  if (value is Map) {
    return value.map<dynamic, dynamic>(
      (k, v) => MapEntry(
        k is String ? transform(k) : k,
        _convertKeysRecursive(v, transform),
      ),
    );
  }
  if (value is List) {
    return value.map((e) => _convertKeysRecursive(e, transform)).toList();
  }
  return value;
}

dynamic convertKeysToSnake(dynamic value) =>
    _convertKeysRecursive(value, _camelToSnakeToken);

dynamic convertKeysToCamel(dynamic value) =>
    _convertKeysRecursive(value, _snakeToCamelToken);
