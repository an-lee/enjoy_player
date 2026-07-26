import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/youtube_subscription_source.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/discover/data/discover_repository.dart';
import 'package:enjoy_player/features/discover/domain/discover_channel.dart';
import 'package:enjoy_player/features/discover/domain/feed_entry.dart';
import 'package:enjoy_player/features/discover/presentation/discover_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _channelId = 'UC_sub_001';

final _subscriptions = [
  DiscoverChannel(
    channelId: _channelId,
    displayName: 'TED',
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
];

class _FakeDiscoverRepository extends DiscoverRepository {
  _FakeDiscoverRepository(super.db);

  @override
  Stream<List<DiscoverChannel>> watchSubscriptions() => const Stream.empty();

  @override
  Stream<List<FeedEntry>> watchTimeline() => const Stream.empty();

  @override
  Stream<List<FeedEntry>> watchChannelFeed(String channelId) =>
      const Stream.empty();
}

late AppDatabase _db;

Widget _wrap({
  required Stream<List<DiscoverChannel>> subscriptions,
  required Stream<List<FeedEntry>> timeline,
  bool refreshing = false,
}) {
  return ProviderScope(
    overrides: [
      appDatabaseProvider.overrideWithValue(_db),
      discoverRepositoryProvider.overrideWithValue(
        _FakeDiscoverRepository(_db),
      ),
      discoverSubscriptionsProvider.overrideWith((ref) => subscriptions),
      filteredDiscoverTimelineProvider.overrideWith((ref) => timeline),
      discoverChannelFeedProvider.overrideWith((ref, channelId) => timeline),
      discoverRefreshStateProvider.overrideWith(
        () => _FakeRefreshState(refreshing: refreshing),
      ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: const Scaffold(body: DiscoverScreen()),
    ),
  );
}

class _FakeRefreshState extends DiscoverRefreshState {
  _FakeRefreshState({required this.refreshing});

  final bool refreshing;

  @override
  bool build() => refreshing;

  @override
  Future<DiscoverRefreshResult> refresh({bool force = false}) async {
    return const DiscoverRefreshResult(
      refreshedChannels: 0,
      failedChannelIds: [],
    );
  }
}

void main() {
  setUpAll(() {
    _db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDownAll(() async {
    await _db.close();
  });

  group('DiscoverScreen', () {
    testWidgets('shows loading skeleton while subscriptions stream pending', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: const Stream<List<DiscoverChannel>>.empty(),
          timeline: const Stream<List<FeedEntry>>.empty(),
        ),
      );
      // Initial frame, no pumpAndSettle (avoid hanging on animations).
      await tester.pump();

      expect(find.byType(Skeleton), findsWidgets);
    });

    testWidgets('shows empty state when no subscriptions', (tester) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(const <DiscoverChannel>[]),
          timeline: const Stream<List<FeedEntry>>.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No videos in feed yet'), findsOneWidget);
      expect(find.text('Manage channels'), findsOneWidget);
    });

    testWidgets('shows error text when subscriptions fail', (tester) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream<List<DiscoverChannel>>.error(
            Exception('db broken'),
          ),
          timeline: const Stream<List<FeedEntry>>.empty(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load subscriptions.'), findsOneWidget);
    });

    testWidgets('shows feed tiles when subscriptions + entries available', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          timeline: Stream.value(_entries),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('First video'), findsOneWidget);
      expect(find.text('Second video'), findsOneWidget);
      // At narrow constraints a SliverList is used.
      expect(find.byType(SliverList), findsWidgets);
    });

    testWidgets('shows feed empty state when entries are empty', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          timeline: Stream.value(const <FeedEntry>[]),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('No videos in feed yet'), findsOneWidget);
    });

    testWidgets('shows feed error retry card when feed fails', (tester) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          timeline: Stream<List<FeedEntry>>.error(Exception('network down')),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Could not load feed'), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('shows LinearProgressIndicator when refreshing', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          subscriptions: Stream.value(_subscriptions),
          timeline: Stream.value(_entries),
          refreshing: true,
        ),
      );
      await tester.pump();

      expect(find.byType(LinearProgressIndicator), findsOneWidget);
    });
  });
}
