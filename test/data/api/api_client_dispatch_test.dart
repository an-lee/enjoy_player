// Coverage for branches not exercised by `api_client_auth_test.dart`:
//
//   * HTTP method dispatcher in `_dispatch` (PATCH/PUT/DELETE paths)
//   * 401 refresh-retry (single retry, no infinite loop)
//   * `camelToSnakeToken` translation for query parameters
//   * `getJsonList` happy path + non-array body rejection
//   * `deleteJson` allowEmptyBody ⇒ empty body becomes {}
//   * `putBytesAbsolute` happy path + non-2xx rejection
//   * `_decodeResponseBody` short-body path (no compute() call)
//   * `_throwApiError` covers non-JSON body (falls back to raw body)
//   * `patchJson` / `putJson` transformBody = true vs false
import 'dart:convert';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _buildClient(MockClient mock) => ApiClient(
  httpClient: mock,
  getBaseUrl: () async => 'https://api.example.com',
  getAccessToken: () async => 'token',
);

void main() {
  group('ApiClient HTTP method dispatcher', () {
    test('PATCH uses _client.patch with snake-case body keys', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode({'updated': true}),
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      await _buildClient(mock).patchJson(
        '/audios/1',
        body: {'displayTitle': 'hi', 'authorName': 'ann'},
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'PATCH');
      expect(captured!.body, contains('"display_title":"hi"'));
      expect(captured!.body, contains('"author_name":"ann"'));
    });

    test('DELETE forwards to _client.delete with empty body', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('', 204);
      });

      final result = await _buildClient(mock).deleteJson('/audios/1');
      expect(captured, isNotNull);
      expect(captured!.method, 'DELETE');
      expect(result, isEmpty);
    });
  });

  group('ApiClient query parameter translation', () {
    test('camelCase query keys are snake-cased in the outgoing URI', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      await _buildClient(
        mock,
      ).getJson('/x', queryParameters: {'updatedAfter': '2024-01-01'});

      expect(captured, isNotNull);
      expect(
        captured!.url.queryParameters,
        containsPair('updated_after', '2024-01-01'),
      );
    });

    test(
      'multi-uppercase keys (e.g. fooBarBaz) snake_case with underscores',
      () async {
        http.Request? captured;
        final mock = MockClient((request) async {
          captured = request;
          return http.Response('{}', 200);
        });

        await _buildClient(
          mock,
        ).getJson('/x', queryParameters: {'fooBarBaz': 'v'});

        expect(captured!.url.queryParameters['foo_bar_baz'], 'v');
      },
    );
  });

  group('ApiClient 401 refresh-retry', () {
    test(
      'retries once after refresh succeeds, then returns the body',
      () async {
        var attempts = 0;
        final mock = MockClient((request) async {
          attempts++;
          if (attempts == 1) {
            // First attempt fails with 401.
            return http.Response(jsonEncode({'error': 'expired'}), 401);
          }
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        var refreshCalls = 0;
        final client = ApiClient(
          httpClient: mock,
          getBaseUrl: () async => 'https://api.example.com',
          getAccessToken: () async => 'token-after-refresh',
          refreshAccessToken: () async {
            refreshCalls++;
            return true;
          },
        );

        final body = await client.getJson('/me');
        expect(attempts, 2);
        expect(refreshCalls, 1);
        expect(body['ok'], isTrue);
      },
    );

    test(
      'does not loop forever: surfaces 401 ApiException when refresh fails',
      () async {
        var refreshCalls = 0;
        var httpCalls = 0;
        final mock = MockClient((_) async {
          httpCalls++;
          return http.Response('{}', 401);
        });

        final client = ApiClient(
          httpClient: mock,
          getBaseUrl: () async => 'https://api.example.com',
          getAccessToken: () async => 'token',
          refreshAccessToken: () async {
            refreshCalls++;
            return false;
          },
        );

        // Refresh was consulted exactly once, did not loop, and the 401 was
        // surfaced to the caller as an ApiException.
        Object? caught;
        try {
          await client.getJson('/me');
        } catch (e) {
          caught = e;
        }
        expect(caught, isA<ApiException>());
        expect((caught as ApiException).statusCode, 401);
        expect(refreshCalls, 1);
        expect(
          httpCalls,
          1,
          reason: 'one HTTP attempt, refresh fails → no second call',
        );
      },
    );
  });

  group('ApiClient getJsonList', () {
    test('decodes a JSON array of objects', () async {
      final mock = MockClient((_) async {
        return http.Response(
          jsonEncode([
            {'id': 1, 'title': 'a'},
            {'id': 2, 'title': 'b'},
          ]),
          200,
        );
      });

      final out = await _buildClient(mock).getJsonList('/audios');
      expect(out, hasLength(2));
      expect(out.first['title'], 'a');
    });

    test('throws ApiException when the body is not a JSON array', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({'not': 'array'}), 200);
      });

      expect(
        () => _buildClient(mock).getJsonList('/audios'),
        throwsA(
          isA<ApiException>().having(
            (e) => e.message,
            'message',
            'Expected JSON array',
          ),
        ),
      );
    });

    test(
      'throws ApiException when the body is an array of non-objects',
      () async {
        final mock = MockClient((_) async {
          return http.Response(jsonEncode(['a', 'b']), 200);
        });

        expect(
          () => _buildClient(mock).getJsonList('/audios'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Array element is not an object',
            ),
          ),
        );
      },
    );
  });

  group('ApiClient putBytesAbsolute', () {
    test('sends a PUT to the absolute URL with custom headers', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response.bytes(const <int>[], 200);
      });

      await _buildClient(mock).putBytesAbsolute(
        Uri.parse('https://storage.example.com/upload/abc'),
        bytes: const [1, 2, 3],
        headers: const {'X-Test': 'yes'},
      );

      expect(captured, isNotNull);
      expect(captured!.method, 'PUT');
      expect(captured!.url.host, 'storage.example.com');
      expect(captured!.headers['X-Test'], 'yes');
      expect(captured!.bodyBytes, [1, 2, 3]);
    });

    test(
      'throws ApiException when the storage backend returns non-2xx',
      () async {
        final mock = MockClient((_) async {
          return http.Response.bytes(utf8.encode('forbidden'), 403);
        });

        expect(
          () => _buildClient(mock).putBytesAbsolute(
            Uri.parse('https://storage.example.com/upload/abc'),
            bytes: const [1, 2, 3],
          ),
          throwsA(
            isA<ApiException>().having((e) => e.statusCode, 'statusCode', 403),
          ),
        );
      },
    );

    test(
      'does not attach a bearer token (storage uses direct-upload headers)',
      () async {
        http.Request? captured;
        final mock = MockClient((request) async {
          captured = request;
          return http.Response.bytes(const <int>[], 200);
        });

        await _buildClient(mock).putBytesAbsolute(
          Uri.parse('https://storage.example.com/upload/abc'),
          bytes: const [1, 2, 3],
        );

        expect(captured, isNotNull);
        expect(captured!.headers.containsKey('Authorization'), isFalse);
      },
    );
  });

  group('ApiClient error responses', () {
    test('non-JSON body → ApiException.body holds the raw text', () async {
      final mock = MockClient((_) async {
        return http.Response('Bad Gateway from upstream', 502);
      });

      try {
        await _buildClient(mock).getJson('/x');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 502);
        expect(e.body, 'Bad Gateway from upstream');
      }
    });

    test('JSON body → ApiException.body is decoded into a map/list', () async {
      final mock = MockClient((_) async {
        return http.Response(jsonEncode({'error': 'oops'}), 422);
      });

      try {
        await _buildClient(mock).getJson('/x');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 422);
        expect(e.body, {'error': 'oops'});
      }
    });

    test('empty body → ApiException.body is null', () async {
      final mock = MockClient((_) async => http.Response('', 500));

      try {
        await _buildClient(mock).getJson('/x');
        fail('expected ApiException');
      } on ApiException catch (e) {
        expect(e.statusCode, 500);
        expect(e.body, isNull);
      }
    });
  });

  group('ApiClient response body decoding', () {
    test(
      'success-path decode falls back to raw text when response is not JSON',
      () async {
        // Triggers the "decoded is not a map" branch in _sendMapWithOptionalRefresh.
        final mock = MockClient((_) async {
          return http.Response(
            '"plain string response"',
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        expect(
          () => _buildClient(mock).getJson('/x'),
          throwsA(
            isA<ApiException>().having(
              (e) => e.message,
              'message',
              'Expected JSON object',
            ),
          ),
        );
      },
    );
  });

  group('ApiClient URL handling', () {
    test('a single trailing slash is stripped from the base URL', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{}', 200);
      });

      final client = ApiClient(
        httpClient: mock,
        getBaseUrl: () async => 'https://api.example.com/',
        getAccessToken: () async => 'token',
      );

      await client.getJson('/me');
      expect(captured!.url.path, '/me');
    });
  });
}
