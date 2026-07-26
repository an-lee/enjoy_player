import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/audio_api.dart';
import 'package:enjoy_player/data/api/services/video_api.dart';
import 'package:enjoy_player/features/cloud/data/cloud_index_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

final _dummyClient = ApiClient(
  httpClient: http.Client(),
  getBaseUrl: () async => 'http://localhost',
  getAccessToken: () async => null,
);

class _FakeAudioApi extends AudioApi {
  _FakeAudioApi(this._rows) : super(_dummyClient);

  final List<Map<String, dynamic>> _rows;

  @override
  Future<List<Map<String, dynamic>>> audios({
    String? provider,
    int? limit,
    String? updatedAfter,
  }) async {
    return _rows;
  }
}

class _FakeVideoApi extends VideoApi {
  _FakeVideoApi(this._rows) : super(_dummyClient);

  final List<Map<String, dynamic>> _rows;

  @override
  Future<List<Map<String, dynamic>>> videos({
    String? provider,
    int? limit,
    String? updatedAfter,
  }) async {
    return _rows;
  }
}

Map<String, dynamic> _audioJson(String id, {String? updatedAt}) => {
  'id': id,
  'aid': 'aid_$id',
  'provider': 'local',
  'title': 'Audio $id',
  'duration': 120,
  'updatedAt': updatedAt ?? '2026-01-01T00:00:00.000Z',
  'createdAt': '2026-01-01T00:00:00.000Z',
};

Map<String, dynamic> _videoJson(String id, {String? updatedAt}) => {
  'id': id,
  'vid': 'vid_$id',
  'provider': 'youtube',
  'title': 'Video $id',
  'duration': 360,
  'updatedAt': updatedAt ?? '2026-01-01T00:00:00.000Z',
  'createdAt': '2026-01-01T00:00:00.000Z',
};

void main() {
  group('CloudIndexRepository.fetchAudios', () {
    test('maps audio rows to RemoteLibraryItem (isVideo=false)', () async {
      final repo = CloudIndexRepository(
        audioApi: _FakeAudioApi(<Map<String, dynamic>>[_audioJson('a1')]),
        videoApi: _FakeVideoApi(<Map<String, dynamic>>[]),
      );

      final items = await repo.fetchAudios();
      expect(items, hasLength(1));
      expect(items.first.id, 'a1');
      expect(items.first.isVideo, isFalse);
      expect(items.first.title, 'Audio a1');
      expect(items.first.durationSeconds, 120);
      expect(items.first.provider, 'local');
      expect(items.first.rawJson['id'], 'a1');
    });

    test('passes updatedAfter to the audio API', () async {
      String? seenUpdatedAfter;
      final fake = _CapturingAudioApi((updatedAfter) {
        seenUpdatedAfter = updatedAfter;
      });
      final repo = CloudIndexRepository(
        audioApi: fake,
        videoApi: _FakeVideoApi(<Map<String, dynamic>>[]),
      );

      await repo.fetchAudios(updatedAfter: '2026-05-01T00:00:00Z');
      expect(seenUpdatedAfter, '2026-05-01T00:00:00Z');
    });

    test('returns empty list when no audios', () async {
      final repo = CloudIndexRepository(
        audioApi: _FakeAudioApi(<Map<String, dynamic>>[]),
        videoApi: _FakeVideoApi(<Map<String, dynamic>>[]),
      );
      expect(await repo.fetchAudios(), isEmpty);
    });

    test('pageSize is 50', () {
      expect(CloudIndexRepository.pageSize, 50);
    });
  });

  group('CloudIndexRepository.fetchVideos', () {
    test('maps video rows to RemoteLibraryItem (isVideo=true)', () async {
      final repo = CloudIndexRepository(
        audioApi: _FakeAudioApi(<Map<String, dynamic>>[]),
        videoApi: _FakeVideoApi(<Map<String, dynamic>>[_videoJson('v1')]),
      );

      final items = await repo.fetchVideos();
      expect(items, hasLength(1));
      expect(items.first.id, 'v1');
      expect(items.first.isVideo, isTrue);
      expect(items.first.title, 'Video v1');
      expect(items.first.durationSeconds, 360);
      expect(items.first.provider, 'youtube');
    });

    test('passes updatedAfter to the video API', () async {
      String? seenUpdatedAfter;
      final fake = _CapturingVideoApi((updatedAfter) {
        seenUpdatedAfter = updatedAfter;
      });
      final repo = CloudIndexRepository(
        audioApi: _FakeAudioApi(<Map<String, dynamic>>[]),
        videoApi: fake,
      );

      await repo.fetchVideos(updatedAfter: '2026-06-01T00:00:00Z');
      expect(seenUpdatedAfter, '2026-06-01T00:00:00Z');
    });

    test('returns empty list when no videos', () async {
      final repo = CloudIndexRepository(
        audioApi: _FakeAudioApi(<Map<String, dynamic>>[]),
        videoApi: _FakeVideoApi(<Map<String, dynamic>>[]),
      );
      expect(await repo.fetchVideos(), isEmpty);
    });
  });
}

class _CapturingAudioApi extends AudioApi {
  _CapturingAudioApi(this._onCall) : super(_dummyClient);

  final void Function(String? updatedAfter) _onCall;

  @override
  Future<List<Map<String, dynamic>>> audios({
    String? provider,
    int? limit,
    String? updatedAfter,
  }) async {
    _onCall(updatedAfter);
    return const <Map<String, dynamic>>[];
  }
}

class _CapturingVideoApi extends VideoApi {
  _CapturingVideoApi(this._onCall) : super(_dummyClient);

  final void Function(String? updatedAfter) _onCall;

  @override
  Future<List<Map<String, dynamic>>> videos({
    String? provider,
    int? limit,
    String? updatedAfter,
  }) async {
    _onCall(updatedAfter);
    return const <Map<String, dynamic>>[];
  }
}
