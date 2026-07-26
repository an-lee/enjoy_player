import 'package:enjoy_player/core/json/json_cast.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('castJsonObjectOrNull', () {
    test('returns null for null', () {
      expect(castJsonObjectOrNull(null), isNull);
    });

    test('returns null for non-Map types', () {
      expect(castJsonObjectOrNull(42), isNull);
      expect(castJsonObjectOrNull('string'), isNull);
      expect(castJsonObjectOrNull([1, 2, 3]), isNull);
    });

    test('passes through Map<String, dynamic> as the same reference', () {
      final source = {'a': 1};
      expect(castJsonObjectOrNull(source), same(source));
    });

    test('re-keys Map<dynamic, dynamic> via toString()', () {
      final raw = <dynamic, dynamic>{1: 'one', 'two': 2};
      final result = castJsonObjectOrNull(raw);
      expect(result, isA<Map<String, dynamic>>());
      expect(result!['1'], 'one');
      expect(result['two'], 2);
    });
  });

  group('castJsonObject', () {
    test('throws FormatException for non-Map values', () {
      expect(() => castJsonObject(123), throwsFormatException);
      expect(() => castJsonObject(null), throwsFormatException);
      expect(() => castJsonObject([1]), throwsFormatException);
    });

    test('returns the cast map for valid input', () {
      expect(castJsonObject({'a': 1}), {'a': 1});
    });
  });

  group('intFromJson', () {
    test('returns null for null', () {
      expect(intFromJson(null), isNull);
    });

    test('passes ints through', () {
      expect(intFromJson(5), 5);
      expect(intFromJson(-3), -3);
    });

    test('truncates doubles toward zero (num.toInt)', () {
      expect(intFromJson(3.9), 3);
      expect(intFromJson(-3.9), -3);
      expect(intFromJson(0.0), 0);
    });

    test('parses well-formed strings', () {
      expect(intFromJson('42'), 42);
      expect(intFromJson('  7  '), 7);
    });

    test('returns null for unparseable strings', () {
      expect(intFromJson('abc'), isNull);
      expect(intFromJson(<dynamic>['x']), isNull);
    });
  });

  group('intOrZero', () {
    test('defaults to 0 for null / unparseable', () {
      expect(intOrZero(null), 0);
      expect(intOrZero('abc'), 0);
      expect(intOrZero({}), 0);
    });

    test('parses numeric values', () {
      expect(intOrZero('42'), 42);
      expect(intOrZero(3.7), 3);
      expect(intOrZero(5), 5);
    });
  });

  group('numOrNull + numOrZero', () {
    test('numOrNull returns null when input is null or unparseable', () {
      expect(numOrNull(null), isNull);
      expect(numOrNull('not a number'), isNull);
      expect(numOrNull(true), isNull);
    });

    test('numOrNull accepts num values and strings', () {
      expect(numOrNull(3), 3);
      expect(numOrNull(3.14), 3.14);
      expect(numOrNull('7.5'), 7.5);
    });

    test('numOrZero defaults to 0 on null / unparseable', () {
      expect(numOrZero(null), 0);
      expect(numOrZero('garbage'), 0);
    });

    test('numOrZero parses numeric strings', () {
      expect(numOrZero('5'), 5);
      expect(numOrZero('2.5'), 2.5);
      expect(numOrZero(11), 11);
    });
  });
}
