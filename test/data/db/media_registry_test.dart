import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/media_registry.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
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
  String? mediaUrl,
}) {
  final now = DateTime(2026, 7, 1);
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
  String? mediaUrl,
}) {
  final now = DateTime(2026, 7, 1);
  return AudioRow(
    id: id,
    aid: aid,
    provider: provider,
    title: title,
    durationSeconds: durationSeconds,
    language: language,
    localUri: localUri,
    size: size,
    mediaUrl: mediaUrl,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AppDatabase db;
  late MediaRegistry registry;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    registry = MediaRegistry(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('getById', () {
    test('maps a video row to domain Media', () async {
      await db.videoDao.insertRow(
        _video(
          localUri: '/tmp/movie.mp4',
          mediaUrl: 'https://x.example/movie.mp4',
          size: 123,
        ),
      );
      final media = await registry.getById('v-1');
      expect(
        media,
        Media(
          id: 'v-1',
          kind: MediaKind.video,
          title: 'Sample',
          sourceUri: '/tmp/movie.mp4',
          thumbnailPath: null,
          durationMs: 60000,
          language: 'und',
          contentHash: 'vid-1',
          fileSize: 123,
          mediaUrl: 'https://x.example/movie.mp4',
          source: null,
          provider: 'user',
          syncStatus: null,
          createdAt: DateTime(2026, 7, 1),
          updatedAt: DateTime(2026, 7, 1),
        ),
      );
    });

    test('maps an audio row to domain Media', () async {
      await db.audioDao.insertRow(_audio(mediaUrl: 'https://x.example/a.mp3'));
      final media = await registry.getById('a-1');
      expect(media, isNotNull);
      expect(media!.kind, MediaKind.audio);
      expect(media.contentHash, 'aid-1');
      // No localUri: sourceUri falls back to mediaUrl.
      expect(media.sourceUri, 'https://x.example/a.mp3');
      expect(media.durationMs, 30000);
      expect(media.fileSize, 0);
    });

    test('returns null when neither table holds the id', () async {
      expect(await registry.getById('missing'), isNull);
    });

    test('video wins when the same id exists in both tables', () async {
      await db.videoDao.insertRow(_video(id: 'shared'));
      await db.audioDao.insertRow(_audio(id: 'shared'));
      final media = await registry.getById('shared');
      expect(media!.kind, MediaKind.video);
    });
  });

  group('kindOf', () {
    test('resolves video and audio kinds', () async {
      await db.videoDao.insertRow(_video());
      await db.audioDao.insertRow(_audio());
      expect(await registry.kindOf('v-1'), MediaKind.video);
      expect(await registry.kindOf('a-1'), MediaKind.audio);
      expect(await registry.kindOf('missing'), isNull);
    });
  });

  group('dexieTargetTypeForId', () {
    test('returns weapp target types', () async {
      await db.videoDao.insertRow(_video());
      await db.audioDao.insertRow(_audio());
      expect(await registry.dexieTargetTypeForId('v-1'), 'Video');
      expect(await registry.dexieTargetTypeForId('a-1'), 'Audio');
      expect(await registry.dexieTargetTypeForId('missing'), isNull);
    });
  });

  group('localUriOf', () {
    test('returns the localUri of whichever table holds the id', () async {
      await db.videoDao.insertRow(_video(localUri: '/tmp/v.mp4'));
      await db.audioDao.insertRow(_audio(localUri: '/tmp/a.mp3'));
      expect(await registry.localUriOf('v-1'), '/tmp/v.mp4');
      expect(await registry.localUriOf('a-1'), '/tmp/a.mp3');
    });

    test('returns null for a missing row or a row without localUri', () async {
      await db.videoDao.insertRow(_video(id: 'remote-only'));
      expect(await registry.localUriOf('remote-only'), isNull);
      expect(await registry.localUriOf('missing'), isNull);
    });
  });
}
