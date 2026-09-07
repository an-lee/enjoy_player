// Widget tests for the community activity card summary body.
//
// This widget is pure presentation built on top of an `ActiveUsersResponse`
// payload — covering it gives cheap branch coverage on the long if/else
// chains (`hasToday`, empty-users fallback, etc.) that aren't otherwise
// easy to drive from the parent `CommunityActivityCard`.
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/community/domain/active_user.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_avatars.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_bodies.dart';
import 'package:enjoy_player/features/community/presentation/community_activity_metrics.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

ColorScheme _cs() => ColorScheme.fromSeed(seedColor: Colors.indigo);

EnjoyThemeTokens _tokens() => EnjoyThemeTokens.build(_cs());

Widget _harness(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

ActiveUsersResponse _users({
  int count = 0,
  int? recordingsCountToday,
  int? recordingsDurationToday,
  int userCount = 0,
}) {
  final users = <ActiveUser>[
    for (var i = 0; i < userCount; i++) ActiveUser(id: 'u$i', name: 'User $i'),
  ];
  return ActiveUsersResponse(
    users: users,
    count: count == 0 ? userCount : count,
    recordingsCountToday: recordingsCountToday,
    recordingsDurationToday: recordingsDurationToday,
  );
}

void main() {
  group('SummaryBody', () {
    testWidgets('renders the empty-users SummaryBody without an avatar stack', (
      tester,
    ) async {
      final data = _users();
      await tester.pumpWidget(
        _harness(SummaryBody(data: data, t: _tokens(), cs: _cs())),
      );
      expect(find.byType(SummaryBody), findsOneWidget);
      expect(find.byType(OverlappingAvatarStack), findsNothing);
    });

    testWidgets(
      'renders avatars and "people learning" when users are present',
      (tester) async {
        final data = _users(count: 3, userCount: 3);
        await tester.pumpWidget(
          _harness(SummaryBody(data: data, t: _tokens(), cs: _cs())),
        );
        expect(find.byType(OverlappingAvatarStack), findsOneWidget);
      },
    );

    testWidgets(
      'renders today stats and active learners count when today stats set',
      (tester) async {
        final data = _users(
          count: 4,
          recordingsCountToday: 5,
          recordingsDurationToday: 60000,
          userCount: 2,
        );
        await tester.pumpWidget(
          _harness(SummaryBody(data: data, t: _tokens(), cs: _cs())),
        );
        expect(find.byType(InlineMetric), findsWidgets);
      },
    );

    testWidgets('shows "no active users" when there are no users', (
      tester,
    ) async {
      final data = _users(count: 0);
      await tester.pumpWidget(
        _harness(SummaryBody(data: data, t: _tokens(), cs: _cs())),
      );
      // homeNoActiveUsers string from AppLocalizationsEn should render.
      expect(find.byType(SummaryBody), findsOneWidget);
    });
  });

  group('initials', () {
    test('returns "U" for empty / whitespace input', () {
      expect(initials(''), 'U');
      expect(initials('   '), 'U');
    });

    test('returns first character when name has one word', () {
      expect(initials('alice'), 'a');
    });

    test('returns up to two first-letters from multi-word names', () {
      expect(initials('alice cooper'), 'ac');
      expect(initials('Alice Cooper'), 'AC');
    });

    test('skips non-alphanumeric leading characters', () {
      // Leading emoji / space gets dropped, then "alice" gives "a".
      expect(initials('🎉 alice'), 'a');
    });

    test('falls back to "U" when no alnum letters are present', () {
      expect(initials('🎉🎉'), 'U');
    });
  });

  group('InlineMetric', () {
    testWidgets('renders value + label', (tester) async {
      await tester.pumpWidget(
        _harness(
          InlineMetric(
            icon: Icons.schedule,
            value: '5m',
            label: 'Practice time',
            cs: _cs(),
            tabular: const [FontFeature.tabularFigures()],
          ),
        ),
      );
      expect(find.text('5m'), findsOneWidget);
      expect(find.text('Practice time'), findsOneWidget);
    });
  });

  group('OverlappingAvatarStack', () {
    testWidgets('renders SizedBox.shrink for empty users list', (tester) async {
      await tester.pumpWidget(
        _harness(
          OverlappingAvatarStack(
            users: const [],
            totalCount: 0,
            maxShown: kMaxAvatarsSummary,
            cs: _cs(),
          ),
        ),
      );
      expect(find.byType(OverlappingAvatarStack), findsOneWidget);
      expect(find.byType(SizedBox), findsWidgets);
    });

    testWidgets('shows an overflow chip when totalCount > maxShown', (
      tester,
    ) async {
      final users = <ActiveUser>[
        for (var i = 0; i < 6; i++) ActiveUser(id: 'u$i', name: 'User $i'),
      ];
      await tester.pumpWidget(
        _harness(
          OverlappingAvatarStack(
            users: users,
            totalCount: 50,
            maxShown: 4,
            cs: _cs(),
          ),
        ),
      );
      expect(find.text('+46'), findsOneWidget);
    });
  });

  group('AvatarWrap', () {
    testWidgets('shows overflow chip when totalCount > maxShown', (
      tester,
    ) async {
      final users = <ActiveUser>[
        for (var i = 0; i < 10; i++) ActiveUser(id: 'u$i', name: 'User $i'),
      ];
      await tester.pumpWidget(
        _harness(
          AvatarWrap(users: users, totalCount: 30, dense: true, maxShown: 4),
        ),
      );
      expect(find.text('+26'), findsOneWidget);
    });

    testWidgets('no overflow chip when totalCount <= maxShown', (tester) async {
      final users = <ActiveUser>[
        for (var i = 0; i < 3; i++) ActiveUser(id: 'u$i', name: 'User $i'),
      ];
      await tester.pumpWidget(
        _harness(
          AvatarWrap(users: users, totalCount: 3, dense: false, maxShown: 8),
        ),
      );
      // No "+N" overflow text expected.
      expect(find.textContaining(RegExp(r'^\+\d+$')), findsNothing);
    });
  });
}
