import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/media_target_resolver.dart';
import 'package:enjoy_player/data/files/security_scoped_bookmark.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

VideoRow _video({
  String id = 'v-1',
  String vid = 'vid-1',
  String provider = 'user',
  String title = 'Sample',
  int durationSeconds = 60,
  String language = 'und',
  String? source,
  String? localUri,
  int? size,
  int? localMtimeMs,
  String? mediaUrl,
  Uint8List? bookmarkData,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return VideoRow(
    id: id,
    vid: vid,
    provider: provider,
    title: title,
    durationSeconds: durationSeconds,
    language: language,
    source: source,
    localUri: localUri,
    bookmarkData: bookmarkData,
    size: size,
    localMtimeMs: localMtimeMs,
    mediaUrl: mediaUrl,
    createdAt: now,
    updatedAt: now,
  );
}

AudioRow _audio({
  String id = 'a-1',
  String aid = 'aid-1',
  String provider = 'user',
  String title = 'Audio',
  int durationSeconds = 30,
  String language = 'und',
  String? localUri,
  int? size,
  int? localMtimeMs,
  String? mediaUrl,
  Uint8List? bookmarkData,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return AudioRow(
    id: id,
    aid: aid,
    provider: provider,
    title: title,
    durationSeconds: durationSeconds,
    language: language,
    localUri: localUri,
    bookmarkData: bookmarkData,
    size: size,
    localMtimeMs: localMtimeMs,
    mediaUrl: mediaUrl,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late Directory tempDir;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    tempDir = await Directory.systemTemp.createTemp('media_target_resolver_');
  });

  tearDown(() async {
    await db.close();
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<File> touchFile(String name, int size) async {
    final f = File('${tempDir.path}/$name');
    final raf = await f.open(mode: FileMode.write);
    await raf.truncate(size);
    await raf.close();
    return f;
  }

  group('dexieTargetTypeForId', () {
    test('returns "Video" when the id is a video row', () async {
      await db.videoDao.insertRow(_video(id: 'v-1'));
      expect(await dexieTargetTypeForId(db, 'v-1'), 'Video');
    });

    test('returns "Audio" when the id is an audio row', () async {
      await db.audioDao.insertRow(_audio(id: 'a-1'));
      expect(await dexieTargetTypeForId(db, 'a-1'), 'Audio');
    });

    test('returns null when the id matches neither', () async {
      expect(await dexieTargetTypeForId(db, 'missing'), isNull);
    });

    test(
      'video takes precedence over audio when both exist (should not happen)',
      () async {
        // Defensive: production code never inserts the same id into both tables,
        // but verify the documented ordering — Video wins.
        await db.videoDao.insertRow(_video(id: 'shared'));
        await db.audioDao.insertRow(_audio(id: 'shared'));
        expect(await dexieTargetTypeForId(db, 'shared'), 'Video');
      },
    );
  });

  group('resolvePlayableSource', () {
    test('returns null when neither video nor audio exists', () async {
      expect(await resolvePlayableSource(db, 'missing'), isNull);
    });

    test('returns YoutubePlayableSource for youtube provider', () async {
      await db.videoDao.insertRow(
        _video(id: 'yt', provider: 'youtube', vid: 'dQw4w9WgXcQ'),
      );
      final src = await resolvePlayableSource(db, 'yt');
      expect(src, isA<YoutubePlayableSource>());
      expect((src as YoutubePlayableSource).videoId, 'dQw4w9WgXcQ');
    });

    test('returns LocalFilePlayableSource for trusted local video', () async {
      final f = await touchFile('movie.mp4', 100);
      await db.videoDao.insertRow(
        _video(id: 'local', localUri: f.path, size: 100),
      );
      final src = await resolvePlayableSource(db, 'local');
      expect(src, isA<LocalFilePlayableSource>());
      expect((src as LocalFilePlayableSource).uri, f.path);
    });

    test('returns RemoteUrlPlayableSource when only mediaUrl is set', () async {
      await db.videoDao.insertRow(
        _video(id: 'remote', mediaUrl: 'https://x.example/a.mp4'),
      );
      final src = await resolvePlayableSource(db, 'remote');
      expect(src, isA<RemoteUrlPlayableSource>());
      expect((src as RemoteUrlPlayableSource).uri, 'https://x.example/a.mp4');
    });

    test('prefers local file over remote url when local is trusted', () async {
      final f = await touchFile('local.mp4', 100);
      await db.videoDao.insertRow(
        _video(
          id: 'both',
          localUri: f.path,
          size: 100,
          mediaUrl: 'https://x.example/remote.mp4',
        ),
      );
      final src = await resolvePlayableSource(db, 'both');
      expect(src, isA<LocalFilePlayableSource>());
    });

    test(
      'returns RemoteUrlPlayableSource when local fails trust check',
      () async {
        // localUri is set but no size/mtime → untrusted → falls back to remote.
        await db.videoDao.insertRow(
          _video(
            id: 'untrusted-local',
            localUri: '/tmp/nonexistent.mp4',
            size: null,
            localMtimeMs: null,
            mediaUrl: 'https://x.example/remote.mp4',
          ),
        );
        final src = await resolvePlayableSource(db, 'untrusted-local');
        expect(src, isA<RemoteUrlPlayableSource>());
      },
    );

    test('returns null when neither localUri nor mediaUrl is set', () async {
      await db.videoDao.insertRow(_video(id: 'bare'));
      expect(await resolvePlayableSource(db, 'bare'), isNull);
    });

    test('falls back to audio row when no video row exists', () async {
      await db.audioDao.insertRow(
        _audio(id: 'audio', mediaUrl: 'https://x.example/a.mp3'),
      );
      final src = await resolvePlayableSource(db, 'audio');
      expect(src, isA<RemoteUrlPlayableSource>());
    });

    test('audio local file path wins over audio remote url', () async {
      final f = await touchFile('song.mp3', 50);
      await db.audioDao.insertRow(
        _audio(
          id: 'audio-local',
          localUri: f.path,
          size: 50,
          mediaUrl: 'https://x.example/song.mp3',
        ),
      );
      final src = await resolvePlayableSource(db, 'audio-local');
      expect(src, isA<LocalFilePlayableSource>());
      expect((src as LocalFilePlayableSource).uri, f.path);
    });

    test('resolves bookmark when present and uses the resolved path '
        'with a scope token (ADR-0060)', () async {
      final realFile = await touchFile('real.mp4', 100);
      // Stale localUri (the file moved). With a bookmark present the
      // resolver must use the resolved path instead.
      await db.videoDao.insertRow(
        _video(
          id: 'bookmarked',
          localUri: '/Users/an-lee/Downloads/old.mp4',
          bookmarkData: Uint8List.fromList([1, 2, 3]),
          size: 100,
        ),
      );
      final mockChannel = const MethodChannel(
        'enjoy.player/security_scoped_bookmark.test_resolve_ok',
      );
      SecurityScopedBookmarkChannel.overrideChannel = mockChannel;
      addTearDown(() {
        SecurityScopedBookmarkChannel.overrideChannel = null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (call) async {
            if (call.method == 'resolveBookmark') {
              return <String, Object?>{
                'path': realFile.path,
                'token': 17,
                'stale': false,
              };
            }
            if (call.method == 'releaseBookmark') return null;
            throw MissingPluginException();
          });

      final src = await resolvePlayableSource(db, 'bookmarked');
      expect(src, isA<LocalFilePlayableSource>());
      final local = src as LocalFilePlayableSource;
      expect(local.uri, realFile.path);
      expect(local.scopeToken, 17);
    });

    test(
      'falls back to localUri when bookmark resolves but the resolved '
      'path fails trust check (size/mtime mismatch — silent rebind)',
      () async {
        final untouchedFile = await touchFile('present.mp4', 100);
        await db.videoDao.insertRow(
          _video(
            id: 'rebound-untrusted',
            localUri: untouchedFile.path,
            bookmarkData: Uint8List.fromList([9, 9, 9]),
            size: 100,
          ),
        );
        final mockChannel = const MethodChannel(
          'enjoy.player/security_scoped_bookmark.test_rebound_untrusted',
        );
        SecurityScopedBookmarkChannel.overrideChannel = mockChannel;
        addTearDown(() {
          SecurityScopedBookmarkChannel.overrideChannel = null;
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(mockChannel, (call) async {
              if (call.method == 'resolveBookmark') {
                return <String, Object?>{
                  'path': untouchedFile.path,
                  'token': 42,
                  'stale': true,
                };
              }
              if (call.method == 'releaseBookmark') return null;
              throw MissingPluginException();
            });

        final src = await resolvePlayableSource(db, 'rebound-untrusted');
        // Falls through to localUri path, which IS trusted (size matches).
        expect(src, isA<LocalFilePlayableSource>());
        expect((src as LocalFilePlayableSource).uri, untouchedFile.path);
      },
    );

    test(
      'falls back to remote mediaUrl when both bookmark and localUri fail',
      () async {
        await db.videoDao.insertRow(
          _video(
            id: 'both-fail',
            localUri: '/tmp/missing.mp4',
            bookmarkData: Uint8List.fromList([1]),
            size: 100,
            mediaUrl: 'https://x.example/a.mp4',
          ),
        );
        final mockChannel = const MethodChannel(
          'enjoy.player/security_scoped_bookmark.test_both_fail',
        );
        SecurityScopedBookmarkChannel.overrideChannel = mockChannel;
        addTearDown(() {
          SecurityScopedBookmarkChannel.overrideChannel = null;
        });
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(mockChannel, (call) async {
              if (call.method == 'resolveBookmark') {
                // Native side fails to resolve (file gone).
                throw PlatformException(code: 'RESOLVE_FAILED');
              }
              if (call.method == 'releaseBookmark') return null;
              throw MissingPluginException();
            });

        final src = await resolvePlayableSource(db, 'both-fail');
        expect(src, isA<RemoteUrlPlayableSource>());
      },
    );
  });

  group('resolvePlayableSourceUri', () {
    test('returns null when nothing matches', () async {
      expect(await resolvePlayableSourceUri(db, 'missing'), isNull);
    });

    test(
      'returns null for a YouTube row (subtitle path skips youtube)',
      () async {
        await db.videoDao.insertRow(
          _video(id: 'yt', provider: 'youtube', vid: 'dQw4w9WgXcQ'),
        );
        expect(await resolvePlayableSourceUri(db, 'yt'), isNull);
      },
    );

    test('returns trusted local uri for a local video row', () async {
      final f = await touchFile('a.mp4', 100);
      await db.videoDao.insertRow(
        _video(id: 'local', localUri: f.path, size: 100),
      );
      expect(await resolvePlayableSourceUri(db, 'local'), f.path);
    });

    test('returns mediaUrl when local fails trust check', () async {
      await db.videoDao.insertRow(
        _video(
          id: 'r',
          localUri: '/tmp/old.mp4',
          mediaUrl: 'https://x.example/a.mp4',
        ),
      );
      expect(
        await resolvePlayableSourceUri(db, 'r'),
        'https://x.example/a.mp4',
      );
    });

    test('returns null when neither local nor mediaUrl is set', () async {
      await db.videoDao.insertRow(_video(id: 'bare'));
      expect(await resolvePlayableSourceUri(db, 'bare'), isNull);
    });

    test('falls back to audio when no video matches', () async {
      await db.audioDao.insertRow(
        _audio(id: 'a', mediaUrl: 'https://x.example/a.mp3'),
      );
      expect(
        await resolvePlayableSourceUri(db, 'a'),
        'https://x.example/a.mp3',
      );
    });

    test('prefers bookmark-resolved path over stale localUri when bookmark '
        'is present', () async {
      final realFile = await touchFile('reb.mp4', 100);
      await db.videoDao.insertRow(
        _video(
          id: 'u',
          localUri: '/Users/an-lee/Downloads/old.mp4',
          bookmarkData: Uint8List.fromList([1]),
          size: 100,
        ),
      );
      final mockChannel = const MethodChannel(
        'enjoy.player/security_scoped_bookmark.test_uri_resolve_ok',
      );
      SecurityScopedBookmarkChannel.overrideChannel = mockChannel;
      addTearDown(() {
        SecurityScopedBookmarkChannel.overrideChannel = null;
      });
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(mockChannel, (call) async {
            if (call.method == 'resolveBookmark') {
              return <String, Object?>{
                'path': realFile.path,
                'token': 5,
                'stale': false,
              };
            }
            if (call.method == 'releaseBookmark') return null;
            throw MissingPluginException();
          });

      expect(await resolvePlayableSourceUri(db, 'u'), realFile.path);
    });
  });
}
