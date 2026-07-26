import 'dart:async';

import 'package:go_router/go_router.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/youtube_subscription_source.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/discover/data/discover_repository.dart';
import 'package:enjoy_player/features/discover/domain/discover_channel.dart';
import 'package:enjoy_player/features/discover/domain/feed_entry.dart';
import 'package:enjoy_player/features/discover/presentation/channel_feed_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

const _channelId = 'UC_sub_001';
const _otherChannelId = 'UC_sub_002';

final _subscriptions = [
  DiscoverChannel(
    channelId: _channelId,
    displayName: 'TED',
    source: YoutubeSubscriptionSource.recommended,
    subscribedAt: DateTime.utc(2024, 1, 1),
  ),
  DiscoverChannel(
    channelId: _otherChannelId,
    displayName: 'Other Channel',
    source: YoutubeSubscriptionSource.recommended,
    subscribedAt: DateTime.utc(2024, 1, 1),
  ),
];

final _entries = [
  FeedEntry(
    videoId: 'vid_001',
    channelId: _channelId,
    title: 'First video',
    publishedAt: DateTime.utc(2024, 1, 1),
  ),
  FeedEntry(
    videoId: 'vid_002',
    channelId: _channelId,
    title: 'Second video',
    publishedAt: DateTime.utc(2024, 1, 2),
  ),
  FeedEntry(
    videoId: 'vid_003',
    channelId: _channelId,
    title: 'Third video',
    publishedAt: DateTime.utc(2024, 1, 3),
  ),
];

class _FakeDiscoverRepository extends DiscoverRepository {
  _FakeDiscoverRepository(super.db);

  int unsubscribeCalls = 0;

  @override
  Stream<List<DiscoverChannel>> watchSubscriptions() =>
      Stream.value(_subscriptions);

  @override
  Stream<List<FeedEntry>> watchChannelFeed(String channelId) =>
      Stream.value(_entries);

  @override
  Future<void> unsubscribe(String channelId) async {
    unsubscribeCalls++;
  }
}

late AppDatabase _db;
late _FakeDiscoverRepository _repo;

Widget _wrap({
  required Stream<List<DiscoverChannel>> subscriptions,
  required Stream<List<FeedEntry>> channelFeed,
  bool useRealRepo = true,
  List<Override> extraOverrides = const <Override>[],
}) {
  _repo = _FakeDiscoverRepository(_db);
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(_db),
      if (useRealRepo) discoverRepositoryProvider.overrideWithValue(_repo),
      discoverSubscriptionsProvider.overrideWith((ref) => subscriptions),
      discoverChannelFeedProvider.overrideWith((ref, channelId) => channelFeed),
      ...extraOverrides,
    ],
    child: const MaterialApp(
      localizationsDelegates: [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: ChannelFeedScreen(channelId: _channelId)),
    ),
  );
}

void main() {
  setUpAll(() {
    _db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDownAll(() async {
    await _db.close();
  });

  group('ChannelFeedScreen', () {
    testWidgets('renders the channel display name from subscriptions stream', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          channelFeed: Stream.value(_entries),
        ),
      );
      await tester.pumpAndSettle();

      // Title shows the channel display name resolved from subscriptions.
      expect(find.text('TED'), findsWidgets);
    });

    testWidgets(
      'renders the raw channelId when no matching subscription exists',
      (tester) async {
        await tester.pumpWidget(
          _wrap(
            subscriptions: Stream.value(<DiscoverChannel>[]),
            channelFeed: Stream.value(_entries),
          ),
        );
        await tester.pumpAndSettle();

        // Falls back to raw channelId in the title.
        expect(find.text(_channelId), findsWidgets);
      },
    );

    testWidgets('shows loading skeleton while channel feed is pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          channelFeed: const Stream<List<FeedEntry>>.empty(),
        ),
      );
      // First frame — the stream hasn't emitted yet → AsyncValue.loading.
      await tester.pump();

      // Skeleton list placeholder visible.
      expect(find.byType(SkeletonMediaList), findsOneWidget);
    });

    testWidgets('shows empty state when channel feed stream emits nothing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          channelFeed: Stream.value(<FeedEntry>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No videos in feed yet'), findsOneWidget);
      expect(
        find.text('Subscribe to a channel and refresh to load recent uploads.'),
        findsOneWidget,
      );
    });

    testWidgets('renders error state when channel feed stream errors', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          channelFeed: Stream<List<FeedEntry>>.error(Exception('boom')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load feed'), findsOneWidget);
      expect(find.text('Check your connection and try again.'), findsOneWidget);
    });

    testWidgets(
      'renders a list of DiscoverFeedTile widgets when viewport is narrow',
      (tester) async {
        // Use a small width to ensure we hit the crossAxisCount == 1 branch.
        tester.view.physicalSize = const Size(360, 800);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);

        await tester.pumpWidget(
          _wrap(
            subscriptions: Stream.value(_subscriptions),
            channelFeed: Stream.value(_entries),
          ),
        );
        await tester.pumpAndSettle();

        // Every entry's title is shown via DiscoverFeedTile.
        expect(find.text('First video'), findsOneWidget);
        expect(find.text('Second video'), findsOneWidget);
        expect(find.text('Third video'), findsOneWidget);
      },
    );

    testWidgets(
      'the unsubscribed icon button triggers repository unsubscribe',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => const Scaffold(body: SizedBox()),
            ),
            GoRoute(
              path: '/discover',
              builder: (context, state) => const Scaffold(
                body: ChannelFeedScreen(channelId: _channelId),
              ),
            ),
          ],
        );
        addTearDown(router.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              appDatabaseProvider.overrideWithValue(_db),
              discoverRepositoryProvider.overrideWithValue(_repo),
              discoverSubscriptionsProvider.overrideWith(
                (ref) => Stream.value(_subscriptions),
              ),
              discoverChannelFeedProvider.overrideWith(
                (ref, channelId) => Stream.value(_entries),
              ),
            ],
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: const [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Navigate forward onto the channel feed so the stack has 2 entries
        // (context.pop() below needs something above to pop back to).
        unawaited(router.push('/discover'));
        await tester.pumpAndSettle();

        final before = _repo.unsubscribeCalls;

        // Find the IconButton with the bell-off icon and tap.
        final unsubscribe = find.byIcon(Icons.notifications_off_outlined);
        expect(unsubscribe, findsOneWidget);

        await tester.tap(unsubscribe);
        await tester.pumpAndSettle();

        expect(_repo.unsubscribeCalls, before + 1);
      },
    );
  });
}
