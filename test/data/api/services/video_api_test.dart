import 'dart:convert';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/video_api.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

ApiClient _client(MockClient mock) => ApiClient(
  httpClient: mock,
  getBaseUrl: () async => 'https://enjoy.example.com',
  getAccessToken: () async => 'tok',
);

Map<String, dynamic> _decode(String body) =>
    Map<String, dynamic>.from(jsonDecode(body) as Map);

void main() {
  group('VideoApi.videos', () {
    test('forwards provider, limit and updatedAfter as query params', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('[]', 200);
      });

      await VideoApi(_client(mock)).videos(
        provider: 'youtube',
        limit: 25,
        updatedAfter: '2026-01-01T00:00:00.000Z',
      );

      expect(captured!.url.path, '/api/v1/mine/videos');
      final qp = captured!.url.queryParameters;
      expect(qp['provider'], 'youtube');
      expect(qp['limit'], '25');
      expect(qp['updated_after'], '2026-01-01T00:00:00.000Z');
    });

    test('returns parsed JSON list', () async {
      final mock = MockClient((_) async {
        return http.Response(
          '[{"id": "v1"}, {"id": "v2"}]',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final list = await VideoApi(_client(mock)).videos();
      expect(list, hasLength(2));
      expect(list.first['id'], 'v1');
    });

    test('omits query params when arguments are null', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('[]', 200);
      });

      await VideoApi(_client(mock)).videos();
      expect(captured!.url.queryParameters, isEmpty);
    });
  });

  group('VideoApi.video', () {
    test('builds the per-resource path under /mine/videos', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{"id": "v1"}', 200);
      });

      final json = await VideoApi(_client(mock)).video('v1');
      expect(captured!.url.path, '/api/v1/mine/videos/v1');
      expect(json['id'], 'v1');
    });
  });

  group('VideoApi.publicVideo', () {
    test('uses the /videos (catalog) prefix, not /mine/videos', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('{"id": "v1"}', 200);
      });

      await VideoApi(_client(mock)).publicVideo('v1');
      expect(captured!.url.path, '/api/v1/videos/v1');
    });
  });

  group('VideoApi.uploadVideo', () {
    test('wraps the body under "video" and POSTs', () async {
      Map<String, dynamic>? sentBody;
      http.BaseRequest? captured;
      final mock = MockClient((request) async {
        captured = request;
        sentBody = _decode(request.body);
        return http.Response('{"video": {"id": "v1"}}', 200);
      });

      final out = await VideoApi(
        _client(mock),
      ).uploadVideo(<String, dynamic>{'id': 'v1'});
      expect(captured, isA<http.Request>());
      expect(captured!.method, 'POST');
      expect(sentBody, isNotNull);
      expect(sentBody!.containsKey('video'), isTrue);
      expect(out['video'], isA<Map>());
    });
  });

  group('VideoApi.deleteVideo', () {
    test('issues DELETE to /mine/videos/:id', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response('', 200);
      });

      await VideoApi(_client(mock)).deleteVideo('v1');
      expect(captured!.method, 'DELETE');
      expect(captured!.url.path, '/api/v1/mine/videos/v1');
    });
  });

  group('VideoApi.registerVideo', () {
    test('POSTs to the public /videos path', () async {
      http.Request? captured;
      Map<String, dynamic>? sentBody;
      final mock = MockClient((request) async {
        captured = request;
        sentBody = _decode(request.body);
        return http.Response('{"id": "v1"}', 200);
      });

      await VideoApi(
        _client(mock),
      ).registerVideo(<String, dynamic>{'id': 'v1'});
      expect(captured!.method, 'POST');
      expect(captured!.url.path, '/api/v1/videos');
      expect(sentBody!['id'], 'v1');
    });
  });

  group('VideoApi.listVideos', () {
    test(
      'returns the videos list and the pagy object from the envelope',
      () async {
        final mock = MockClient((_) async {
          return http.Response(
            jsonEncode(<String, dynamic>{
              'videos': [
                <String, dynamic>{'id': 'v1'},
                <String, dynamic>{'id': 'v2'},
              ],
              'pagy': <String, dynamic>{'page': 1, 'pages': 5},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        });

        final result = await VideoApi(
          _client(mock),
        ).listVideos(page: 1, limit: 2);
        expect(result.videos, hasLength(2));
        expect(result.videos.first['id'], 'v1');
        expect(result.pagy['pages'], 5);
      },
    );

    test('forwards filters as query params', () async {
      http.Request? captured;
      final mock = MockClient((request) async {
        captured = request;
        return http.Response(
          jsonEncode(<String, dynamic>{
            'videos': <dynamic>[],
            'pagy': <String, dynamic>{},
          }),
          200,
        );
      });

      await VideoApi(_client(mock)).listVideos(
        provider: 'youtube',
        page: 2,
        limit: 10,
        updatedAfter: '2026-01-01T00:00:00.000Z',
      );
      expect(captured!.url.path, '/api/v1/videos');
      final qp = captured!.url.queryParameters;
      expect(qp['provider'], 'youtube');
      expect(qp['page'], '2');
      expect(qp['limit'], '10');
      expect(qp['updated_after'], '2026-01-01T00:00:00.000Z');
    });

    test('throws when envelope is missing the videos list', () async {
      final mock = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{'pagy': <String, dynamic>{}}),
          200,
        );
      });
      expect(
        () => VideoApi(_client(mock)).listVideos(),
        throwsA(isA<StateError>()),
      );
    });

    test('accepts a non-Map pagy and yields an empty object', () async {
      final mock = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'videos': <dynamic>[],
            'pagy': 'not-a-map',
          }),
          200,
        );
      });
      final result = await VideoApi(_client(mock)).listVideos();
      expect(result.videos, isEmpty);
      expect(result.pagy, isEmpty);
    });

    test('throws when a video entry is not a map', () async {
      final mock = MockClient((_) async {
        return http.Response(
          jsonEncode(<String, dynamic>{
            'videos': ['not-a-map'],
            'pagy': <String, dynamic>{},
          }),
          200,
        );
      });
      expect(
        () => VideoApi(_client(mock)).listVideos(),
        throwsA(isA<StateError>()),
      );
    });
  });
}
