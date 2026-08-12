import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/community/application/active_users_provider.dart';
import 'package:enjoy_player/features/community/domain/active_user.dart';
import 'package:enjoy_player/features/library/application/library_media_provider.dart';
import 'package:enjoy_player/features/library/application/learning_statistics_provider.dart';
import 'package:enjoy_player/features/library/domain/learning_statistics.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/presentation/home_screen.dart';
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
          _themedHomeWithRouter(
            router,
            overrides: [
              authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
              libraryHomeRecentsProvider.overrideWith(
                (ref) => Stream.value(<Media>[]),
              ),
              learningStatisticsProvider.overrideWith(
                (ref) async => LearningStatistics.empty(),
              ),
              activeUsersProvider.overrideWith(
                (ref) async => const ActiveUsersResponse(users: [], count: 0),
              ),
            ],
          ),
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
        _themedHomeWithRouter(
          router,
          overrides: [
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            libraryHomeRecentsProvider.overrideWith(
              (ref) => Stream.value(<Media>[]),
            ),
            learningStatisticsProvider.overrideWith(
              (ref) async => LearningStatistics.empty(),
            ),
            activeUsersProvider.overrideWith(
              (ref) async => const ActiveUsersResponse(users: [], count: 0),
            ),
          ],
        ),
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
  });
}
