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
}
