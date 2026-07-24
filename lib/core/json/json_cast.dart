/// Defensive `Map<String, dynamic>` coercion for decoded JSON.
///
/// `dart:convert`-decoded JSON objects sometimes surface as
/// `Map<dynamic, dynamic>` rather than `Map<String, dynamic>` — e.g. after
/// [package:enjoy_player/data/api/case_conversion.dart] key conversion, or
/// values crossing a platform channel. A naive `is Map<String, dynamic>`
/// check silently drops such maps, so every call site needs the same
/// "accept the fast-path type, else re-key by `.toString()`" coercion.
library;

/// Returns [value] as a `Map<String, dynamic>`, re-keying a
/// `Map<dynamic, dynamic>` via `.toString()` on each key. Returns `null` if
/// [value] is not a [Map] at all (including `null`).
Map<String, dynamic>? castJsonObjectOrNull(Object? value) {
  if (value is Map<String, dynamic>) return value;
  if (value is Map) {
    return Map<String, dynamic>.from(
      value.map((k, v) => MapEntry(k.toString(), v)),
    );
  }
  return null;
}

/// Same as [castJsonObjectOrNull], but throws a [FormatException] instead of
/// returning `null` when [value] is not a JSON object.
Map<String, dynamic> castJsonObject(Object? value) {
  final map = castJsonObjectOrNull(value);
  if (map == null) {
    throw FormatException('Expected JSON object, got ${value.runtimeType}');
  }
  return map;
}

/// Coerces a JSON value to a nullable `int`.
///
/// Accepts an [int] directly, truncates a [num] (e.g. a `double` that slipped
/// in from a lenient backend) toward zero via [num.toInt], and parses a
/// [String]. Returns `null` for `null` or an unparseable value.
///
/// Truncation (not rounding) is used deliberately: these fields are counts,
/// timestamps, and durations that are semantically integers, and
/// `num.toInt()` is the conventional Dart coercion. Use [intOrZero] when a
/// non-null default is wanted.
int? intFromJson(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value.toString());
}

/// Coerces a JSON value to a non-null `int`, defaulting to `0`.
///
/// Like [intFromJson] but never returns `null` — `null`, a non-numeric type,
/// or an unparseable string all become `0`.
int intOrZero(Object? value) => intFromJson(value) ?? 0;

/// Coerces a JSON value to a non-null [num], defaulting to `0`.
///
/// Accepts a [num] directly and parses a [String]; anything else (including
/// `null`) becomes `0`.
num numOrZero(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value) ?? 0;
  return 0;
}

/// Coerces a JSON value to a nullable [num].
///
/// Accepts a [num] directly and parses a [String]; `null` or an unparseable
/// value yields `null`. Use [numOrZero] when a non-null default is wanted.
num? numOrNull(Object? value) {
  if (value is num) return value;
  if (value is String) return num.tryParse(value);
  return null;
}
