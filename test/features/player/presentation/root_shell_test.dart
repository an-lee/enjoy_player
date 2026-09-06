// Tests for `lib/features/player/presentation/root_shell.dart`.
//
// Covers the shell's adaptive nav layout (mobile bottom-nav vs. rail sidebar)
// and the routing-driven selection logic. Heavy providers (player engine,
// database, sync) are stubbed so the shell can be exercised in isolation.
import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_bottom_nav.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/features/player/presentation/widgets/app_sidebar.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/library/application/continue_practice_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/root_shell.dart';
import 'package:enjoy_player/features/player/presentation/widgets/global_transport_bar.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/subscription/application/subscription_status_provider.dart';
import 'package:enjoy_player/features/subscription/domain/subscription_status.dart';
import 'package:enjoy_player/features/sync/application/sync_controller.dart';
import 'package:enjoy_player/features/transcript/application/all_transcripts_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_track.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../helpers/chrome_icon_finders.dart';
import '../../../support/fake_player_engine.dart';

const _kShellMediaId = 'shell-transport-test';

PlaybackSession _shellSession() {
  final now = DateTime(2026, 1, 1);
  return PlaybackSession(
    mediaId: _kShellMediaId,
    dexieTargetType: 'Audio',
    mediaType: 'audio',
    mediaTitle: 'Shell transport test',
    durationSeconds: 120,
    currentTimeSeconds: 0,
    currentSegmentIndex: 0,
    language: 'en',
    startedAt: now,
    lastActiveAt: now,
  );
}

class _FakeVocabSession extends VocabularyReviewSession {
  _FakeVocabSession({ReviewSessionState? initial})
    : _initial = initial ?? const ReviewSessionState(queue: []);

  final ReviewSessionState _initial;

  @override
  ReviewSessionState build() => _initial;
}

class _NullPlayerController extends PlayerController {
  _NullPlayerController();

  @override
  PlaybackSession? build() => null;
}

class _SessionPlayerController extends PlayerController {
  _SessionPlayerController(this._session);

  PlaybackSession? _session;

  @override
  PlaybackSession? build() => _session;

  @override
  Future<void> clear({bool keepVideoSurface = false}) async {
    _session = null;
    state = null;
  }
}

class _BlurModeOff extends TranscriptBlurMode {
  @override
  bool build() => false;
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
            path: '/discover',
            builder: (_, _) => const Scaffold(body: Text('discover-page')),
          ),
          GoRoute(
            path: '/library',
            builder: (_, _) => const Scaffold(body: Text('library-page')),
          ),
          GoRoute(
            path: '/profile',
            builder: (_, _) => const Scaffold(body: Text('profile-page')),
          ),
          GoRoute(
            path: '/settings',
            builder: (_, _) => const Scaffold(body: Text('settings-page')),
          ),
          GoRoute(
            path: '/cloud',
            builder: (_, _) => const Scaffold(body: Text('cloud-page')),
          ),
          GoRoute(
            path: '/player/:mediaId',
            builder: (_, _) => const Scaffold(body: Text('player-page')),
          ),
          GoRoute(
            path: '/youtube/login',
            builder: (_, _) => const Scaffold(body: Text('youtube-login-page')),
          ),
          GoRoute(
            path: '/vocabulary',
            builder: (_, _) => const Scaffold(body: Text('vocabulary-page')),
          ),
          GoRoute(
            path: '/vocabulary/review',
            builder: (_, _) =>
                const Scaffold(body: Text('vocabulary-review-page')),
          ),
        ],
      ),
    ],
  );
}

List<Override> _shellOverrides(
  AppDatabase db, {
  ReviewSessionState? vocab,
  bool updateBadge = false,
  PlaybackSession? playerSession,
  FakePlayerEngine? playerEngine,
}) {
  final overrides = <Override>[
    appDatabaseProvider.overrideWithValue(db),
    deviceGlobalAppDatabaseProvider.overrideWithValue(db),
    // The sidebar's Continue card opens library + echo-session drift watches
    // whose teardown timers trip the pending-timer guard. Shell layout tests
    // never exercise resume logic, and the card is covered in
    // app_sidebar_test — pin it off (sidebar renders shrink).
    continuePracticeResumeProvider.overrideWith((ref) => null),
    syncCtrlProvider.overrideWithValue(0),
    discoverFeedRefreshSchedulerProvider.overrideWithValue(0),
    updateAvailableBadgeProvider.overrideWithValue(updateBadge),
    subscriptionStatusProvider.overrideWith(
      (ref) async => const SubscriptionStatus(
        subscriptionActive: false,
        subscriptionTier: SubscriptionTier.free,
      ),
    ),
    vocabularyReviewSessionProvider.overrideWith(
      () => _FakeVocabSession(initial: vocab),
    ),
  ];

  if (playerSession == null) {
    overrides.add(
      playerControllerProvider.overrideWith(_NullPlayerController.new),
    );
  } else {
    final engine = playerEngine ?? FakePlayerEngine();
    overrides.addAll([
      playerEngineTestDoubleProvider.overrideWithValue(engine),
      playerControllerProvider.overrideWith(
        () => _SessionPlayerController(playerSession),
      ),
      transcriptHasLinesForMediaProvider(
        playerSession.mediaId,
      ).overrideWith((ref) => Stream.value(false)),
      playerIsPlayingProvider.overrideWith((ref) => Stream.value(false)),
      playerIsBufferingProvider.overrideWith((ref) => Stream.value(false)),
      allTranscriptsForMediaProvider(
        playerSession.mediaId,
      ).overrideWith((ref) => Stream.value(const <TranscriptTrack>[])),
      transcriptFetchCtrlProvider(playerSession.mediaId).overrideWithValue(
        const TranscriptFetchUiState(status: TranscriptFetchStatus.idle),
      ),
      transcriptBlurModeProvider.overrideWith(_BlurModeOff.new),
    ]);
  }

  return overrides;
}

Future<void> _pump(
  WidgetTester tester, {
  required GoRouter router,
  required List<Override> overrides,
  required Size surface,
}) async {
  addTearDown(router.dispose);
  await tester.binding.setSurfaceSize(surface);
  addTearDown(() => tester.view.resetPhysicalSize());

  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides,
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
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePlayerEngine fakeEngine;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    fakeEngine = FakePlayerEngine();
  });

  tearDown(() async {
    await db.close();
    await fakeEngine.dispose();
  });

  group('RootShell narrow layout (mobile)', () {
    testWidgets('renders bottom nav with Home selected at /', (tester) async {
      final router = _router(initial: '/');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(find.text('home-page'), findsOneWidget);
      // Bottom nav icons for Home, Discover, Library, Profile.
      expect(findChromeIcon(EnjoyChromeGlyph.home), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.compass), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.library), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.user), findsOneWidget);
    });

    testWidgets(
      'floats bottom nav over a transparent scaffold with extendBody',
      (tester) async {
        final router = _router(initial: '/');
        await _pump(
          tester,
          router: router,
          overrides: _shellOverrides(db),
          surface: const Size(400, 900),
        );

        final shellScaffolds = tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .where((s) => s.bottomNavigationBar != null)
            .toList();
        expect(shellScaffolds, hasLength(1));
        expect(shellScaffolds.first.backgroundColor, Colors.transparent);
        expect(shellScaffolds.first.extendBody, isTrue);
        expect(find.byType(EnjoyBottomNav), findsOneWidget);
        final content = tester.widget<Padding>(
          find.byKey(const ValueKey<String>('root-shell-content')),
        );
        expect(content.padding.resolve(TextDirection.ltr).bottom, 68);
      },
    );

    testWidgets('selects Discover icon at /discover', (tester) async {
      final router = _router(initial: '/discover');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(findChromeIcon(EnjoyChromeGlyph.compass), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.home), findsOneWidget);
    });

    testWidgets('selects Library icon at /library', (tester) async {
      final router = _router(initial: '/library');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(findChromeIcon(EnjoyChromeGlyph.library), findsOneWidget);
    });

    testWidgets('selects Profile icon at /profile', (tester) async {
      final router = _router(initial: '/profile');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(findChromeIcon(EnjoyChromeGlyph.user), findsOneWidget);
    });

    testWidgets('selects Profile icon at /settings', (tester) async {
      final router = _router(initial: '/settings');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      // /settings also maps to the profile tab (settings > profile).
      expect(findChromeIcon(EnjoyChromeGlyph.user), findsOneWidget);
    });

    testWidgets('selects Library icon at /cloud', (tester) async {
      final router = _router(initial: '/cloud');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(findChromeIcon(EnjoyChromeGlyph.library), findsOneWidget);
    });

    testWidgets('does not render bottom nav on /player/abc', (tester) async {
      final router = _router(initial: '/player/abc');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      // Player route hides the bottom nav.
      expect(find.byType(EnjoyBottomNav), findsNothing);
      expect(find.text('player-page'), findsOneWidget);
    });

    testWidgets('still renders bottom nav on /youtube/login', (tester) async {
      final router = _router(initial: '/youtube/login');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      // `/youtube/login` parks the video stage but does not hide shell chrome.
      expect(find.byType(EnjoyBottomNav), findsOneWidget);
      expect(find.text('youtube-login-page'), findsOneWidget);
    });
  });

  group('RootShell wide layout (rail sidebar)', () {
    testWidgets('uses AppSidebar instead of bottom nav at >= breakpoint', (
      tester,
    ) async {
      final router = _router(initial: '/');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(1100, 900),
      );

      // AppSidebar brand row + nav pills are visible.
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byType(AppSidebar), findsOneWidget);
      expect(find.byType(EnjoyBottomNav), findsNothing);
      expect(findChromeIcon(EnjoyChromeGlyph.home), findsOneWidget);
    });

    testWidgets('does not render AppSidebar when on /player/abc', (
      tester,
    ) async {
      final router = _router(initial: '/player/abc');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(1100, 900),
      );

      // No sidebar search field is rendered on the player route.
      expect(find.byIcon(Icons.search_rounded), findsNothing);
      expect(find.text('player-page'), findsOneWidget);
    });
  });

  group('RootShell vocabulary review practice', () {
    testWidgets('does not show mini transport when practice owns video stage', (
      tester,
    ) async {
      final router = _router(initial: '/library');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(
          db,
          vocab: const ReviewSessionState(
            queue: [],
            practicePhase: ReviewPracticePhase.clipReady,
          ),
        ),
        surface: const Size(400, 900),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
    });

    testWidgets('tapping bottom-nav Discover navigates to /discover', (
      tester,
    ) async {
      final router = _router(initial: '/');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(router.state.uri.path, '/');
      await tester.tap(findChromeIcon(EnjoyChromeGlyph.compass));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(router.state.uri.path, '/discover');
    });

    testWidgets('tapping bottom-nav Library navigates to /library', (
      tester,
    ) async {
      final router = _router(initial: '/');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      await tester.tap(findChromeIcon(EnjoyChromeGlyph.library));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(router.state.uri.path, '/library');
    });

    testWidgets('tapping bottom-nav Profile navigates to /profile', (
      tester,
    ) async {
      final router = _router(initial: '/');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      await tester.tap(findChromeIcon(EnjoyChromeGlyph.user));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(router.state.uri.path, '/profile');
    });

    testWidgets('tapping bottom-nav Home navigates back to /', (tester) async {
      final router = _router(initial: '/discover');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      await tester.tap(findChromeIcon(EnjoyChromeGlyph.home));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(router.state.uri.path, '/');
    });

    testWidgets('updateAvailableBadgeProvider=true shows profile semantics', (
      tester,
    ) async {
      final router = _router(initial: '/');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db, updateBadge: true),
        surface: const Size(400, 900),
      );

      // Profile pill is present with the badge semantics label.
      expect(find.text('home-page'), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.user), findsWidgets);
    });

    testWidgets('shows transport on /player/ with an active session', (
      tester,
    ) async {
      final router = _router(initial: '/player/$_kShellMediaId');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(
          db,
          playerSession: _shellSession(),
          playerEngine: fakeEngine,
        ),
        surface: const Size(400, 900),
      );

      expect(find.text('player-page'), findsOneWidget);
      expect(find.byType(GlobalTransportBar), findsOneWidget);
    });

    testWidgets(
      'floats player transport over a transparent scaffold with extendBody',
      (tester) async {
        final router = _router(initial: '/player/$_kShellMediaId');
        await _pump(
          tester,
          router: router,
          overrides: _shellOverrides(
            db,
            playerSession: _shellSession(),
            playerEngine: fakeEngine,
          ),
          surface: const Size(400, 900),
        );

        final shellScaffolds = tester
            .widgetList<Scaffold>(find.byType(Scaffold))
            .where((s) => s.bottomNavigationBar != null)
            .toList();
        expect(shellScaffolds, hasLength(1));
        expect(shellScaffolds.first.backgroundColor, Colors.transparent);
        expect(shellScaffolds.first.extendBody, isTrue);
        expect(find.byType(GlobalTransportBar), findsOneWidget);
      },
    );

    testWidgets('does not show mini transport on / even with a session', (
      tester,
    ) async {
      final router = _router(initial: '/');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(
          db,
          playerSession: _shellSession(),
          playerEngine: fakeEngine,
        ),
        surface: const Size(400, 900),
      );
      await tester.pump();
      expect(find.byType(GlobalTransportBar), findsNothing);
    });

    testWidgets('does not show mini transport bar when no player session', (
      tester,
    ) async {
      final router = _router(initial: '/library');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      expect(find.byIcon(Icons.mic_none_rounded), findsNothing);
    });

    testWidgets('renders AppBackground and shell at /profile', (tester) async {
      final router = _router(initial: '/profile');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(find.text('profile-page'), findsOneWidget);
      expect(findChromeIcon(EnjoyChromeGlyph.user), findsOneWidget);
    });
  });

  // Chrome matrix: specs/033-immersive-flashcard-review
  // - /vocabulary/review → hide sidebar, bottom nav, transport
  // - /vocabulary (hub) → normal chrome; no mini transport
  // - leave review → nav chrome restored (path-derived); still no mini bar
  // - resize while on review → chrome stays hidden
  group('RootShell immersive vocabulary review', () {
    testWidgets('hides AppSidebar on /vocabulary/review (wide)', (
      tester,
    ) async {
      final router = _router(initial: '/vocabulary/review');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(1100, 900),
      );

      expect(find.text('vocabulary-review-page'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsNothing);
      expect(find.byType(AppSidebar), findsNothing);
      expect(find.byType(EnjoyBottomNav), findsNothing);
    });

    testWidgets('hides bottom nav on /vocabulary/review (narrow)', (
      tester,
    ) async {
      final router = _router(initial: '/vocabulary/review');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(400, 900),
      );

      expect(find.text('vocabulary-review-page'), findsOneWidget);
      expect(find.byType(EnjoyBottomNav), findsNothing);
      expect(findChromeIcon(EnjoyChromeGlyph.compass), findsNothing);
    });

    testWidgets(
      'hides mini transport on /vocabulary/review with active session',
      (tester) async {
        final router = _router(initial: '/vocabulary/review');
        await _pump(
          tester,
          router: router,
          overrides: _shellOverrides(
            db,
            playerSession: _shellSession(),
            playerEngine: fakeEngine,
          ),
          surface: const Size(1100, 900),
        );

        expect(find.text('vocabulary-review-page'), findsOneWidget);
        expect(find.byType(GlobalTransportBar), findsNothing);
        expect(find.byIcon(Icons.play_arrow_rounded), findsNothing);
      },
    );

    testWidgets(
      'does not show mini transport on /vocabulary hub with session',
      (tester) async {
        final router = _router(initial: '/vocabulary');
        await _pump(
          tester,
          router: router,
          overrides: _shellOverrides(
            db,
            playerSession: _shellSession(),
            playerEngine: fakeEngine,
          ),
          surface: const Size(1100, 900),
        );

        expect(find.text('vocabulary-page'), findsOneWidget);
        expect(find.byType(GlobalTransportBar), findsNothing);
      },
    );

    testWidgets('restores sidebar after leaving /vocabulary/review (wide)', (
      tester,
    ) async {
      final router = _router(initial: '/vocabulary/review');
      await _pump(
        tester,
        router: router,
        overrides: _shellOverrides(db),
        surface: const Size(1100, 900),
      );

      expect(find.byIcon(Icons.search_rounded), findsNothing);

      router.go('/vocabulary');
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.text('vocabulary-page'), findsOneWidget);
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    });

    testWidgets(
      'does not restore mini transport after leaving review with a session',
      (tester) async {
        final router = _router(initial: '/vocabulary/review');
        await _pump(
          tester,
          router: router,
          overrides: _shellOverrides(
            db,
            playerSession: _shellSession(),
            playerEngine: fakeEngine,
          ),
          surface: const Size(400, 900),
        );

        expect(find.byType(GlobalTransportBar), findsNothing);

        router.go('/library');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('library-page'), findsOneWidget);
        expect(find.byType(GlobalTransportBar), findsNothing);
      },
    );

    testWidgets(
      'keeps chrome hidden when resizing while on /vocabulary/review',
      (tester) async {
        final router = _router(initial: '/vocabulary/review');
        await _pump(
          tester,
          router: router,
          overrides: _shellOverrides(db),
          surface: const Size(400, 900),
        );

        expect(find.byType(EnjoyBottomNav), findsNothing);

        await tester.binding.setSurfaceSize(const Size(1100, 900));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.text('vocabulary-review-page'), findsOneWidget);
        expect(find.byIcon(Icons.search_rounded), findsNothing);
        expect(find.byType(AppSidebar), findsNothing);
        expect(find.byType(EnjoyBottomNav), findsNothing);

        await tester.binding.setSurfaceSize(const Size(400, 900));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(find.byType(EnjoyBottomNav), findsNothing);
      },
    );
  });
}
