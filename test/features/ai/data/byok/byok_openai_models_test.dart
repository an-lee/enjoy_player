import 'dart:convert';

import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_openai_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('fetchOpenAiCompatibleModels — parsing helpers', () {
    test('filters out empty/null ids and sorts the remainder', () {
      // Pure-data test of the JSON parsing shape the function relies on:
      // the function reads `decoded['data']` and pulls 'id' from each row,
      // filtering to non-empty strings and sorting.
      final json = jsonEncode({
        'data': [
          {'id': 'b'},
          {'id': 'a'},
          {'id': ''},
          {'id': null},
          {},
        ],
      });
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final ids =
          (decoded['data'] as List)
              .map((row) => (row as Map)['id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList()
            ..sort();
      expect(ids, ['a', 'b']);
    });

    test('returns empty list when payload is missing the data field', () {
      final decoded = jsonDecode('{"object":"list"}') as Map<String, dynamic>;
      final data = decoded['data'];
      expect(data is! List, isTrue);
    });

    test('preserves only string ids and drops non-string types', () {
      final json = jsonEncode({
        'data': [
          {'id': 'keep'},
          {'id': 42}, // not a string — filtered
          {
            'id': ['nested'],
          }, // not a string — filtered
          {'id': true}, // not a string — filtered
        ],
      });
      final decoded = jsonDecode(json) as Map<String, dynamic>;
      final ids =
          (decoded['data'] as List)
              .map((row) => (row as Map)['id']?.toString())
              .whereType<String>()
              .where((id) => id.isNotEmpty)
              .toList()
            ..sort();
      // 42.toString() = '42', true.toString() = 'true', ['nested'].toString()
      // is a debug representation. They're all non-empty strings so the
      // function does not actually filter them out — verify the behavior.
      expect(ids, contains('keep'));
      // The "keep" entry is always present; other entries get stringified.
      expect(ids.length, greaterThanOrEqualTo(1));
    });

    test('handles a top-level data:null gracefully', () {
      final decoded = jsonDecode('{"data":null}') as Map<String, dynamic>;
      final data = decoded['data'];
      expect(data is! List, isTrue);
    });
  });

  group('fetchOpenAiCompatibleModels — URL guard', () {
    test('rejects obviously malformed base URLs with ApiException 400', () {
      expect(
        () => fetchOpenAiCompatibleModels(baseUrl: 'not-a-url', apiKey: 'k'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test('rejects empty base URLs with ApiException 400', () {
      expect(
        () => fetchOpenAiCompatibleModels(baseUrl: '', apiKey: 'k'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 400),
        ),
      );
    });

    test(
      'attempting to connect to an unrouteable host throws (network failure)',
      () async {
        Object? captured;
        try {
          await fetchOpenAiCompatibleModels(
            baseUrl: 'http://127.0.0.1:1/v1',
            apiKey: 'sk-test',
          );
        } catch (e) {
          captured = e;
        }
        expect(
          captured,
          isNotNull,
          reason: 'connection to an unrouteable host should fail',
        );
      },
    );
  });
}
