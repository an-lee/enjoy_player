// Community coverage: avatars, stats, metrics, JSON parsing.
import 'package:enjoy_player/features/community/domain/active_user.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_avatars.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_metrics.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_stats.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('initials', () {
    test('returns "U" for empty or whitespace-only names', () {
      expect(initials(''), 'U');
      expect(initials('   '), 'U');
    });

    test('takes the first letter of the first whitespace-separated token', () {
      expect(initials('Alice'), 'A');
      expect(initials('  Alice  '), 'A');
    });

    test('takes the first two letters of a multi-token name', () {
      expect(initials('Alice Bob'), 'AB');
      expect(initials('alice BOB'), 'aB');
    });

    test('caps at two letters', () {
      expect(initials('Alice Bob Carol'), 'AB');
    });

    test('returns U when name has no alnum characters', () {
      expect(initials('!!!'), 'U');
      expect(initials('-- --'), 'U');
    });
  });

  group('ActiveUser.fromJson', () {
    test('reads id/name and rasterizes DiceBear svg URLs', () {
      final u = ActiveUser.fromJson(const {
        'id': 42,
        'name': 'Alice',
        'avatarUrl': 'https://api.dicebear.com/9.x/seed/svg',
      });
      expect(u.id, '42');
      expect(u.name, 'Alice');
      expect(u.avatarUrl, 'https://api.dicebear.com/9.x/seed/png');
    });

    test('preserves non-DiceBear URLs unchanged', () {
      final u = ActiveUser.fromJson(const {
        'id': 'u',
        'name': 'Bob',
        'avatarUrl': 'https://cdn.example.com/p.png',
      });
      expect(u.avatarUrl, 'https://cdn.example.com/p.png');
    });

    test('handles null avatarUrl', () {
      final u = ActiveUser.fromJson(const {'id': 'u', 'name': 'Bob'});
      expect(u.avatarUrl, isNull);
    });
  });

  group('ActiveUsersResponse.fromJson', () {
    test('parses empty users list', () {
      final r = ActiveUsersResponse.fromJson(const {'users': [], 'count': 0});
      expect(r.users, isEmpty);
      expect(r.count, 0);
      expect(r.recordingsCountToday, isNull);
      expect(r.recordingsDurationToday, isNull);
    });

    test('falls back to users.length when count is missing', () {
      final r = ActiveUsersResponse.fromJson(const {
        'users': [
          {'id': '1', 'name': 'a'},
          {'id': '2', 'name': 'b'},
        ],
      });
      expect(r.count, 2);
    });

    test('parses today stats as nullable ints', () {
      final r = ActiveUsersResponse.fromJson(const {
        'users': [],
        'count': 5,
        'recordingsCountToday': 7,
        'recordingsDurationToday': 1830000,
      });
      expect(r.recordingsCountToday, 7);
      expect(r.recordingsDurationToday, 1830000);
    });

    test('skips malformed user entries', () {
      final r = ActiveUsersResponse.fromJson(<String, dynamic>{
        'users': [
          {'id': '1', 'name': 'ok'},
          'not-a-map',
          null,
          {'id': '2', 'name': 'also-ok'},
        ],
        'count': 9,
      });
      expect(r.users.map((u) => u.id), ['1', '2']);
      expect(r.count, 9);
    });
  });

  group('community widgets', () {
    Widget localized(Widget Function(BuildContext) build) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Builder(builder: build),
      );
    }

    testWidgets('AvatarWrap renders +N chip when over capacity', (
      tester,
    ) async {
      final users = List.generate(
        10,
        (i) => ActiveUser(id: '$i', name: 'User $i'),
      );
      await tester.pumpWidget(
        localized(
          (ctx) => Scaffold(
            body: AvatarWrap(
              users: users,
              totalCount: 10,
              dense: true,
              maxShown: 3,
            ),
          ),
        ),
      );
      expect(find.text('+7'), findsOneWidget);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets('AvatarWrap shows no chip when count fits', (tester) async {
      final users = List.generate(
        3,
        (i) => ActiveUser(id: '$i', name: 'User $i'),
      );
      await tester.pumpWidget(
        localized(
          (ctx) => Scaffold(
            body: AvatarWrap(
              users: users,
              totalCount: 3,
              dense: false,
              maxShown: 5,
            ),
          ),
        ),
      );
      expect(find.textContaining('+'), findsNothing);
      expect(find.byType(Wrap), findsOneWidget);
    });

    testWidgets(
      'OverlappingAvatarStack paints +extra chip when over capacity',
      (tester) async {
        final users = List.generate(
          12,
          (i) => ActiveUser(id: '$i', name: 'U$i'),
        );
        await tester.pumpWidget(
          localized(
            (ctx) => Scaffold(
              body: SizedBox(
                width: 200,
                child: OverlappingAvatarStack(
                  users: users,
                  totalCount: 12,
                  maxShown: 4,
                  cs: Theme.of(ctx).colorScheme,
                ),
              ),
            ),
          ),
        );
        expect(find.text('+8'), findsOneWidget);
      },
    );

    testWidgets('InlineMetric and StatBlock render their text', (tester) async {
      await tester.pumpWidget(
        localized(
          (ctx) => Scaffold(
            body: Column(
              children: [
                InlineMetric(
                  icon: Icons.mic,
                  value: '5',
                  label: 'rec',
                  cs: Theme.of(ctx).colorScheme,
                  tabular: const [],
                ),
                const StatBlock(icon: Icons.mic, valueText: '5', label: 'rec'),
              ],
            ),
          ),
        ),
      );
      expect(find.text('5'), findsNWidgets(2));
      expect(find.text('rec'), findsNWidgets(2));
    });

    testWidgets('TodayStatsBody shows count + duration today branches', (
      tester,
    ) async {
      final data = const ActiveUsersResponse(
        users: [ActiveUser(id: '1', name: 'Alice')],
        count: 1,
        recordingsCountToday: 2,
        recordingsDurationToday: 1800000,
      );
      await tester.pumpWidget(
        localized(
          (ctx) =>
              Scaffold(body: TodayStatsBody(data: data, denseAvatars: true)),
        ),
      );
      expect(find.text('2'), findsOneWidget);
      expect(find.text('30m 0s'), findsOneWidget);
    });

    testWidgets('SimpleCountBody empty branch renders zero + label', (
      tester,
    ) async {
      const data = ActiveUsersResponse(users: [], count: 0);
      await tester.pumpWidget(
        localized(
          (ctx) => const Scaffold(
            body: SimpleCountBody(data: data, denseAvatars: true),
          ),
        ),
      );
      expect(find.text('0'), findsOneWidget);
    });

    testWidgets('SimpleCountBody non-empty shows count + avatar initials', (
      tester,
    ) async {
      final data = const ActiveUsersResponse(
        users: [ActiveUser(id: '1', name: 'Alice')],
        count: 7,
      );
      await tester.pumpWidget(
        localized(
          (ctx) =>
              Scaffold(body: SimpleCountBody(data: data, denseAvatars: true)),
        ),
      );
      expect(find.text('7'), findsOneWidget);
      expect(find.text('A'), findsOneWidget); // initials avatar text
    });

    testWidgets('ActiveLearnersRow renders count + avatars', (tester) async {
      final data = const ActiveUsersResponse(
        users: [
          ActiveUser(id: '1', name: 'Alice'),
          ActiveUser(id: '2', name: 'Bob'),
        ],
        count: 2,
      );
      await tester.pumpWidget(
        localized(
          (ctx) => Scaffold(body: ActiveLearnersRow(data: data, dense: true)),
        ),
      );
      expect(find.text('2'), findsOneWidget);
    });
  });
}
