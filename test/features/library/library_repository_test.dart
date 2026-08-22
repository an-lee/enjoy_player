import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:cross_file/cross_file.dart';
import 'package:drift/native.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/core/utils/youtube_video_identity.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/library/data/library_repository.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/test_path_provider.dart';

const _testUserId = 'test-user';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaLibraryRepository', () {
    late PathProviderPlatform original;
    late Directory root;
    late AppDatabase db;
    late MediaLibraryRepository repo;

    setUp(() {
      original = PathProviderPlatform.instance;
      root = Directory.systemTemp.createTempSync('enjoy_lib_repo_test');
      PathProviderPlatform.instance = TestPathProvider(root.path);
      db = AppDatabase(executor: NativeDatabase.memory());
      repo = MediaLibraryRepository(db, FileStorage());
    });

    tearDown(() async {
      PathProviderPlatform.instance = original;
      await db.close();
      if (root.existsSync()) {
        root.deleteSync(recursive: true);
      }
    });

    test('getById maps row to Media domain', () async {
      final now = DateTime.now();
      const id = 'id-1';
      await db.videoDao.insertRow(
        VideoRow(
          id: id,
          vid: 'hh',
          provider: 'user',
          title: 'Clip',
          description: null,
          thumbnailUrl: '/thumb.png',
          durationSeconds: 12,
          language: 'ja',
          source: null,
          localUri: 'file:///x.mp4',
          md5: null,
          size: 99,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final media = await repo.getById(id);
      expect(media, isNotNull);
      expect(media!.kind, MediaKind.video);
      expect(media.title, 'Clip');
      expect(media.durationMs, 12_000);
    });

    test('importMedia stores file and returns deterministic id', () async {
      final bytes = utf8.encode('hello-import');
      final hash = sha256.convert(bytes).toString();
      final expectedAid = enjoyLocalAudioAid(
        contentHashHex: hash,
        userId: _testUserId,
      );
      final expectedId = enjoyAudioId(aid: expectedAid);

      final src = File(p.join(root.path, 'lesson.mp3'));
      await src.writeAsBytes(bytes);

      final id = await repo.importMedia(
        XFile(src.path),
        signedInUserId: _testUserId,
      );
      expect(id, expectedId);

      final media = await repo.getById(id);
      expect(media, isNotNull);
      expect(media!.contentHash, expectedAid);
      expect(media.kind, MediaKind.audio);

      final row = await db.audioDao.getById(id);
      expect(row!.localUri, Uri.file(src.path).toString());
      expect(row.localMtimeMs, isNotNull);
    });

    test('importMedia reuses row for same fingerprint', () async {
      final bytes = utf8.encode('same-bytes-twice');
      final src = File(p.join(root.path, 'same.mp3'));
      await src.writeAsBytes(bytes);

      final id1 = await repo.importMedia(
        XFile(src.path, name: 'same.mp3'),
        signedInUserId: _testUserId,
      );
      final id2 = await repo.importMedia(
        XFile(src.path, name: 'same.mp3'),
        signedInUserId: _testUserId,
      );
      expect(id1, id2);
      expect(await db.audioDao.watchAll().first, hasLength(1));
    });

    test('importMedia copies ephemeral picker path into media/', () async {
      final tmp = Directory(p.join(root.path, '.os_tmp'))
        ..createSync(recursive: true);
      final bytes = utf8.encode('ephemeral-import');
      final src = File(p.join(tmp.path, 'cache.mp3'));
      await src.writeAsBytes(bytes);

      final id = await repo.importMedia(
        XFile(src.path, name: 'cache.mp3'),
        signedInUserId: _testUserId,
      );
      final row = await db.audioDao.getById(id);
      expect(row!.localUri, contains('/media/'));
      expect(File.fromUri(Uri.parse(row.localUri!)).existsSync(), isTrue);
    });

    test(
      'deleteMedia preserves external file and removes app-managed copy',
      () async {
        final externalBytes = utf8.encode('external-keep');
        final external = File(p.join(root.path, 'keep.mp3'));
        await external.writeAsBytes(externalBytes);

        final linkedId = await repo.importMedia(
          XFile(external.path, name: 'keep.mp3'),
          signedInUserId: _testUserId,
        );
        await repo.deleteMedia(linkedId);
        expect(external.existsSync(), isTrue);

        final tmp = Directory(p.join(root.path, '.os_tmp'))
          ..createSync(recursive: true);
        final managedSrc = File(p.join(tmp.path, 'managed.mp3'));
        await managedSrc.writeAsBytes(utf8.encode('managed-delete'));
        final managedId = await repo.importMedia(
          XFile(managedSrc.path, name: 'managed.mp3'),
          signedInUserId: 'test-user-b',
        );
        final managedRow = await db.audioDao.getById(managedId);
        final managedPath = File.fromUri(Uri.parse(managedRow!.localUri!)).path;
        expect(File(managedPath).existsSync(), isTrue);
        await repo.deleteMedia(managedId);
        expect(File(managedPath).existsSync(), isFalse);
      },
    );

    test(
      'deleteMedia keeps app-managed file when another row still references it',
      () async {
        final mediaDir = Directory(p.join(root.path, 'media'))
          ..createSync(recursive: true);
        final managed = File(p.join(mediaDir.path, 'shared.mp3'));
        await managed.writeAsBytes(utf8.encode('shared-bytes'));
        final uri = Uri.file(managed.path).toString();
        final now = DateTime.now();

        await db.audioDao.insertRow(
          AudioRow(
            id: 'keep-ref',
            aid: 'a1',
            provider: 'user',
            title: 'keep',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: uri,
            md5:
                'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
            size: managed.lengthSync(),
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.audioDao.insertRow(
          AudioRow(
            id: 'drop-ref',
            aid: 'a2',
            provider: 'user',
            title: 'drop',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: uri,
            md5:
                'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
            size: managed.lengthSync(),
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repo.deleteMedia('drop-ref');
        expect(managed.existsSync(), isTrue);
        expect(await db.audioDao.getById('keep-ref'), isNotNull);
      },
    );

    test(
      'importMedia re-link cleans previous unreferenced app-managed copy',
      () async {
        final tmp = Directory(p.join(root.path, '.os_tmp'))
          ..createSync(recursive: true);
        final bytes = utf8.encode('relink-cleanup-body');
        final ephemeral = File(p.join(tmp.path, 'ephemeral.mp3'));
        await ephemeral.writeAsBytes(bytes);

        final id = await repo.importMedia(
          XFile(ephemeral.path, name: 'ephemeral.mp3'),
          signedInUserId: _testUserId,
        );
        final afterCopy = await db.audioDao.getById(id);
        final managedPath = File.fromUri(Uri.parse(afterCopy!.localUri!)).path;
        expect(File(managedPath).existsSync(), isTrue);

        final durable = File(p.join(root.path, 'durable.mp3'));
        await durable.writeAsBytes(bytes);
        final id2 = await repo.importMedia(
          XFile(durable.path, name: 'durable.mp3'),
          signedInUserId: _testUserId,
        );
        expect(id2, id);

        final afterLink = await db.audioDao.getById(id);
        expect(afterLink!.localUri, Uri.file(durable.path).toString());
        expect(File(managedPath).existsSync(), isFalse);
      },
    );

    test('importMedia rejects unsupported image extension', () async {
      final src = File(p.join(root.path, 'photo.jpg'));
      await src.writeAsBytes([1, 2, 3]);

      await expectLater(
        repo.importMedia(
          XFile(src.path, name: 'photo.jpg'),
          signedInUserId: _testUserId,
        ),
        throwsA(isA<UnsupportedImportFileFailure>()),
      );

      expect(await db.videoDao.watchAll().first, isEmpty);
      expect(await db.audioDao.watchAll().first, isEmpty);
    });

    test('deleteMedia removes row', () async {
      final now = DateTime.now();
      const id = 'gone';
      await db.audioDao.insertRow(
        AudioRow(
          id: id,
          aid: 'f',
          provider: 'user',
          title: 'x',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: 'file:///x.mp3',
          md5: null,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      await repo.deleteMedia(id);
      expect(await repo.getById(id), isNull);
    });

    test(
      'relocateLocalFile sets localUri when picked file hash matches',
      () async {
        final bytes = utf8.encode('relocate-body');
        final hash = sha256.convert(bytes).toString();
        final id = enjoyVideoId(vid: hash);
        final src = File(p.join(root.path, 'clip.mp4'));
        await src.writeAsBytes(bytes);

        final now = DateTime.now();
        await db.videoDao.insertRow(
          VideoRow(
            id: id,
            vid: hash,
            provider: 'user',
            title: 'Synced',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            source: null,
            localUri: null,
            md5: hash,
            size: bytes.length,
            mediaUrl: null,
            syncStatus: 'synced',
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await repo.relocateLocalFile(
          mediaId: id,
          picked: XFile(src.path, name: 'clip.mp4'),
        );

        final row = await db.videoDao.getById(id);
        expect(row, isNotNull);
        expect(row!.localUri, Uri.file(src.path).toString());
        expect(row.size, bytes.length);
        expect(row.localMtimeMs, isNotNull);
      },
    );

    test(
      'relocateLocalFile throws and keeps localUri when hash mismatches',
      () async {
        final goodBytes = utf8.encode('good');
        final hash = sha256.convert(goodBytes).toString();
        final id = enjoyAudioId(aid: hash);
        final wrong = File(p.join(root.path, 'wrong.mp3'));
        await wrong.writeAsBytes(utf8.encode('other-bytes'));

        final now = DateTime.now();
        await db.audioDao.insertRow(
          AudioRow(
            id: id,
            aid: hash,
            provider: 'user',
            title: 'Remote',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            translationKey: null,
            sourceText: null,
            voice: null,
            source: null,
            localUri: null,
            md5: hash,
            size: goodBytes.length,
            mediaUrl: null,
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        await expectLater(
          repo.relocateLocalFile(
            mediaId: id,
            picked: XFile(wrong.path, name: 'wrong.mp3'),
          ),
          throwsA(isA<FileFailure>()),
        );

        final row = await db.audioDao.getById(id);
        expect(row!.localUri, isNull);
      },
    );

    test('importYoutubeVideo uses prefetched title without oEmbed', () async {
      const vid = 'dQw4w9WgXcQ';
      final oembedClient = MockClient((_) async => http.Response('', 500));

      final ytRepo = MediaLibraryRepository(
        db,
        FileStorage(),
        oembedClient: oembedClient,
      );

      final id = await ytRepo.importYoutubeVideo(
        vid,
        prefetchedTitle: 'RSS Title',
        prefetchedThumbnailUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
      );

      final row = await db.videoDao.getById(id);
      expect(row!.title, 'RSS Title');
      expect(row.thumbnailUrl, 'https://i.ytimg.com/vi/$vid/hqdefault.jpg');
    });

    test(
      'importYoutubeVideo re-import bumps updatedAt for Home recents',
      () async {
        const vid = 'dQw4w9WgXcQ';
        final mediaId = enjoyVideoId(provider: 'youtube', vid: vid);
        final oldUpdated = DateTime.utc(2024, 1, 1);

        await db.videoDao.insertRow(
          VideoRow(
            id: mediaId,
            vid: vid,
            provider: 'youtube',
            title: 'Existing Title',
            description: null,
            thumbnailUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
            durationSeconds: 0,
            language: 'und',
            source: 'youtube',
            localUri: null,
            md5: null,
            size: null,
            mediaUrl: 'https://www.youtube.com/watch?v=$vid',
            syncStatus: 'pending',
            serverUpdatedAt: null,
            createdAt: oldUpdated,
            updatedAt: oldUpdated,
          ),
        );

        final ytRepo = MediaLibraryRepository(
          db,
          FileStorage(),
          oembedClient: MockClient((_) async => http.Response('', 500)),
        );

        final id = await ytRepo.importYoutubeVideo(vid);
        expect(id, mediaId);

        final row = await db.videoDao.getById(mediaId);
        expect(row!.updatedAt.isAfter(oldUpdated), isTrue);
      },
    );

    test('touchMediaUpdatedAt bumps video row for Home recents', () async {
      const vid = 'dQw4w9WgXcQ';
      final mediaId = enjoyVideoId(provider: 'youtube', vid: vid);
      final oldUpdated = DateTime.utc(2024, 1, 1);

      await db.videoDao.insertRow(
        VideoRow(
          id: mediaId,
          vid: vid,
          provider: 'youtube',
          title: 'Existing Title',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          source: 'youtube',
          localUri: null,
          md5: null,
          size: null,
          mediaUrl: 'https://www.youtube.com/watch?v=$vid',
          syncStatus: 'pending',
          serverUpdatedAt: null,
          createdAt: oldUpdated,
          updatedAt: oldUpdated,
        ),
      );

      final repo = MediaLibraryRepository(db, FileStorage());
      await repo.touchMediaUpdatedAt(mediaId);

      final row = await db.videoDao.getById(mediaId);
      expect(row!.updatedAt.isAfter(oldUpdated), isTrue);
    });

    test('refreshYoutubeMetadataIfNeeded patches placeholder title', () async {
      const vid = 'dQw4w9WgXcQ';
      final mediaId = enjoyVideoId(provider: 'youtube', vid: vid);
      final now = DateTime.now();

      await db.videoDao.insertRow(
        VideoRow(
          id: mediaId,
          vid: vid,
          provider: 'youtube',
          title: youtubeImportPlaceholderTitle(vid),
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          source: 'youtube',
          localUri: null,
          md5: null,
          size: null,
          mediaUrl: 'https://www.youtube.com/watch?v=$vid',
          syncStatus: 'pending',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final oembedClient = MockClient((request) async {
        expect(request.url.host, 'www.youtube.com');
        return http.Response(
          '{"title":"Real Title","thumbnail_url":"https://i.ytimg.com/vi/$vid/hqdefault.jpg"}',
          200,
          headers: {'content-type': 'application/json'},
        );
      });

      final ytRepo = MediaLibraryRepository(
        db,
        FileStorage(),
        oembedClient: oembedClient,
      );

      final patch = await ytRepo.refreshYoutubeMetadataIfNeeded(mediaId);
      expect(patch?.title, 'Real Title');
      expect(patch?.thumbnailUrl, 'https://i.ytimg.com/vi/$vid/hqdefault.jpg');

      final row = await db.videoDao.getById(mediaId);
      expect(row!.title, 'Real Title');
      expect(row.thumbnailUrl, 'https://i.ytimg.com/vi/$vid/hqdefault.jpg');
    });

    test('refreshYoutubeMetadataIfNeeded skips complete metadata', () async {
      const vid = 'dQw4w9WgXcQ';
      final mediaId = enjoyVideoId(provider: 'youtube', vid: vid);
      final now = DateTime.now();

      await db.videoDao.insertRow(
        VideoRow(
          id: mediaId,
          vid: vid,
          provider: 'youtube',
          title: 'Already Good',
          description: null,
          thumbnailUrl: 'https://i.ytimg.com/vi/$vid/hqdefault.jpg',
          durationSeconds: 120,
          language: 'und',
          source: 'youtube',
          localUri: null,
          md5: null,
          size: null,
          mediaUrl: 'https://www.youtube.com/watch?v=$vid',
          syncStatus: 'synced',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final oembedClient = MockClient((_) async {
        fail('oEmbed should not be called');
      });

      final ytRepo = MediaLibraryRepository(
        db,
        FileStorage(),
        oembedClient: oembedClient,
      );

      final patch = await ytRepo.refreshYoutubeMetadataIfNeeded(mediaId);
      expect(patch, isNull);
    });

    test('watchAll deduplicates identical emissions', () async {
      final now = DateTime.now();
      const id = 'dup-1';
      await db.audioDao.insertRow(
        AudioRow(
          id: id,
          aid: 'f',
          provider: 'user',
          title: 'x',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: 'file:///x.mp3',
          md5: null,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );

      final emissions = <List<Media>>[];
      final sub = repo.watchAll().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions, hasLength(1));
      expect(emissions.first, hasLength(1));

      // No-op write: same row, same fields. Drift re-queries both tables and
      // pushes the unchanged merged list back through watchAll. The repo
      // should suppress the duplicate so home/library providers don't re-sort.
      await db.audioDao.insertRow(
        AudioRow(
          id: id,
          aid: 'f',
          provider: 'user',
          title: 'x',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: 'file:///x.mp3',
          md5: null,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions, hasLength(1));

      // A real change must still emit.
      await db.audioDao.insertRow(
        AudioRow(
          id: id,
          aid: 'f',
          provider: 'user',
          title: 'renamed',
          description: null,
          thumbnailUrl: null,
          durationSeconds: 0,
          language: 'und',
          translationKey: null,
          sourceText: null,
          voice: null,
          source: null,
          localUri: 'file:///x.mp3',
          md5: null,
          size: 1,
          mediaUrl: null,
          syncStatus: null,
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions, hasLength(2));
      expect(emissions.last.single.title, 'renamed');

      await sub.cancel();
    });

    test('watchAll emits once for an empty library', () async {
      // Regression test: `lastEmitted` used to start as `const <Media>[]`,
      // which compared equal to the first (empty) merged snapshot from both
      // DAOs and silently swallowed it — so `watchAll()` never emitted for a
      // brand-new/empty library and every provider built on it (home
      // recents, filtered lists) stayed stuck in `AsyncLoading` forever.
      final emissions = <List<Media>>[];
      final sub = repo.watchAll().listen(emissions.add);
      await Future<void>.delayed(const Duration(milliseconds: 50));

      expect(emissions, hasLength(1));
      expect(emissions.single, isEmpty);

      await sub.cancel();
    });

    test('importMedia persists selected content language', () async {
      final bytes = utf8.encode('lang-import');
      final src = File(p.join(root.path, 'clip.mp3'));
      await src.writeAsBytes(bytes);

      final id = await repo.importMedia(
        XFile(src.path),
        signedInUserId: _testUserId,
        contentLanguage: 'ja',
      );
      final media = await repo.getById(id);
      expect(media!.language, 'ja-JP');
    });

    test('importYoutubeVideo persists content language', () async {
      const vid = 'dQw4w9WgXcQ';
      final ytRepo = MediaLibraryRepository(
        db,
        FileStorage(),
        oembedClient: MockClient((_) async => http.Response('', 500)),
      );

      final id = await ytRepo.importYoutubeVideo(
        vid,
        prefetchedTitle: 'Korean clip',
        contentLanguage: 'ko',
      );
      final row = await db.videoDao.getById(id);
      expect(row!.language, 'ko-KR');
    });

    test(
      'updateMediaLanguage updates row and clears transcript fetch state',
      () async {
        var syncCalls = 0;
        final syncingRepo = MediaLibraryRepository(
          db,
          FileStorage(),
          enqueueSync: (_, _, _) async {
            syncCalls++;
          },
        );

        final now = DateTime.now();
        const id = 'yt-lang';
        await db.videoDao.insertRow(
          VideoRow(
            id: id,
            vid: 'abcdefghijk',
            provider: 'youtube',
            title: 'Clip',
            description: null,
            thumbnailUrl: null,
            durationSeconds: 0,
            language: 'und',
            source: 'youtube',
            localUri: null,
            md5: null,
            size: null,
            mediaUrl: 'https://www.youtube.com/watch?v=abcdefghijk',
            syncStatus: null,
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
        await db.transcriptFetchStateDao.upsertOutcome(
          targetType: 'video',
          targetId: id,
          lastFetchedAt: now,
          lastStatus: 'error',
          lastError: 'wrong language',
        );

        await syncingRepo.updateMediaLanguage(id, 'fr');
        final row = await db.videoDao.getById(id);
        expect(row!.language, 'fr-FR');
        expect(syncCalls, 1);
        final fetchState = await db.transcriptFetchStateDao.getForTarget(
          'video',
          id,
        );
        expect(fetchState, isNull);
      },
    );
  });
}
