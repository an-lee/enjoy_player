import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/youtube_subscription_source.dart';
import 'package:flutter_test/flutter_test.dart';

YoutubeChannelSubscriptionRow _channel({
  String channelId = 'channel-1',
  String displayName = 'Channel One',
  String? thumbnailUrl,
  YoutubeSubscriptionSource source = YoutubeSubscriptionSource.user,
  YoutubeSourceType sourceType = YoutubeSourceType.channel,
  String? feedUrl,
  DateTime? subscribedAt,
  DateTime? lastFetchedAt,
  String language = 'en',
}) {
  return YoutubeChannelSubscriptionRow(
    channelId: channelId,
    displayName: displayName,
    thumbnailUrl: thumbnailUrl,
    source: source,
    sourceType: sourceType,
    feedUrl: feedUrl,
    subscribedAt: subscribedAt ?? DateTime.utc(2026, 1, 1),
    lastFetchedAt: lastFetchedAt,
    language: language,
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

  group('YoutubeChannelSubscriptionDao', () {
    test('upsert then getByChannelId round-trips', () async {
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(displayName: 'Hello'),
      );
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found, isNotNull);
      expect(found!.displayName, 'Hello');
    });

    test('getByChannelId returns null for unknown id', () async {
      expect(
        await db.youtubeChannelSubscriptionDao.getByChannelId('missing'),
        isNull,
      );
    });

    test('listAll returns every row', () async {
      await db.youtubeChannelSubscriptionDao.upsert(_channel(channelId: 'a'));
      await db.youtubeChannelSubscriptionDao.upsert(_channel(channelId: 'b'));
      final all = await db.youtubeChannelSubscriptionDao.listAll();
      expect(all.map((r) => r.channelId), unorderedEquals(['a', 'b']));
    });

    test('watchAll orders by displayName ascending', () async {
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(channelId: 'a', displayName: 'Charlie'),
      );
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(channelId: 'b', displayName: 'Alpha'),
      );
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(channelId: 'c', displayName: 'Bravo'),
      );
      final list = await db.youtubeChannelSubscriptionDao.watchAll().first;
      expect(list.map((r) => r.displayName), ['Alpha', 'Bravo', 'Charlie']);
    });

    test('upsert replaces existing row by primary key', () async {
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(displayName: 'first'),
      );
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(displayName: 'second'),
      );
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.displayName, 'second');
    });

    test('deleteChannelId removes the row', () async {
      await db.youtubeChannelSubscriptionDao.upsert(_channel());
      await db.youtubeChannelSubscriptionDao.deleteChannelId('channel-1');
      expect(
        await db.youtubeChannelSubscriptionDao.getByChannelId('channel-1'),
        isNull,
      );
    });

    test('touchLastFetched sets lastFetchedAt', () async {
      await db.youtubeChannelSubscriptionDao.upsert(_channel());
      final ts = DateTime.utc(2026, 7, 1);
      await db.youtubeChannelSubscriptionDao.touchLastFetched('channel-1', ts);
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.lastFetchedAt!.toUtc(), ts);
    });

    test('updateDisplayName changes displayName', () async {
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(displayName: 'old'),
      );
      await db.youtubeChannelSubscriptionDao.updateDisplayName(
        'channel-1',
        'new',
      );
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.displayName, 'new');
    });

    test('updateThumbnail accepts null to clear', () async {
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(thumbnailUrl: 'http://x'),
      );
      await db.youtubeChannelSubscriptionDao.updateThumbnail('channel-1', null);
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.thumbnailUrl, isNull);
    });

    test('updateThumbnail sets a new url', () async {
      await db.youtubeChannelSubscriptionDao.upsert(_channel());
      await db.youtubeChannelSubscriptionDao.updateThumbnail(
        'channel-1',
        'http://new',
      );
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.thumbnailUrl, 'http://new');
    });

    test('updateLanguage changes language', () async {
      await db.youtubeChannelSubscriptionDao.upsert(_channel(language: 'en'));
      await db.youtubeChannelSubscriptionDao.updateLanguage('channel-1', 'zh');
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.language, 'zh');
    });

    test('updateSourceType changes sourceType', () async {
      await db.youtubeChannelSubscriptionDao.upsert(_channel());
      await db.youtubeChannelSubscriptionDao.updateSourceType(
        'channel-1',
        YoutubeSourceType.playlist,
      );
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.sourceType, YoutubeSourceType.playlist);
    });

    test('updateFeedUrl accepts null', () async {
      await db.youtubeChannelSubscriptionDao.upsert(
        _channel(feedUrl: 'http://feed'),
      );
      await db.youtubeChannelSubscriptionDao.updateFeedUrl('channel-1', null);
      final found = await db.youtubeChannelSubscriptionDao.getByChannelId(
        'channel-1',
      );
      expect(found!.feedUrl, isNull);
    });
  });
}
