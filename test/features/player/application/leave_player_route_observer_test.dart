// Leave-player teardown is route-driven: [LeavePlayerRouteObserver] reports the
// transition and `clearLivePlaybackSession` applies the policy. These tests pin
// both the "fires exactly once per leave" contract and the wiring shape used in
// `app_router.dart` (observer on the shell navigator + page named after its
// matched location).
import 'dart:async';

import 'package:enjoy_player/features/player/application/leave_player_route_observer.dart';
import 'package:enjoy_player/features/player/application/leave_player_session.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

PlaybackSession _session() {
  final now = DateTime.utc(2026, 1, 1);
  return PlaybackSession(
    mediaId: 'm1',
    dexieTargetType: 'Audio',
    mediaType: 'audio',
    mediaTitle: 't',
    durationSeconds: 10,
    currentTimeSeconds: 1,
    currentSegmentIndex: 0,
    language: 'en',
    startedAt: now,
    lastActiveAt: now,
  );
}

class _RecordingPlayerController extends PlayerController {
  _RecordingPlayerController(this._session);

  PlaybackSession? _session;
  var clearCalls = 0;

  @override
  PlaybackSession? build() => _session;

  @override
  Future<void> clear({bool keepVideoSurface = false}) async {
    clearCalls++;
    _session = null;
    state = null;
  }
}

class _EmptyVocabSession extends VocabularyReviewSession {
  @override
  ReviewSessionState build() => const ReviewSessionState(queue: []);
}

/// Entry point that runs the `Ref`-based teardown with a real [Ref]. The
/// provider hands out a closure so the clear never runs during a provider's
/// initialization.
final _clearLiveSessionProbe = Provider<Future<void> Function()>(
  (ref) =>
      () => clearLivePlaybackSession(ref),
);

GoRouter _router(LeavePlayerRouteObserver observer) {
  return GoRouter(
    initialLocation: '/',
    routes: [
      ShellRoute(
        builder: (context, state, child) => child,
        observers: [observer],
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home-page')),
          ),
          GoRoute(
            path: '/library',
            builder: (_, _) => const Scaffold(body: Text('library-page')),
          ),
          GoRoute(
            path: '/player/:mediaId',
            pageBuilder: (context, state) => CustomTransitionPage<void>(
              key: const ValueKey('player-page'),
              // Mirrors `app_router.dart`: the page name is what
              // [isPlayerRoute] matches on.
              name: state.matchedLocation,
              transitionsBuilder: (_, _, _, child) => child,
              child: const Scaffold(body: Text('player-page')),
            ),
          ),
        ],
      ),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('isPlayerRoute', () {
    test('matches a route named after a player location', () {
      final route = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/player/m1'),
        builder: (_) => const SizedBox.shrink(),
      );
      expect(isPlayerRoute(route), isTrue);
    });

    test('ignores other routes and unnamed routes', () {
      final named = MaterialPageRoute<void>(
        settings: const RouteSettings(name: '/library'),
        builder: (_) => const SizedBox.shrink(),
      );
      final unnamed = MaterialPageRoute<void>(
        builder: (_) => const SizedBox.shrink(),
      );
      expect(isPlayerRoute(named), isFalse);
      expect(isPlayerRoute(unnamed), isFalse);
    });
  });

  group('LeavePlayerRouteObserver', () {
    testWidgets('clears the live session once when leaving /player/', (
      tester,
    ) async {
      final controller = _RecordingPlayerController(_session());
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(() => controller),
          vocabularyReviewSessionProvider.overrideWith(_EmptyVocabSession.new),
        ],
      );
      addTearDown(container.dispose);

      var leftCount = 0;
      final observer = LeavePlayerRouteObserver(
        onLeftPlayerRoute: () {
          leftCount++;
          scheduleMicrotask(() {
            unawaited(container.read(_clearLiveSessionProbe)());
          });
        },
      );
      final router = _router(observer);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('home-page'), findsOneWidget);
      expect(controller.clearCalls, 0);
      expect(observer.isHostingPlayerRoute, isFalse);

      router.go('/player/m1');
      await tester.pumpAndSettle();
      expect(find.text('player-page'), findsOneWidget);
      expect(observer.isHostingPlayerRoute, isTrue);
      // Entering the player is not a leave.
      expect(controller.clearCalls, 0);

      router.go('/library');
      await tester.pumpAndSettle();
      expect(find.text('library-page'), findsOneWidget);
      expect(controller.clearCalls, 1);
      expect(leftCount, 1);

      // Still off the player route: no repeated teardown.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      expect(controller.clearCalls, 1);
      expect(leftCount, 1);
    });

    testWidgets('re-arms after re-entering the player', (tester) async {
      final controller = _RecordingPlayerController(_session());
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(() => controller),
          vocabularyReviewSessionProvider.overrideWith(_EmptyVocabSession.new),
        ],
      );
      addTearDown(container.dispose);

      final observer = LeavePlayerRouteObserver(onLeftPlayerRoute: () {});
      final router = _router(observer);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/player/m1');
      await tester.pumpAndSettle();
      expect(observer.isHostingPlayerRoute, isTrue);

      router.go('/library');
      await tester.pumpAndSettle();
      expect(observer.isHostingPlayerRoute, isFalse);

      router.go('/player/m1');
      await tester.pumpAndSettle();
      expect(observer.isHostingPlayerRoute, isTrue);

      router.go('/library');
      await tester.pumpAndSettle();
      expect(observer.isHostingPlayerRoute, isFalse);
    });

    testWidgets('stays put while moving between /player routes', (
      tester,
    ) async {
      final controller = _RecordingPlayerController(_session());
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(() => controller),
          vocabularyReviewSessionProvider.overrideWith(_EmptyVocabSession.new),
        ],
      );
      addTearDown(container.dispose);

      var leftCount = 0;
      final observer = LeavePlayerRouteObserver(
        onLeftPlayerRoute: () => leftCount++,
      );
      final router = _router(observer);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      router.go('/player/m1');
      await tester.pumpAndSettle();
      router.go('/player/m2');
      await tester.pumpAndSettle();
      expect(find.text('player-page'), findsOneWidget);
      expect(observer.isHostingPlayerRoute, isTrue);
      expect(leftCount, 0);
      expect(controller.clearCalls, 0);
    });

    testWidgets('fires for a pop back off the player route', (tester) async {
      final controller = _RecordingPlayerController(_session());
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(() => controller),
          vocabularyReviewSessionProvider.overrideWith(_EmptyVocabSession.new),
        ],
      );
      addTearDown(container.dispose);

      final observer = LeavePlayerRouteObserver(
        onLeftPlayerRoute: () => scheduleMicrotask(() {
          unawaited(container.read(_clearLiveSessionProbe)());
        }),
      );
      final router = _router(observer);
      addTearDown(router.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(router.push('/player/m1'));
      await tester.pumpAndSettle();
      expect(find.text('player-page'), findsOneWidget);
      expect(controller.clearCalls, 0);

      router.pop();
      await tester.pumpAndSettle();
      expect(find.text('home-page'), findsOneWidget);
      expect(controller.clearCalls, 1);
    });
  });

  group('clearLivePlaybackSession (Ref variant)', () {
    testWidgets('clears an off-route live session', (tester) async {
      final controller = _RecordingPlayerController(_session());
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(() => controller),
          vocabularyReviewSessionProvider.overrideWith(_EmptyVocabSession.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(_clearLiveSessionProbe)();
      expect(controller.clearCalls, 1);
    });

    testWidgets('skips a cleared session', (tester) async {
      final controller = _RecordingPlayerController(null);
      final container = ProviderContainer(
        overrides: [
          playerControllerProvider.overrideWith(() => controller),
          vocabularyReviewSessionProvider.overrideWith(_EmptyVocabSession.new),
        ],
      );
      addTearDown(container.dispose);

      await container.read(_clearLiveSessionProbe)();
      expect(controller.clearCalls, 0);
    });
  });
}
