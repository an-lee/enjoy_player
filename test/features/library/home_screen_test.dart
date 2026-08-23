import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/media_card/tile.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/community/application/active_users_provider.dart';
import 'package:enjoy_player/features/community/domain/active_user.dart';
import 'package:enjoy_player/features/library/application/home_continue_practice_provider.dart';
import 'package:enjoy_player/features/library/application/library_media_provider.dart';
import 'package:enjoy_player/features/library/application/learning_statistics_provider.dart';
import 'package:enjoy_player/features/library/domain/learning_statistics.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/domain/practice_resume.dart';
import 'package:enjoy_player/features/library/presentation/home_screen.dart';
import 'package:enjoy_player/features/library/presentation/widgets/continue_practice_card.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 'a@b.com', name: 'A'),
  );
}

class _FakePrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => AppPreferencesState.initial;
}

PracticeResume _resume({
  String id = 'practiced-1',
  String title = 'Practiced talk',
}) {
  final ts = DateTime.utc(2026, 1, 1);
  return PracticeResume(
    media: Media(
      id: id,
      kind: MediaKind.video,
      title: title,
      sourceUri: 'file:///$id',
      durationMs: 60000,
      language: 'en-US',
      contentHash: id,
      fileSize: 1,
      createdAt: ts,
      updatedAt: ts,
    ),
    positionMs: 15000,
    echoActive: false,
    lastActiveAt: ts,
    sessionId: 's1',
  );
}

Media _recent({required String id, required String title}) {
  final ts = DateTime.utc(2026, 2, 1);
  return Media(
    id: id,
    kind: MediaKind.video,
    title: title,
    sourceUri: 'file:///$id',
    durationMs: 60000,
    language: 'en-US',
    contentHash: id,
    fileSize: 1,
    createdAt: ts,
    updatedAt: ts,
  );
}

List<Override> _homeOverrides({
  PracticeResume? resume,
  List<Media> recents = const [],
}) {
  return [
    authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
    appPreferencesCtrlProvider.overrideWith(_FakePrefsCtrl.new),
    homeContinuePracticeProvider.overrideWith((ref) => resume),
    libraryHomeRecentsProvider.overrideWith((ref) => Stream.value(recents)),
    learningStatisticsProvider.overrideWith(
      (ref) async => LearningStatistics.empty(),
    ),
    activeUsersProvider.overrideWith(
      (ref) async => const ActiveUsersResponse(users: [], count: 0),
    ),
  ];
}

Widget _themedHomeWithRouter(
  GoRouter router, {
  List<Override> overrides = const [],
}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp.router(
      routerConfig: router,
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeScreen', () {
    testWidgets(
      "shows Today's Goal + Community cards even when recents is empty",
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        );
        await tester.pumpWidget(
          _themedHomeWithRouter(router, overrides: _homeOverrides()),
        );
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        // Empty-state copy is still shown for the recents section.
        expect(find.text(l10n.homeEmptyTitle), findsOneWidget);

        // Insight cards render alongside the empty state, as they do when
        // recents are populated.
        expect(find.text(l10n.homeTodaysGoal), findsOneWidget);
        expect(find.text(l10n.communityActivity), findsOneWidget);
      },
    );

    testWidgets('Craft action navigates to /craft', (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          GoRoute(
            path: '/craft',
            builder: (context, state) =>
                const Scaffold(body: Text('craft-open')),
          ),
        ],
      );

      await tester.pumpWidget(
        _themedHomeWithRouter(router, overrides: _homeOverrides()),
      );
      await tester.pumpAndSettle();

      final l10n = await AppLocalizations.delegate.load(const Locale('en'));

      await tester.tap(
        find.widgetWithText(OutlinedButton, l10n.homeCraftAction),
      );
      await tester.pumpAndSettle();

      expect(find.text('craft-open'), findsOneWidget);
      expect(router.state.uri.path, '/craft');
    });

    testWidgets(
      'hides Continue card when resume is null and recents are empty',
      (tester) async {
        final router = GoRouter(
          initialLocation: '/',
          routes: [
            GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
          ],
        );
        await tester.pumpWidget(
          _themedHomeWithRouter(router, overrides: _homeOverrides()),
        );
        await tester.pumpAndSettle();
        final l10n = await AppLocalizations.delegate.load(const Locale('en'));
        expect(find.text(l10n.homeContinuePracticing), findsNothing);
        expect(find.byType(ContinuePracticeCard), findsNothing);
        expect(find.text(l10n.homeEmptyTitle), findsOneWidget);
        expect(find.text(l10n.homeTodaysGoal), findsOneWidget);
      },
    );

    testWidgets('shows Continue hero above recents grid', (tester) async {
      tester.view.physicalSize = const Size(800, 2000);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(path: '/', builder: (context, state) => const HomeScreen()),
        ],
      );
      await tester.pumpWidget(
        _themedHomeWithRouter(
          router,
          overrides: _homeOverrides(
            resume: _resume(),
            recents: [
              _recent(id: 'practiced-1', title: 'Practiced talk'),
              _recent(id: 'other', title: 'Other item'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(find.text(l10n.homeContinuePracticing), findsOneWidget);
      expect(find.byType(ContinuePracticeCard), findsOneWidget);
      expect(find.byType(MediaCardTile), findsWidgets);
      expect(find.text(l10n.homeRecentMedia), findsOneWidget);
    });
  });
}
