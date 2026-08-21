/// Tests for the Crafted Audio Cloud Sync branch of
/// [SyncUploadService.uploadAudio].
///
/// Verifies:
/// - `provider = 'craft'` rows trigger the binary upload pre-step and
///   the resulting `signedId` is included in the JSON payload.
/// - `provider = 'user'` and `provider = 'youtube'` rows DO NOT trigger
///   the uploader (SC-003 — only crafted audios are uploaded automatically).
/// - The server's `mediaUrl` is stamped on the row on success.
library;

import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/audio_api.dart';
import 'package:enjoy_player/data/api/services/direct_uploads_api.dart';
import 'package:enjoy_player/data/api/services/recording_api.dart';
import 'package:enjoy_player/data/api/services/video_api.dart';
import 'package:enjoy_player/data/api/services/vocabulary_api.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/craft/application/craft_audio_cloud_uploader.dart';
import 'package:enjoy_player/features/sync/data/sync_upload_service.dart';

import '../../support/test_path_provider.dart';

final _now = DateTime.utc(2026, 6, 1);

ApiClient _client(MockClient mock) => ApiClient(
  httpClient: mock,
  getBaseUrl: () async => 'https://enjoy.example.com',
  getAccessToken: () async => 'tok',
);

SyncUploadService _serviceWithUploader(
  AppDatabase db,
  ApiClient client,
  CraftAudioCloudUploader uploader,
) => SyncUploadService(
  db: db,
  audioApi: AudioApi(client),
  videoApi: VideoApi(client),
  recordingApi: RecordingApi(client),
  vocabularyApi: VocabularyApi(client),
  craftAudioCloudUploader: uploader,
);

SyncUploadService _serviceNoUploader(AppDatabase db, ApiClient client) =>
    SyncUploadService(
      db: db,
      audioApi: AudioApi(client),
      videoApi: VideoApi(client),
      recordingApi: RecordingApi(client),
      vocabularyApi: VocabularyApi(client),
    );

AudioRow _row({
  String id = 'aud-craft-1',
  String provider = 'craft',
  String? mediaUrl,
  String? localUri,
  String? md5,
  int? size,
  String syncStatus = 'pending',
}) => AudioRow(
  id: id,
  aid: id,
  provider: provider,
  title: 'Test Audio',
  description: null,
  thumbnailUrl: null,
  durationSeconds: 30,
  language: 'en',
  translationKey: null,
  sourceText: 'hello',
  voice: 'alloy',
  source: 'craft-direct',
  localUri: localUri,
  localMtimeMs: null,
  md5: md5,
  size: size,
  mediaUrl: mediaUrl,
  syncStatus: syncStatus,
  serverUpdatedAt: null,
  createdAt: _now,
  updatedAt: _now,
);

void main() {
  late AppDatabase db;
  late PathProviderPlatform originalPathProvider;
  late Directory docsRoot;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    originalPathProvider = PathProviderPlatform.instance;
    docsRoot = Directory.systemTemp.createTempSync('enjoy_craft_sync');
    PathProviderPlatform.instance = TestPathProvider(docsRoot.path);
  });

  tearDown(() async {
    PathProviderPlatform.instance = originalPathProvider;
    await db.close();
    if (docsRoot.existsSync()) {
      docsRoot.deleteSync(recursive: true);
    }
  });

  group('Crafted Audio Cloud Sync branch', () {
    test(
      'crafted row sends signedId in JSON payload when uploader returns it',
      () async {
        // Write a real audio file into the app-managed media directory so
        // `isAppManagedMediaPath()` returns true and `readAppManagedMedia()`
        // finds the bytes.
        final mediaDir = Directory(p.join(docsRoot.path, 'media'))
          ..createSync();
        final audioFile = File(p.join(mediaDir.path, 'abc.wav'));
        audioFile.writeAsBytesSync([1, 2, 3, 4, 5, 6, 7, 8]);
        final localUri = Uri.file(audioFile.path).toString();

        // Stub: direct-uploads POST returns a signedId + a (mock) PUT URL.
        // The PUT is just a 200 OK; we don't care about the bytes.
        final mock = MockClient((req) async {
          if (req.url.path == '/api/v1/direct_uploads') {
            return http.Response(
              jsonEncode({
                'signedId': 'signed-id-craft-12345',
                'directUpload': {
                  'url': 'https://storage.example.com/upload',
                  'headers': {'Content-Type': 'audio/wav'},
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          // Catch-all for the PUT to the storage backend (absolute URL).
          if (req.method == 'PUT') {
            return http.Response('', 200);
          }
          if (req.url.path == '/api/v1/mine/audios' && req.method == 'POST') {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            final audio = body['audio'] as Map<String, dynamic>;
            // ApiClient converts camelCase to snake_case on the wire; the
            // server reads `signed_id`. Verify it round-trips.
            expect(
              audio['signed_id'],
              'signed-id-craft-12345',
              reason: 'crafted upload must include the blob signed_id',
            );
            // Provider must remain 'craft'.
            expect(audio['provider'], 'craft');
            // mediaUrl in payload should be null (we haven't synced yet).
            expect(audio.containsKey('mediaUrl'), isFalse);
            return http.Response(
              jsonEncode({
                'audio': {
                  'id': audio['id'],
                  'aid': audio['aid'],
                  'provider': 'craft',
                  'title': audio['title'],
                  'mediaUrl': 'https://cdn.example.com/audios/abc.wav',
                  'updatedAt': '2026-06-01T00:00:01.000Z',
                  'createdAt': '2026-06-01T00:00:00.000Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        });

        final apiClient = _client(mock);
        final uploader = CraftAudioCloudUploader(
          fileStorage: FileStorage(),
          directUploadsApi: DirectUploadsApi(apiClient),
        );
        final svc = _serviceWithUploader(db, apiClient, uploader);

        final row = _row(
          id: 'aud-craft-1',
          provider: 'craft',
          localUri: localUri,
          md5: 'abcdef1234567890',
          size: 8,
          mediaUrl: null,
        );
        // The file at `localUri` is under `{docs}/media/`, so
        // `isAppManagedMediaPath()` returns true and the uploader reads the
        // bytes via `FileStorage.readAppManagedMedia`.
        await svc.uploadAudio(row);

        // Verify the row got mediaUrl stamped from the server response.
        final reloaded = await db.audioDao.getById(row.id);
        expect(reloaded, isNotNull);
        expect(reloaded!.mediaUrl, 'https://cdn.example.com/audios/abc.wav');
        expect(reloaded.syncStatus, 'synced');
      },
    );

    test('provider=user row does not trigger the uploader (SC-003)', () async {
      // Track whether direct_uploads was ever hit.
      var directUploadsCalled = false;

      final mock = MockClient((req) async {
        if (req.url.path == '/api/v1/direct_uploads') {
          directUploadsCalled = true;
          return http.Response('should not be called', 500);
        }
        if (req.url.path == '/api/v1/mine/audios' && req.method == 'POST') {
          final body = jsonDecode(req.body) as Map<String, dynamic>;
          final audio = body['audio'] as Map<String, dynamic>;
          // CRITICAL: signedId MUST NOT be in the JSON body for user imports.
          expect(
            audio.containsKey("signed_id"),
            isFalse,
            reason: 'user-imported audio must not include a signedId',
          );
          expect(audio['provider'], 'user');
          return http.Response(
            jsonEncode({
              'audio': {
                'id': audio['id'],
                'aid': audio['aid'],
                'provider': 'user',
                'title': audio['title'],
                'updatedAt': '2026-06-01T00:00:01.000Z',
                'createdAt': '2026-06-01T00:00:00.000Z',
              },
            }),
            200,
            headers: {'content-type': 'application/json'},
          );
        }
        return http.Response('not found', 404);
      });

      final apiClient = _client(mock);
      final uploader = CraftAudioCloudUploader(
        fileStorage: FileStorage(),
        directUploadsApi: DirectUploadsApi(apiClient),
      );
      final svc = _serviceWithUploader(db, apiClient, uploader);

      final row = _row(
        id: 'aud-user-1',
        provider: 'user',
        localUri: 'file:///tmp/imported.mp3',
        md5: 'abc123',
        size: 4096,
        mediaUrl: null,
      );
      await svc.uploadAudio(row);

      expect(directUploadsCalled, isFalse, reason: 'SC-003 violation');
    });

    test(
      'provider=youtube row does not trigger the uploader (SC-003)',
      () async {
        var directUploadsCalled = false;

        final mock = MockClient((req) async {
          if (req.url.path == '/api/v1/direct_uploads') {
            directUploadsCalled = true;
            return http.Response('should not be called', 500);
          }
          if (req.url.path == '/api/v1/mine/audios' && req.method == 'POST') {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            final audio = body['audio'] as Map<String, dynamic>;
            expect(audio.containsKey("signed_id"), isFalse);
            expect(audio['provider'], 'youtube');
            return http.Response(
              jsonEncode({
                'audio': {
                  'id': audio['id'],
                  'aid': audio['aid'],
                  'provider': 'youtube',
                  'title': audio['title'],
                  'updatedAt': '2026-06-01T00:00:01.000Z',
                  'createdAt': '2026-06-01T00:00:00.000Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        });

        final apiClient = _client(mock);
        final uploader = CraftAudioCloudUploader(
          fileStorage: FileStorage(),
          directUploadsApi: DirectUploadsApi(apiClient),
        );
        final svc = _serviceWithUploader(db, apiClient, uploader);

        final row = _row(
          id: 'aud-yt-1',
          provider: 'youtube',
          localUri: null,
          mediaUrl: null,
        );
        await svc.uploadAudio(row);

        expect(directUploadsCalled, isFalse, reason: 'SC-003 violation');
      },
    );

    test(
      'crafted row with no uploader wired still uploads (no crash, no signedId)',
      () async {
        final mock = MockClient((req) async {
          if (req.url.path == '/api/v1/mine/audios' && req.method == 'POST') {
            final body = jsonDecode(req.body) as Map<String, dynamic>;
            final audio = body['audio'] as Map<String, dynamic>;
            expect(audio.containsKey("signed_id"), isFalse);
            return http.Response(
              jsonEncode({
                'audio': {
                  'id': audio['id'],
                  'aid': audio['aid'],
                  'provider': 'craft',
                  'title': audio['title'],
                  'updatedAt': '2026-06-01T00:00:01.000Z',
                  'createdAt': '2026-06-01T00:00:00.000Z',
                },
              }),
              200,
              headers: {'content-type': 'application/json'},
            );
          }
          return http.Response('not found', 404);
        });

        // Note: deliberately NOT wiring the uploader — service should still
        // work in legacy configurations.
        final svc = _serviceNoUploader(db, _client(mock));
        final row = _row(
          id: 'aud-craft-legacy',
          provider: 'craft',
          localUri: 'file:///tmp/legacy.wav',
        );
        await svc.uploadAudio(row);
      },
    );
  });
}
