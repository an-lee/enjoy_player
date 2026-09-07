/// Discover feeds: subscriptions, RSS refresh, add-to-library bridge.
library;

import 'dart:async';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/cache/lru_store.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:flutter/foundation.dart';
import 'package:enjoy_player/core/utils/stream_distinct.dart';
import 'package:enjoy_player/data/api/services/ai/youtube_feed_api.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/youtube_subscription_source.dart';
import 'package:enjoy_player/features/library/data/library_repository.dart';
import 'package:http/http.dart' as http;

import '../domain/discover_channel.dart';
import '../domain/feed_entry.dart';
import '../domain/recommended_channel.dart';
import '../domain/youtube_source.dart';
import 'recommended_channels_loader.dart';
import 'worker_feed_exception.dart';
import 'youtube_url_parser.dart';

final _log = logNamed('discover.repository');

/// Maximum number of channels refreshed in parallel.
const int _kRefreshChannelConcurrency = 4;

/// Maximum number of distinct channel avatars to keep in memory.
/// LinkedHashMap-based LRU; oldest unread entry is evicted on insert.
const int _kAvatarCacheCapacity = 256;

class DiscoverRefreshResult {
  const DiscoverRefreshResult({
    required this.refreshedChannels,
    required this.failedChannelIds,
  });

  final int refreshedChannels;
  final List<String> failedChannelIds;

  bool get hasFailures => failedChannelIds.isNotEmpty;
}

class YoutubeFeedFetchException implements Exception {
  YoutubeFeedFetchException(this.message, {this.statusCode});

  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

class DiscoverRepository {
  DiscoverRepository(
    this._db, {
    http.Client? httpClient,
    RecommendedChannelsLoader? recommendedLoader,
    YoutubeFeedClient? feedClient,
    YoutubeUrlParser? urlParser,
    this._libraryRepository,
  }) : _recommendedLoader = recommendedLoader ?? RecommendedChannelsLoader(),
       _feedClient = feedClient ?? YoutubeFeedClient(httpClient: httpClient),
       _urlParser = urlParser ?? YoutubeUrlParser();

  final AppDatabase _db;
  final RecommendedChannelsLoader _recommendedLoader;
  final YoutubeFeedClient _feedClient;
  final YoutubeUrlParser _urlParser;
  MediaLibraryRepository? _libraryRepository;

  /// Bounded LRU cache for channel avatar URLs. TTL is generous: avatar
  /// URLs change only when the channel owner swaps their photo, which is
  /// effectively never at app-runtime. Prevents unbounded growth on a
  /// user who subscribes / unsubscribes many channels.
  // ignore: prefer_const_constructors — L1Store is not const-constructible
  // because its LinkedHashMap backing is a non-const default value.
  final L1Store<String, String> _avatarUrlCache = L1Store<String, String>(
    capacity: _kAvatarCacheCapacity,
    ttl: _avatarCacheTtl,
  );

  static const Duration _avatarCacheTtl = Duration(hours: 6);

  static const minRefreshInterval = Duration(hours: 1);
  static const rssFeedBase =
      'https://www.youtube.com/feeds/videos.xml?channel_id=';

  void bindLibraryRepository(MediaLibraryRepository repo) {
    _libraryRepository = repo;
  }

  Future<List<RecommendedChannel>> loadRecommendedChannels() =>
      _recommendedLoader.load();

  Stream<List<DiscoverChannel>> watchSubscriptions() {
    return _db.youtubeChannelSubscriptionDao
        .watchAll()
        .map((rows) => rows.map(_mapSubscription).toList(growable: false))
        .distinctBy(listEquals);
  }

  Stream<List<FeedEntry>> watchTimeline() {
    return _db.youtubeFeedEntryDao
        .watchTimeline()
        .map((rows) => rows.map(_mapFeedEntry).toList(growable: false))
        .distinctBy(listEquals);
  }

  Stream<List<FeedEntry>> watchChannelFeed(String channelId) {
    return _db.youtubeFeedEntryDao
        .watchForChannel(channelId)
        .map((rows) => rows.map(_mapFeedEntry).toList(growable: false))
        .distinctBy(listEquals);
  }

  Future<DiscoverChannel?> getSubscription(String channelId) async {
    final row = await _db.youtubeChannelSubscriptionDao.getByChannelId(
      channelId,
    );
    return row == null ? null : _mapSubscription(row);
  }

  Future<void> subscribeRecommended(RecommendedChannel channel) async {
    await subscribeChannel(
      channelId: channel.channelId,
      displayName: channel.name,
      source: YoutubeSubscriptionSource.recommended,
      sourceType: YoutubeSourceType.channel,
      feedUrl:
          '${_urlParser.workerBaseUrl}/youtube/channel/${channel.channelId}?format=json',
    );
  }

  Future<void> subscribeFromUserInput(String rawInput) async {
    // 1. Parse URL to get source type and feed URL
    ParsedYoutubeUrl parsed;
    try {
      parsed = _urlParser.parse(rawInput);
    } on FormatException {
      rethrow;
    }

    // 2. Fetch the feed to get display name, avatar, and entries
    final fetchResult = await _feedClient.fetchFeed(parsed.feedUrl);
    final feedResult = fetchResult.feedResult;

    // 3. Handle-to-ID canonicalization: if subscribed via @handle,
    //    use the canonical channel ID from the feed response.
    final canonicalId = fetchResult.canonicalChannelId ?? parsed.canonicalId;
    var sourceType = parsed.sourceType;
    var feedUrl = parsed.feedUrl;
    if (fetchResult.canonicalChannelId != null) {
      // Switch from handle URL to channel feed URL
      sourceType = YoutubeSourceType.channel;
      feedUrl =
          '${_urlParser.workerBaseUrl}/youtube/channel/$canonicalId?format=json';
    }

    // 4. Create or update the subscription
    final now = DateTime.now();
    final existing = await _db.youtubeChannelSubscriptionDao.getByChannelId(
      canonicalId,
    );
    if (existing != null) {
      // Already subscribed — update metadata and re-fetch
      await _db.youtubeChannelSubscriptionDao.upsert(
        YoutubeChannelSubscriptionRow(
          channelId: canonicalId,
          displayName: feedResult.displayName,
          thumbnailUrl: feedResult.iconUrl ?? existing.thumbnailUrl,
          source: YoutubeSubscriptionSource.user,
          sourceType: sourceType,
          feedUrl: feedUrl,
          subscribedAt: existing.subscribedAt,
          lastFetchedAt: now,
          language: existing.language,
        ),
      );
    } else {
      await _db.youtubeChannelSubscriptionDao.upsert(
        YoutubeChannelSubscriptionRow(
          channelId: canonicalId,
          displayName: feedResult.displayName,
          thumbnailUrl: feedResult.iconUrl,
          source: YoutubeSubscriptionSource.user,
          sourceType: sourceType,
          feedUrl: feedUrl,
          subscribedAt: now,
          lastFetchedAt: now,
          language: 'und',
        ),
      );
    }

    // 5. Upsert feed entries in a single batched transaction. One SQLite
    // COMMIT replaces N per-entry INSERTs; `watchTimeline` re-emits once
    // instead of N times, and the underlying `feedResult.entries` is small
    // enough to allocate in one go.
    await _upsertFeedEntries(canonicalId, feedResult.entries, now);
  }

  /// Batch-upserts [entries] as feed rows for [channelId]. One SQLite
  /// COMMIT replaces N per-entry INSERTs; `watchTimeline` re-emits once
  /// instead of N times.
  Future<void> _upsertFeedEntries(
    String channelId,
    Iterable<FeedEntry> entries,
    DateTime fetchedAt,
  ) async {
    if (entries.isEmpty) return;
    await _db.youtubeFeedEntryDao.upsertEntries([
      for (final entry in entries)
        YoutubeFeedEntryRow(
          videoId: entry.videoId,
          channelId: channelId,
          title: entry.title,
          thumbnailUrl: entry.thumbnailUrl,
          durationSeconds: entry.durationSeconds,
          publishedAt: entry.publishedAt,
          fetchedAt: fetchedAt,
        ),
    ]);
  }

  Future<void> subscribeChannel({
    required String channelId,
    required String displayName,
    required YoutubeSubscriptionSource source,
    String? thumbnailUrl,
    YoutubeSourceType sourceType = YoutubeSourceType.channel,
    String? feedUrl,
  }) async {
    final existing = await _db.youtubeChannelSubscriptionDao.getByChannelId(
      channelId,
    );
    final now = DateTime.now();
    await _db.youtubeChannelSubscriptionDao.upsert(
      YoutubeChannelSubscriptionRow(
        channelId: channelId,
        displayName: displayName,
        thumbnailUrl: thumbnailUrl ?? existing?.thumbnailUrl,
        source: source,
        sourceType: sourceType,
        feedUrl: feedUrl ?? existing?.feedUrl,
        subscribedAt: existing?.subscribedAt ?? now,
        lastFetchedAt: existing?.lastFetchedAt,
        language: existing?.language ?? 'und',
      ),
    );
  }

  Future<void> unsubscribe(String channelId) async {
    await _db.youtubeChannelSubscriptionDao.deleteChannelId(channelId);
    await _db.youtubeFeedEntryDao.deleteForChannel(channelId);
  }

  Future<bool> isVideoInLibrary(String videoId) async {
    final row = await _db.videoDao.getYoutubeByVid(videoId);
    return row != null;
  }

  /// Channel profile photo from the cached feed data.
  /// With the worker RSSHub proxy, avatars come from the feed `icon` field
  /// and are already stored in the subscription row on subscribe.
  /// This method returns the cached value from the local database.
  Future<String?> fetchChannelAvatarUrl(String channelId) async {
    final cached = _avatarUrlCache.peek(channelId);
    if (cached != null) return cached;

    try {
      final row = await _db.youtubeChannelSubscriptionDao.getByChannelId(
        channelId,
      );
      final url = row?.thumbnailUrl;
      if (url != null && url.isNotEmpty) {
        _avatarUrlCache.put(channelId, url);
      }
      return url;
    } catch (e, st) {
      _log.fine('channel avatar fetch failed for $channelId', e, st);
      return null;
    }
  }

  Future<String> addFeedEntryToLibrary(
    FeedEntry entry, {
    String? contentLanguage,
  }) async {
    final library = _libraryRepository;
    if (library == null) {
      throw StateError('DiscoverRepository library bridge not bound');
    }
    return library.importYoutubeVideo(
      entry.videoId,
      prefetchedTitle: entry.title,
      prefetchedThumbnailUrl: entry.thumbnailUrl,
      contentLanguage: contentLanguage ?? kUnknownMediaLanguageTag,
    );
  }

  /// Fetches fresh video entries for all subscribed sources from the worker.
  /// Automatically skips sources that were fetched within [minRefreshInterval]
  /// unless [force] is true.
  Future<DiscoverRefreshResult> refreshFeeds({bool force = false}) async {
    final subs = await _db.youtubeChannelSubscriptionDao.listAll();
    if (subs.isEmpty) {
      return const DiscoverRefreshResult(
        refreshedChannels: 0,
        failedChannelIds: [],
      );
    }

    final now = DateTime.now();
    final work = <YoutubeChannelSubscriptionRow>[];
    for (final sub in subs) {
      if (!force &&
          sub.lastFetchedAt != null &&
          now.difference(sub.lastFetchedAt!) < minRefreshInterval) {
        continue;
      }
      work.add(sub);
    }
    if (work.isEmpty) {
      return const DiscoverRefreshResult(
        refreshedChannels: 0,
        failedChannelIds: [],
      );
    }

    // Run up to [_kRefreshChannelConcurrency] channel refreshes in parallel.
    final results = <(String, bool)>[];
    for (var i = 0; i < work.length; i += _kRefreshChannelConcurrency) {
      final batch = work.sublist(
        i,
        i + _kRefreshChannelConcurrency > work.length
            ? work.length
            : i + _kRefreshChannelConcurrency,
      );
      results.addAll(
        await Future.wait(
          batch.map((sub) => _refreshSingleSource(sub, fetchedAt: now)),
        ),
      );
    }

    var refreshed = 0;
    final failed = <String>[];
    for (final (channelId, success) in results) {
      if (success) {
        refreshed++;
      } else {
        failed.add(channelId);
      }
    }

    return DiscoverRefreshResult(
      refreshedChannels: refreshed,
      failedChannelIds: List.unmodifiable(failed),
    );
  }

  /// Refreshes a single source by fetching its feed URL from the worker.
  Future<(String, bool)> _refreshSingleSource(
    YoutubeChannelSubscriptionRow sub, {
    required DateTime fetchedAt,
  }) async {
    final id = sub.channelId;
    var feedUrl = sub.feedUrl;
    if (feedUrl == null || feedUrl.isEmpty) {
      // Repair: generate feed URL from channel ID for legacy subscriptions
      // that were created before the migration backfilled feed_url.
      feedUrl = '${_urlParser.workerBaseUrl}/youtube/channel/$id?format=json';
      _log.info('Repairing missing feed URL for subscription $id');
      await _db.youtubeChannelSubscriptionDao.updateFeedUrl(id, feedUrl);
    }

    try {
      final result = await _feedClient.fetchFeed(feedUrl);

      await _upsertFeedEntries(id, result.feedResult.entries, fetchedAt);

      // Update subscription metadata (display name, avatar may change)
      await _db.youtubeChannelSubscriptionDao.upsert(
        YoutubeChannelSubscriptionRow(
          channelId: id,
          displayName: result.feedResult.displayName,
          thumbnailUrl: result.feedResult.iconUrl ?? sub.thumbnailUrl,
          source: sub.source,
          sourceType: sub.sourceType,
          feedUrl: sub.feedUrl,
          subscribedAt: sub.subscribedAt,
          lastFetchedAt: fetchedAt,
          language: sub.language,
        ),
      );

      return (id, true);
    } on WorkerFeedException catch (e) {
      _log.warning('Worker refresh failed for $id: ${e.message}');
      return (id, false);
    } catch (e, st) {
      _log.warning('Refresh failed for $id', e, st);
      return (id, false);
    }
  }

  DiscoverChannel _mapSubscription(YoutubeChannelSubscriptionRow row) {
    return DiscoverChannel(
      channelId: row.channelId,
      displayName: row.displayName,
      thumbnailUrl: row.thumbnailUrl,
      source: row.source,
      sourceType: row.sourceType,
      feedUrl: row.feedUrl,
      subscribedAt: row.subscribedAt,
      lastFetchedAt: row.lastFetchedAt,
    );
  }

  FeedEntry _mapFeedEntry(YoutubeFeedEntryRow row) {
    return FeedEntry(
      videoId: row.videoId,
      channelId: row.channelId,
      title: row.title,
      thumbnailUrl: row.thumbnailUrl,
      durationSeconds: row.durationSeconds,
      publishedAt: row.publishedAt,
    );
  }

  static bool looksLikeVideoThumbnail(String? url) {
    if (url == null || url.isEmpty) return false;
    return url.contains('i.ytimg.com/vi/');
  }
}
