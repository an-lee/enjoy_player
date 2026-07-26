import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

YoutubeFeedEntryRow _feedEntry({
  required String videoId,
  String channelId = 'channel-1',
  String title = 'Title',
  String? thumbnailUrl,
  int? durationSeconds,
  DateTime? publishedAt,
  DateTime? fetchedAt,
}) {
  return YoutubeFeedEntryRow(
    videoId: videoId,
    channelId: channelId,
    title: title,
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    publishedAt: publishedAt ?? DateTime.utc(2026, 1, 1),
    fetchedAt: fetchedAt ?? DateTime.utc(2026, 1, 1),
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

  group('YoutubeFeedEntryDao', () {
    test('upsertEntry then getEntry round-trips', () async {
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v1', title: 'Hello'),
      );
      final found = await db.youtubeFeedEntryDao.getEntry(
        channelId: 'channel-1',
        videoId: 'v1',
      );
      expect(found, isNotNull);
      expect(found!.title, 'Hello');
    });

    test('getEntry returns null for missing pair', () async {
      expect(
        await db.youtubeFeedEntryDao.getEntry(
          channelId: 'channel-1',
          videoId: 'missing',
        ),
        isNull,
      );
    });

    test('upsertEntry with same primary key replaces existing', () async {
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v1', title: 'first'),
      );
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v1', title: 'second'),
      );
      final found = await db.youtubeFeedEntryDao.getEntry(
        channelId: 'channel-1',
        videoId: 'v1',
      );
      expect(found!.title, 'second');
    });

    test('upsertEntries batches many rows in a single transaction', () async {
      await db.youtubeFeedEntryDao.upsertEntries([
        _feedEntry(videoId: 'v1', channelId: 'a'),
        _feedEntry(videoId: 'v2', channelId: 'a'),
        _feedEntry(videoId: 'v3', channelId: 'b'),
      ]);
      expect((await db.youtubeFeedEntryDao.getForChannel('a')).length, 2);
      expect((await db.youtubeFeedEntryDao.getForChannel('b')).length, 1);
    });

    test('upsertEntries on empty input is a no-op', () async {
      await db.youtubeFeedEntryDao.upsertEntries(const []);
      expect(await db.youtubeFeedEntryDao.getForChannel('any'), isEmpty);
    });

    test('getForChannel orders by publishedAt descending', () async {
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'old', publishedAt: DateTime.utc(2026, 1, 1)),
      );
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'new', publishedAt: DateTime.utc(2026, 6, 1)),
      );
      final list = await db.youtubeFeedEntryDao.getForChannel('channel-1');
      expect(list.map((r) => r.videoId), ['new', 'old']);
    });

    test('getForChannel returns only matching channelId', () async {
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v1', channelId: 'a'),
      );
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v2', channelId: 'b'),
      );
      final list = await db.youtubeFeedEntryDao.getForChannel('a');
      expect(list.single.videoId, 'v1');
    });

    test(
      'watchTimeline emits rows ordered by publishedAt descending',
      () async {
        await db.youtubeFeedEntryDao.upsertEntry(
          _feedEntry(
            videoId: 'old',
            channelId: 'a',
            publishedAt: DateTime.utc(2026, 1, 1),
          ),
        );
        await db.youtubeFeedEntryDao.upsertEntry(
          _feedEntry(
            videoId: 'new',
            channelId: 'a',
            publishedAt: DateTime.utc(2026, 6, 1),
          ),
        );
        final list = await db.youtubeFeedEntryDao.watchTimeline().first;
        expect(list.map((r) => r.videoId), ['new', 'old']);
      },
    );

    test('watchForChannel emits only the requested channel', () async {
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v1', channelId: 'a'),
      );
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v2', channelId: 'b'),
      );
      final list = await db.youtubeFeedEntryDao.watchForChannel('a').first;
      expect(list.single.videoId, 'v1');
    });

    test('updateDurationSeconds sets duration on existing row', () async {
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v1', durationSeconds: 60),
      );
      await db.youtubeFeedEntryDao.updateDurationSeconds(
        channelId: 'channel-1',
        videoId: 'v1',
        durationSeconds: 600,
      );
      final found = await db.youtubeFeedEntryDao.getEntry(
        channelId: 'channel-1',
        videoId: 'v1',
      );
      expect(found!.durationSeconds, 600);
    });

    test('updateDurationSeconds on missing row is a no-op', () async {
      await db.youtubeFeedEntryDao.updateDurationSeconds(
        channelId: 'channel-1',
        videoId: 'missing',
        durationSeconds: 600,
      );
      expect(
        await db.youtubeFeedEntryDao.getEntry(
          channelId: 'channel-1',
          videoId: 'missing',
        ),
        isNull,
      );
    });

    test('deleteForChannel removes only that channel', () async {
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v1', channelId: 'a'),
      );
      await db.youtubeFeedEntryDao.upsertEntry(
        _feedEntry(videoId: 'v2', channelId: 'b'),
      );
      await db.youtubeFeedEntryDao.deleteForChannel('a');
      expect(await db.youtubeFeedEntryDao.getForChannel('a'), isEmpty);
      expect(
        (await db.youtubeFeedEntryDao.getForChannel('b')).single.videoId,
        'v2',
      );
    });
  });
}
