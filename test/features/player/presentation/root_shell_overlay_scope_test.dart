// Issue #663 (rebuild scope, item B): opening / closing a transient overlay
// (dialog, sheet, menu, notice) must not rebuild RootShell.
//
// The shell used to watch `playerSurfaceShouldParkForOverlayProvider`, so
// every coordinator token change re-ran its build — LayoutBuilder, nav or
// sidebar, and both scaffolds — when only [PlayerSurfaceHost] needed to move
// the surface. The host now watches the coordinator itself (pinned by
// `player_surface_host_test.dart`); this file pins that the *shell* stays
// untouched.
//
// Structural signal: RootShell constructs a fresh non-const [AppBackground]
// (wrapping a fresh [LayoutBuilder]) on every build, so widget-instance
// identity is a build counter — no timing involved
// (docs/perf-measurement.md, "structural, deterministic assertions").
import 'package:drift/native.dart';
import 'package:enjoy_player/core/player/player_surface_overlay_coordinator.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/app_background.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/root_shell.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_host.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/sync/application/sync_controller.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _NullPlayerController extends PlayerController {
  @override
  PlaybackSession? build() => null;
}

class _FakeVocabSession extends VocabularyReviewSession {
  @override
  ReviewSessionState build() => const ReviewSessionState(queue: []);
}

GoRouter _router({required String initial}) {
  return GoRouter(
    initialLocation: initial,
    routes: [
      ShellRoute(
        builder: (context, state, child) => RootShell(child: child),
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home-page')),
          ),
          GoRoute(
            path: '/youtube/login',
            builder: (_, _) => const Scaffold(body: Text('youtube-login-page')),
          ),
        ],
      ),
    ],
  );
}

List<Override> _overrides(AppDatabase db) {
  return [
    appDatabaseProvider.overrideWithValue(db),
    deviceGlobalAppDatabaseProvider.overrideWithValue(db),
    syncCtrlProvider.overrideWithValue(0),
    discoverFeedRefreshSchedulerProvider.overrideWithValue(0),
    updateAvailableBadgeProvider.overrideWithValue(false),
    subscriptionStatusProvider.overrideWith(
      (ref) async => const SubscriptionStatus(
        subscriptionActive: false,
        subscriptionTier: SubscriptionTier.free,
      ),
    ),
    vocabularyReviewSessionProvider.overrideWith(_FakeVocabSession.new),
    playerControllerProvider.overrideWith(_NullPlayerController.new),
  ];
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  required String initial,
  required AppDatabase db,
}) async {
  final router = _router(initial: initial);
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(const Size(400, 900));
  addTearDown(() => tester.view.resetPhysicalSize());

  final container = ProviderContainer(overrides: _overrides(db));
  addTearDown(container.dispose);

  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp.router(
        theme: ThemeData(
          colorScheme: scheme,
          extensions: [EnjoyThemeTokens.build(scheme)],
        ),
        locale: const Locale('en', 'US'),
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 100));
  return container;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('overlay open/close does not rebuild RootShell', (tester) async {
    final container = await _pump(tester, initial: '/', db: db);

    final shellBefore = tester.widget<AppBackground>(
      find.byType(AppBackground),
    );
    final hostBefore = tester.widget<PlayerSurfaceHost>(
      find.byType(PlayerSurfaceHost),
    );

    final token = container
        .read(playerSurfaceOverlayCoordinatorProvider.notifier)
        .acquire('notice');
    await tester.pump();
    await tester.pump();

    // The overlay hold must not have re-run the shell's build…
    expect(
      tester.widget<AppBackground>(find.byType(AppBackground)),
      same(shellBefore),
      reason:
          'Acquiring an overlay token rebuilt RootShell; the park decision '
          'belongs to PlayerSurfaceHost alone (issue #663)',
    );
    // …nor re-allocated the shell-level host wiring.
    expect(
      tester.widget<PlayerSurfaceHost>(find.byType(PlayerSurfaceHost)),
      same(hostBefore),
    );

    container
        .read(playerSurfaceOverlayCoordinatorProvider.notifier)
        .release(token);
    await tester.pump();
    await tester.pump();

    expect(
      tester.widget<AppBackground>(find.byType(AppBackground)),
      same(shellBefore),
    );
  });

  testWidgets('shell keeps only the /youtube/login path flag', (tester) async {
    // The route flag is the one park reason RootShell still owns: it is
    // derived from the path it already computes for nav chrome.
    final container = await _pump(tester, initial: '/', db: db);
    expect(
      tester
          .widget<PlayerSurfaceHost>(find.byType(PlayerSurfaceHost))
          .forcePark,
      isFalse,
    );

    container.dispose();
    // Re-pump on the login route: the shell passes its path flag through.
    final loginContainer = await _pump(
      tester,
      initial: '/youtube/login',
      db: db,
    );
    addTearDown(loginContainer.dispose);
    expect(
      tester
          .widget<PlayerSurfaceHost>(find.byType(PlayerSurfaceHost))
          .forcePark,
      isTrue,
    );
  });
}
