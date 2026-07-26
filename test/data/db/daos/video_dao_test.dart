import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

VideoRow _video({
  String id = 'v-1',
  String vid = 'vid-1',
  String provider = 'user',
  String title = 'Sample',
  String? description,
  String? thumbnailUrl,
  int durationSeconds = 60,
  String language = 'und',
  String? source,
  String? localUri,
  String? md5,
  int? size,
  int? localMtimeMs,
  String? mediaUrl,
  DateTime? createdAt,
  DateTime? updatedAt,
}) {
  final now = DateTime.utc(2026, 7, 1);
  return VideoRow(
    id: id,
    vid: vid,
    provider: provider,
    title: title,
    description: description,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    language: language,
    source: source,
    localUri: localUri,
    md5: md5,
    size: size,
    localMtimeMs: localMtimeMs,
    mediaUrl: mediaUrl,
    createdAt: createdAt ?? now,
    updatedAt: updatedAt ?? now,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('VideoDao', () {
    test('insertRow + getById round-trip', () async {
      await db.videoDao.insertRow(_video(title: 'Hello'));
      final found = await db.videoDao.getById('v-1');
      expect(found, isNotNull);
      expect(found!.title, 'Hello');
      expect(found.vid, 'vid-1');
      expect(found.provider, 'user');
    });

    test('getById returns null for unknown id', () async {
      expect(await db.videoDao.getById('missing'), isNull);
    });

    test('getYoutubeByVid filters by provider=youtube + vid', () async {
      await db.videoDao.insertRow(
        _video(id: 'yt-a', vid: 'YT-1', provider: 'youtube'),
      );
      await db.videoDao.insertRow(
        _video(id: 'local-a', vid: 'YT-1', provider: 'user'),
      );

      final yt = await db.videoDao.getYoutubeByVid('YT-1');
      expect(yt, isNotNull);
      expect(yt!.id, 'yt-a');

      expect(await db.videoDao.getYoutubeByVid('NOPE'), isNull);
    });

    test('listAll returns every row', () async {
      await db.videoDao.insertRow(_video(id: 'a'));
      await db.videoDao.insertRow(_video(id: 'b'));
      final all = await db.videoDao.listAll();
      expect(all.map((r) => r.id).toSet(), {'a', 'b'});
    });

    test('watchAll orders by createdAt descending', () async {
      final base = DateTime.utc(2026, 7, 1);
      await db.videoDao.insertRow(
        _video(id: 'old', createdAt: base, updatedAt: base),
      );
      await db.videoDao.insertRow(
        _video(
          id: 'new',
          createdAt: base.add(const Duration(days: 1)),
          updatedAt: base.add(const Duration(days: 1)),
        ),
      );
      final list = await db.videoDao.watchAll().first;
      expect(list.first.id, 'new');
      expect(list.last.id, 'old');
    });

    test('insertRow with insertOrReplace overwrites by primary key', () async {
      await db.videoDao.insertRow(_video(title: 'first'));
      await db.videoDao.insertRow(_video(title: 'second'));
      final found = await db.videoDao.getById('v-1');
      expect(found!.title, 'second');
    });

    test('updateLocalThumbnail sets thumbnailUrl', () async {
      await db.videoDao.insertRow(_video());
      await db.videoDao.updateLocalThumbnail('v-1', '/tmp/a.jpg');
      final found = await db.videoDao.getById('v-1');
      expect(found!.thumbnailUrl, '/tmp/a.jpg');
    });

    test('updateYoutubeMetadata sets title and thumbnail', () async {
      await db.videoDao.insertRow(_video(title: 'old'));
      await db.videoDao.updateYoutubeMetadata(
        id: 'v-1',
        title: 'new',
        thumbnailUrl: 'http://t',
      );
      final found = await db.videoDao.getById('v-1');
      expect(found!.title, 'new');
      expect(found.thumbnailUrl, 'http://t');
    });

    test(
      'updateYoutubeMetadata accepts null thumbnail (Value.absent)',
      () async {
        await db.videoDao.insertRow(_video(thumbnailUrl: 'http://old'));
        await db.videoDao.updateYoutubeMetadata(
          id: 'v-1',
          title: 'new',
          thumbnailUrl: null,
        );
        final found = await db.videoDao.getById('v-1');
        // null thumbnail → Value.absent → existing thumbnail preserved
        expect(found!.title, 'new');
        expect(found.thumbnailUrl, 'http://old');
      },
    );

    test('updateLanguage changes language column', () async {
      await db.videoDao.insertRow(_video(language: 'en'));
      await db.videoDao.updateLanguage(id: 'v-1', language: 'zh');
      final found = await db.videoDao.getById('v-1');
      expect(found!.language, 'zh');
    });

    test('touchUpdatedAt bumps updatedAt', () async {
      final base = DateTime.utc(2026, 1, 1);
      await db.videoDao.insertRow(_video(createdAt: base, updatedAt: base));
      await db.videoDao.touchUpdatedAt('v-1');
      final found = await db.videoDao.getById('v-1');
      expect(found!.updatedAt.toUtc().isAfter(base), isTrue);
      expect(found.createdAt.toUtc(), base);
    });

    test('deleteId removes the row', () async {
      await db.videoDao.insertRow(_video());
      await db.videoDao.deleteId('v-1');
      expect(await db.videoDao.getById('v-1'), isNull);
    });

    test('countByLocalUri returns matching rows count', () async {
      await db.videoDao.insertRow(_video(id: 'a', localUri: '/tmp/a.mp4'));
      await db.videoDao.insertRow(_video(id: 'b', localUri: '/tmp/a.mp4'));
      await db.videoDao.insertRow(_video(id: 'c', localUri: '/tmp/b.mp4'));
      final n = await db.videoDao.countByLocalUri('/tmp/a.mp4');
      expect(n, 2);
      expect(await db.videoDao.countByLocalUri('/tmp/missing'), 0);
    });
  });
}
