import 'package:enjoy_player/core/json/json_cast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('castJsonObjectOrNull', () {
    test('returns a Map<String, dynamic> as-is', () {
      final input = <String, dynamic>{'a': 1};
      expect(identical(castJsonObjectOrNull(input), input), isTrue);
    });

    test('re-keys a Map<dynamic, dynamic> via toString', () {
      final input = <dynamic, dynamic>{'a': 1, 'b': 2};
      final result = castJsonObjectOrNull(input);
      expect(result, {'a': 1, 'b': 2});
    });

    test('returns null for null', () {
      expect(castJsonObjectOrNull(null), isNull);
    });

    test('returns null for a non-Map value', () {
      expect(castJsonObjectOrNull('not a map'), isNull);
      expect(castJsonObjectOrNull(42), isNull);
      expect(castJsonObjectOrNull(<dynamic>[1, 2]), isNull);
    });
  });

  group('castJsonObject', () {
    test('returns a Map<String, dynamic> as-is', () {
      final input = <String, dynamic>{'a': 1};
      expect(identical(castJsonObject(input), input), isTrue);
    });

    test('re-keys a Map<dynamic, dynamic> via toString', () {
      final input = <dynamic, dynamic>{'a': 1};
      expect(castJsonObject(input), {'a': 1});
    });

    test('throws FormatException for null', () {
      expect(() => castJsonObject(null), throwsFormatException);
    });

    test('throws FormatException for a non-Map value', () {
      expect(() => castJsonObject('nope'), throwsFormatException);
    });
  });

  group('intFromJson', () {
    test('accepts an int directly', () {
      expect(intFromJson(7), 7);
    });

    test('truncates a num toward zero (not round)', () {
      // Truncation is deliberate: these fields are counts / timestamps /
      // durations that are semantically integers. 3.9 -> 3, not 4.
      expect(intFromJson(3.9), 3);
      expect(intFromJson(-3.9), -3);
    });

    test('parses a numeric string', () {
      expect(intFromJson('42'), 42);
    });

    test('returns null for null', () {
      expect(intFromJson(null), isNull);
    });

    test('returns null for an unparseable value', () {
      expect(intFromJson('nonsense'), isNull);
      expect(intFromJson(true), isNull);
    });
  });

  group('intOrZero', () {
    test('returns the int when parseable', () {
      expect(intOrZero(5), 5);
      expect(intOrZero('9'), 9);
    });

    test('defaults to 0 for null or unparseable', () {
      expect(intOrZero(null), 0);
      expect(intOrZero('x'), 0);
      expect(intOrZero(<String, dynamic>{}), 0);
    });
  });

  group('numOrZero', () {
    test('accepts a num directly', () {
      expect(numOrZero(3), 3);
      expect(numOrZero(2.5), 2.5);
    });

    test('parses a numeric string', () {
      expect(numOrZero('1.5'), 1.5);
    });

    test('defaults to 0 for null, unparseable string, or other types', () {
      expect(numOrZero(null), 0);
      expect(numOrZero('x'), 0);
      expect(numOrZero(true), 0);
    });
  });

  group('numOrNull', () {
    test('accepts a num directly', () {
      expect(numOrNull(3), 3);
      expect(numOrNull(2.5), 2.5);
    });

    test('parses a numeric string', () {
      expect(numOrNull('1.5'), 1.5);
    });

    test('returns null for null, unparseable string, or other types', () {
      expect(numOrNull(null), isNull);
      expect(numOrNull('x'), isNull);
      expect(numOrNull(false), isNull);
    });
  });
}
