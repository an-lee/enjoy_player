// Regression test for the player-exit UI freeze.
//
// A floating AppNotice alive across a player-route exit used to trip the
// "Floating SnackBar presented off screen" layout assert on the shell
// Scaffold: EnjoyBottomNav expanded to the full screen height inside the
// bottomNavigationBar slot, so the scaffold's contentBottom collapsed to 0
// and any floating SnackBar was un-fittable. The thrown assert aborts the
// frame before paint, and with the exit transition + loading skeleton
// rescheduling frames the UI froze on the player page (black 16:9 stage).
//
// This exercises the real RootShell: enter /player/:id with a live session,
// show a notice, then exit (clear() then pop()) — no snackbar layout error.
library;

import 'dart:async';

import 'package:drift/native.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_state_providers.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/root_shell.dart';
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
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import '../../../support/fake_player_engine.dart';

const _kMediaId = 'exit-freeze-media';

PlaybackSession _session() {
  final now = DateTime(2026, 1, 1);
  return PlaybackSession(
    mediaId: _kMediaId,
    dexieTargetType: 'Video',
    mediaType: 'video',
    mediaTitle: 'Exit freeze probe',
    durationSeconds: 120,
    currentTimeSeconds: 0,
    currentSegmentIndex: 0,
    language: 'en',
    startedAt: now,
    lastActiveAt: now,
  );
}

class _FakeVocabSession extends VocabularyReviewSession {
  @override
  ReviewSessionState build() => const ReviewSessionState(queue: []);
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

class _HomeWithNoticeButton extends StatelessWidget {
  const _HomeWithNoticeButton();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (inner) => TextButton(
            onPressed: () => AppNotice.success(inner, 'exit probe notice'),
            child: const Text('show-notice'),
          ),
        ),
      ),
    );
  }
}

/// Mirrors [collapseExpandedPlayer] ordering: clear() (which nulls the
/// session) then pop() — the window where the shell flips scaffold variants
/// while the notice snackbar is still alive.
class _PlayerPageWithExit extends ConsumerWidget {
  const _PlayerPageWithExit();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (inner) => TextButton(
            onPressed: () async {
              await ref.read(playerControllerProvider.notifier).clear();
              if (inner.mounted) inner.pop();
            },
            child: const Text('exit-player'),
          ),
        ),
      ),
    );
  }
}

GoRouter _router() {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => RootShell(child: child),
        routes: [
          GoRoute(path: '/', builder: (_, _) => const _HomeWithNoticeButton()),
          GoRoute(
            path: '/player/:mediaId',
            builder: (_, _) => const _PlayerPageWithExit(),
          ),
        ],
      ),
    ],
  );
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

  Future<void> pumpShell(
    WidgetTester tester, {
    required GoRouter router,
    required List<Override> overrides,
  }) async {
    // Consistent view metrics (logical 392.7x850.9 @ dpr 3, gesture-inset
    // bottom) — a mismatched setSurfaceSize desyncs MediaQuery.fromView.
    tester.view.physicalSize = const Size(392.7 * 3, 850.9 * 3);
    tester.view.devicePixelRatio = 3;
    tester.view.padding = const FakeViewPadding(
      left: 0,
      top: 72,
      right: 0,
      bottom: 102,
    );
    tester.view.viewPadding = const FakeViewPadding(
      left: 0,
      top: 72,
      right: 0,
      bottom: 102,
    );
    addTearDown(tester.view.reset);

    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides,
        child: MaterialApp.router(
          scaffoldMessengerKey: appScaffoldMessengerKey,
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

  testWidgets(
    'notice alive across player exit never trips the floating snackbar assert',
    (tester) async {
      final errors = <FlutterErrorDetails>[];
      final original = FlutterError.onError;
      FlutterError.onError = errors.add;
      addTearDown(() => FlutterError.onError = original);

      final session = _session();
      final overrides = <Override>[
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
        playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
        playerControllerProvider.overrideWith(
          () => _SessionPlayerController(session),
        ),
        transcriptHasLinesForMediaProvider(
          session.mediaId,
        ).overrideWith((ref) => Stream.value(false)),
        playerIsPlayingProvider.overrideWith((ref) => Stream.value(false)),
        playerIsBufferingProvider.overrideWith((ref) => Stream.value(false)),
        allTranscriptsForMediaProvider(
          session.mediaId,
        ).overrideWith((ref) => Stream.value(const <TranscriptTrack>[])),
        transcriptFetchCtrlProvider(session.mediaId).overrideWithValue(
          const TranscriptFetchUiState(status: TranscriptFetchStatus.idle),
        ),
        transcriptBlurModeProvider.overrideWith(_BlurModeOff.new),
      ];

      final router = _router();
      addTearDown(router.dispose);
      await pumpShell(tester, router: router, overrides: overrides);

      // A notice is shown on the home shell and stays alive (3s duration).
      await tester.tap(find.text('show-notice'));
      await tester.pump(); // notice post-frame callback
      await tester.pump(const Duration(milliseconds: 250)); // entrance

      // Enter the player, then exit while the notice is still presented.
      unawaited(router.push('/player/$_kMediaId'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('exit-player'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300)); // reverse fade

      final offScreen = errors.where(
        (e) => '${e.exception}'.contains('Floating SnackBar'),
      );
      expect(
        offScreen,
        isEmpty,
        reason:
            'A floating notice must stay fittable while the shell flips '
            'scaffold variants during player exit; the layout assert aborts '
            'frames in debug and freezes the screen.',
      );
      expect(tester.takeException(), isNull);
      expect(find.text('exit probe notice'), findsOneWidget);

      // The notice must also be on screen, not just error-free.
      final box = tester.renderObject<RenderBox>(find.byType(SnackBar));
      expect(box.localToGlobal(Offset.zero).dy, greaterThanOrEqualTo(0));
      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    },
  );
}
