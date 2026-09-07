import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/recording_api.dart';

void main() {
  group('RecordingApi', () {
    late List<http.Request> captured;
    late RecordingApi api;

    setUp(() {
      captured = [];
      final mock = MockClient((request) async {
        captured.add(request);
        if (request.method == 'GET' &&
            request.url.path.endsWith('/recordings')) {
          return http.Response(
            jsonEncode([
              {'id': 'rec-1', 'targetId': 'a1', 'targetType': 'Video'},
            ]),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'GET') {
          return http.Response(
            jsonEncode({
              'recording': {'id': 'rec-1'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'POST') {
          return http.Response(
            jsonEncode({
              'recording': {
                'id': 'rec-new',
                'updatedAt': '2026-01-01T00:00:00Z',
              },
            }),
            201,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'DELETE') {
          return http.Response(
            jsonEncode({'success': true}),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        if (request.method == 'PUT') {
          return http.Response(
            jsonEncode({
              'recording': {'id': 'rec-1', 'updatedAt': '2026-01-02T00:00:00Z'},
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      api = RecordingApi(
        ApiClient(
          httpClient: mock,
          getBaseUrl: () async => 'https://api.example.com',
          getAccessToken: () async => 'test-token',
        ),
        clientPlatform: 'linux',
      );
    });

    test('recordings sends query parameters', () async {
      await api.recordings(
        targetId: 'media-1',
        targetType: 'Video',
        language: 'en',
        limit: 10,
        updatedAfter: '2026-01-01T00:00:00Z',
      );

      expect(captured, hasLength(1));
      final url = captured.first.url;
      expect(url.path, '/api/v1/mine/recordings');
      expect(url.queryParameters['target_id'], 'media-1');
      expect(url.queryParameters['target_type'], 'Video');
      expect(url.queryParameters['language'], 'en');
      expect(url.queryParameters['limit'], '10');
      expect(url.queryParameters['updated_after'], '2026-01-01T00:00:00Z');
    });

    test('recordings omits null parameters', () async {
      await api.recordings();

      expect(captured, hasLength(1));
      final url = captured.first.url;
      expect(url.queryParameters.containsKey('targetId'), isFalse);
      expect(url.queryParameters.containsKey('limit'), isFalse);
    });

    test('recording fetches by id', () async {
      await api.recording('rec-1');

      expect(captured, hasLength(1));
      expect(captured.first.url.path, '/api/v1/mine/recordings/rec-1');
      expect(captured.first.method, 'GET');
    });

    test('uploadRecording sends payload with clientPlatform', () async {
      await api.uploadRecording({
        'id': 'rec-1',
        'targetId': 'media-1',
        'targetType': 'Video',
        'duration': 500,
        'md5': 'abc123',
        'referenceText': 'hello',
        'referenceStart': 0,
        'referenceDuration': 1000,
        'language': 'en',
        'createdAt': '2026-01-01T00:00:00Z',
        'updatedAt': '2026-01-01T00:00:00Z',
      });

      expect(captured, hasLength(1));
      expect(captured.first.method, 'POST');
      final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
      final recording = body['recording'] as Map<String, dynamic>;
      expect(recording['id'], 'rec-1');
      expect(recording['target_id'] ?? recording['targetId'], 'media-1');
      expect(
        recording['client_platform'] ?? recording['clientPlatform'],
        'linux',
      );
      expect(recording['duration'], 500);
    });

    test('uploadRecording omits null fields', () async {
      await api.uploadRecording({'targetId': 'media-1', 'targetType': 'Video'});

      expect(captured, hasLength(1));
      final body = jsonDecode(captured.first.body) as Map<String, dynamic>;
      final recording = body['recording'] as Map<String, dynamic>;
      expect(recording.containsKey('id'), isFalse);
      expect(recording.containsKey('md5'), isFalse);
      expect(recording.containsKey('duration'), isFalse);
      expect(
        recording['client_platform'] ?? recording['clientPlatform'],
        'linux',
      );
    });

    test('deleteRecording sends DELETE', () async {
      await api.deleteRecording('rec-1');

      expect(captured, hasLength(1));
      expect(captured.first.method, 'DELETE');
      expect(captured.first.url.path, '/api/v1/mine/recordings/rec-1');
    });
  });
}
