import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/media_target_resolver.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
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
    size: size,
    localMtimeMs: localMtimeMs,
    mediaUrl: mediaUrl,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
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
  });
}
