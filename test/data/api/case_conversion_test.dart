/// Tests for the recursive camelCase ↔ snake_case key conversion helpers used
/// by [ApiClient] and friends to bridge the JSON-over-HTTP seam with the
/// Dart codebase's snake_case domain types.
library;

import 'package:enjoy_player/data/api/case_conversion.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('convertKeysToSnake', () {
    test('renames top-level camelCase keys to snake_case', () {
      final result = convertKeysToSnake({'userId': 1, 'firstName': 'Alice'});
      expect(result, {'user_id': 1, 'first_name': 'Alice'});
    });

    test('passes through single-word lowercase keys unchanged', () {
      expect(convertKeysToSnake({'id': 1, 'name': 'x'}), {
        'id': 1,
        'name': 'x',
      });
    });

    test('recurses into nested maps', () {
      final result = convertKeysToSnake({
        'userData': {'firstName': 'Alice', 'lastName': 'Doe'},
      });
      expect(result, {
        'user_data': {'first_name': 'Alice', 'last_name': 'Doe'},
      });
    });

    test('recurses into lists of maps', () {
      final result = convertKeysToSnake({
        'items': [
          {'userId': 1, 'firstName': 'Alice'},
          {'userId': 2, 'firstName': 'Bob'},
        ],
      });
      expect(result, {
        'items': [
          {'user_id': 1, 'first_name': 'Alice'},
          {'user_id': 2, 'first_name': 'Bob'},
        ],
      });
    });

    test('preserves list order and scalar list contents', () {
      final result = convertKeysToSnake({
        'scores': [10, 20, 30],
        'flags': [true, false],
      });
      expect(result, {
        'scores': [10, 20, 30],
        'flags': [true, false],
      });
    });

    test('preserves non-string map keys verbatim', () {
      // Symmetric mapping type is `Map<dynamic, dynamic>`, but most call sites
      // use String keys. Keep non-string keys stable.
      final input = <dynamic, dynamic>{1: 'a', 'userId': 2};
      final result = convertKeysToSnake(input);
      expect(result[1], 'a');
      expect(result['user_id'], 2);
    });

    test('returns scalar values unchanged', () {
      expect(convertKeysToSnake('hello'), 'hello');
      expect(convertKeysToSnake(42), 42);
      expect(convertKeysToSnake(null), null);
      expect(convertKeysToSnake(true), true);
    });

    test('handles empty map and empty list inputs', () {
      expect(convertKeysToSnake(<String, dynamic>{}), <String, dynamic>{});
      expect(convertKeysToSnake(<dynamic>[]), <dynamic>[]);
    });

    test('handles deeply nested mixed structure', () {
      final input = {
        'userData': {
          'firstName': 'Alice',
          'addresses': [
            {'streetName': 'Main St', 'zipCode': 12345},
          ],
        },
        'createdAt': '2026-06-25T08:00:00Z',
      };
      final result = convertKeysToSnake(input);
      expect(result, {
        'user_data': {
          'first_name': 'Alice',
          'addresses': [
            {'street_name': 'Main St', 'zip_code': 12345},
          ],
        },
        'created_at': '2026-06-25T08:00:00Z',
      });
    });

    test('preserves non-ASCII key characters unchanged', () {
      // Non-ASCII keys (e.g. localized metadata) are not in the API contract
      // but the helper must not corrupt them — lock in the original
      // Unicode-aware behaviour.
      final result = convertKeysToSnake({'caféName': 1, 'naïve': 2});
      expect(result['caféName'], 1);
      expect(result['naïve'], 2);
    });
  });

  group('convertKeysToCamel', () {
    test('renames top-level snake_case keys to camelCase', () {
      final result = convertKeysToCamel({'user_id': 1, 'first_name': 'Alice'});
      expect(result, {'userId': 1, 'firstName': 'Alice'});
    });

    test('passes through single-word lowercase keys unchanged', () {
      expect(convertKeysToCamel({'id': 1, 'name': 'x'}), {
        'id': 1,
        'name': 'x',
      });
    });

    test('recurses into nested maps', () {
      final result = convertKeysToCamel({
        'user_data': {'first_name': 'Alice', 'last_name': 'Doe'},
      });
      expect(result, {
        'userData': {'firstName': 'Alice', 'lastName': 'Doe'},
      });
    });

    test('recurses into lists of maps', () {
      final result = convertKeysToCamel({
        'items': [
          {'user_id': 1, 'first_name': 'Alice'},
          {'user_id': 2, 'first_name': 'Bob'},
        ],
      });
      expect(result, {
        'items': [
          {'userId': 1, 'firstName': 'Alice'},
          {'userId': 2, 'firstName': 'Bob'},
        ],
      });
    });

    test('preserves list order and scalar list contents', () {
      final result = convertKeysToCamel({
        'scores': [10, 20, 30],
        'flags': [true, false],
      });
      expect(result, {
        'scores': [10, 20, 30],
        'flags': [true, false],
      });
    });

    test('preserves non-string map keys verbatim', () {
      final input = <dynamic, dynamic>{1: 'a', 'user_id': 2};
      final result = convertKeysToCamel(input);
      expect(result[1], 'a');
      expect(result['userId'], 2);
    });

    test('returns scalar values unchanged', () {
      expect(convertKeysToCamel('hello'), 'hello');
      expect(convertKeysToCamel(42), 42);
      expect(convertKeysToCamel(null), null);
      expect(convertKeysToCamel(true), true);
    });

    test('handles empty map and empty list inputs', () {
      expect(convertKeysToCamel(<String, dynamic>{}), <String, dynamic>{});
      expect(convertKeysToCamel(<dynamic>[]), <dynamic>[]);
    });

    test('collapses consecutive underscores between segments', () {
      // `__` has no real-world source in the API contract, but the helper
      // currently drops the empty segment rather than emitting `__`. Lock that
      // in so behavior stays predictable if the wire format ever shifts.
      final result = convertKeysToCamel({'user__id': 1});
      expect(result, {'userId': 1});
    });
  });

  group('round-trip convertKeysToSnake → convertKeysToCamel', () {
    test('is the identity for simple camelCase maps', () {
      const input = {'userId': 1, 'firstName': 'Alice'};
      final roundTripped = convertKeysToCamel(convertKeysToSnake(input));
      expect(roundTripped, input);
    });

    test('is the identity for nested mixed structures', () {
      final input = {
        'userData': {
          'firstName': 'Alice',
          'addresses': [
            {'streetName': 'Main St', 'zipCode': 12345},
          ],
        },
        'createdAt': '2026-06-25T08:00:00Z',
      };
      final roundTripped = convertKeysToCamel(convertKeysToSnake(input));
      expect(roundTripped, input);
    });
  });
}
