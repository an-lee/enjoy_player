import 'dart:convert';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

/// Tests the bearer-token acquisition logic deduplicated into
/// [ApiClient] from `putBytesJson`, `postMultipartJson`, and `_dispatch`.
///
/// Exercises the helper through the public API so the three call sites stay
/// locked together. The tests cover every branch:
///   - cached token present → attached as `Authorization: Bearer <tok>`
///   - cached token empty + refresh succeeds → new token attached
///   - cached token empty + refresh fails (or missing) → 401 `ApiException`
///   - `requireAuth: false` → no auth headers (regardless of cached token)
void main() {
  group('ApiClient bearer auth', () {
    test('attaches the cached access token when present', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final client = ApiClient(
        httpClient: mock,
        getBaseUrl: () async => 'https://api.example.com',
        getAccessToken: () async => 'cached-token',
      );

      await client.getJson('/me');

      expect(captured, isNotNull);
      expect(captured!.headers['Authorization'], 'Bearer cached-token');
    });

    test(
      'refreshes when the cached token is empty and refresh succeeds',
      () async {
        http.Request? captured;
        final mock = MockClient((request) async {
          captured = request;
          return http.Response(jsonEncode({'ok': true}), 200);
        });

        var refreshCalls = 0;
        final client = ApiClient(
          httpClient: mock,
          getBaseUrl: () async => 'https://api.example.com',
          getAccessToken: () async {
            // First read returns the cached (empty) token; the second read
            // (after refresh) returns the newly minted token.
            if (refreshCalls == 0) return '';
            return 'fresh-token';
          },
          refreshAccessToken: () async {
            refreshCalls++;
            return true;
          },
        );

        await client.getJson('/me');

        expect(refreshCalls, 1);
        expect(captured, isNotNull);
        expect(captured!.headers['Authorization'], 'Bearer fresh-token');
      },
    );

    test(
      'throws 401 when the cached token is empty and refresh fails',
      () async {
        final mock = MockClient((_) async {
          fail('request should not be sent when auth cannot be established');
        });

        final client = ApiClient(
          httpClient: mock,
          getBaseUrl: () async => 'https://api.example.com',
          getAccessToken: () async => '',
          refreshAccessToken: () async => false,
        );

        expect(
          () => client.getJson('/me'),
          throwsA(
            isA<ApiException>()
                .having((e) => e.statusCode, 'statusCode', 401)
                .having((e) => e.message, 'message', 'Not authenticated'),
          ),
        );
      },
    );

    test('throws 401 when no cached token and no refresh callback', () async {
      final mock = MockClient((_) async {
        fail('request should not be sent when auth cannot be established');
      });

      final client = ApiClient(
        httpClient: mock,
        getBaseUrl: () async => 'https://api.example.com',
        getAccessToken: () async => null,
      );

      expect(
        () => client.getJson('/me'),
        throwsA(
          isA<ApiException>().having((e) => e.statusCode, 'statusCode', 401),
        ),
      );
    });

    test('skips auth when requireAuth is false', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(jsonEncode({'ok': true}), 200);
      });

      final client = ApiClient(
        httpClient: mock,
        getBaseUrl: () async => 'https://api.example.com',
        getAccessToken: () async => 'should-not-be-sent',
      );

      await client.getJson('/me', requireAuth: false);

      expect(captured, isNotNull);
      expect(captured!.headers.containsKey('Authorization'), isFalse);
    });

    test(
      'putBytesJson shares the same auth flow as the JSON dispatch path',
      () async {
        http.Request? captured;
        final mock = MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            utf8.encode('{"ok":true}'),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          httpClient: mock,
          getBaseUrl: () async => 'https://api.example.com',
          getAccessToken: () async => 'token',
        );

        await client.putBytesJson(
          '/audio/media/abc',
          bytes: [1, 2, 3],
          contentType: 'application/octet-stream',
        );

        expect(captured, isNotNull);
        expect(captured!.headers['Authorization'], 'Bearer token');
      },
    );

    test(
      'postMultipartJson shares the same auth flow as the JSON dispatch path',
      () async {
        http.Request? captured;
        final mock = MockClient((request) async {
          captured = request;
          return http.Response.bytes(
            utf8.encode('{"ok":true}'),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final client = ApiClient(
          httpClient: mock,
          getBaseUrl: () async => 'https://api.example.com',
          getAccessToken: () async => 'token',
        );

        await client.postMultipartJson(
          '/whisper',
          fileFieldName: 'audio',
          fileBytes: [1, 2, 3],
        );

        expect(captured, isNotNull);
        expect(captured!.headers['Authorization'], 'Bearer token');
      },
    );
  });
}
