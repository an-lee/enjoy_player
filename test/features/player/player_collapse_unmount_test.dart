// Regression test: the collapse (back) control lives inside the player chrome
// body. clear() nulls the session mid-flight, which rebuilds the player page
// from the chrome body into the loading placeholder and unmounts the control's
// context. The route pop must not depend on that context surviving the
// teardown awaits — otherwise the learner is stranded on the placeholder
// (only the system back gesture could leave, since the route never popped).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/window/window_fullscreen_provider.dart';
import 'package:enjoy_player/features/player/application/player_collapse.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';

class _RecordingFullscreen extends WindowFullscreen {
  var setFullscreenCalled = false;

  @override
  bool build() => false;

  @override
  Future<void> setFullscreen(bool value) async {
    setFullscreenCalled = true;
    state = value;
  }
}

PlaybackSession _session() {
  final now = DateTime.utc(2026, 1, 1);
  return PlaybackSession(
    mediaId: 'unmount-media',
    dexieTargetType: 'Video',
    mediaType: 'video',
    mediaTitle: 't',
    durationSeconds: 10,
    currentTimeSeconds: 1,
    currentSegmentIndex: 0,
    language: 'en',
    startedAt: now,
    lastActiveAt: now,
  );
}

/// Mirrors ExpandedPlayerScreen: chrome body (with the collapse control)
/// while a session exists, loading placeholder once clear() nulls it.
class _PlayerPage extends ConsumerWidget {
  const _PlayerPage();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hasSession = ref.watch(
      playerControllerProvider.select((s) => s != null),
    );
    if (!hasSession) {
      return const Scaffold(body: Center(child: Text('player-placeholder')));
    }
    return Scaffold(
      body: Center(
        child: Builder(
          builder: (buttonCtx) => TextButton(
            // Same shape as PlayerCollapseControl: context captured from inside
            // the chrome body subtree that unmounts on session clear.
            onPressed: () => collapseExpandedPlayer(ref, buttonCtx),
            child: const Text('collapse'),
          ),
        ),
      ),
    );
  }
}

class _EmptyVocabSession extends VocabularyReviewSession {
  @override
  ReviewSessionState build() => const ReviewSessionState(queue: []);
}

/// clear() suspends on a real async boundary (position tracker cancel, drift
/// flush, engine stop) so a frame can interleave and unmount the button —
/// like the real controller on device.
class _SlowClearPlayerController extends PlayerController {
  _SlowClearPlayerController(this._session);
  PlaybackSession? _session;

  @override
  PlaybackSession? build() => _session;

  @override
  Future<void> clear({bool keepVideoSurface = false}) async {
    await Future<void>.delayed(const Duration(milliseconds: 50));
    _session = null;
    state = null;
    await Future<void>.delayed(const Duration(milliseconds: 50));
  }

  @override
  void abandonPendingOpen() {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'collapse pops the route even when the chrome body unmounts mid-clear',
    (tester) async {
      final fullscreen = _RecordingFullscreen();
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(body: Text('home')),
          ),
          GoRoute(
            path: '/player/:mediaId',
            builder: (_, _) => const _PlayerPage(),
          ),
        ],
      );
      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            windowFullscreenProvider.overrideWith(() => fullscreen),
            playerControllerProvider.overrideWith(
              () => _SlowClearPlayerController(_session()),
            ),
            vocabularyReviewSessionProvider.overrideWith(
              _EmptyVocabSession.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      unawaited(router.push('/player/unmount-media'));
      await tester.pumpAndSettle();
      expect(find.text('collapse'), findsOneWidget);

      await tester.tap(find.text('collapse'));
      // Let the interleaved frames run through the slow clear.
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));
      await tester.pump(const Duration(milliseconds: 16));

      // The chrome body swapped to the placeholder mid-clear…
      expect(find.text('player-placeholder'), findsOneWidget);
      // …but the route must still have popped back home.
      expect(
        router.state.uri.path,
        '/',
        reason:
            'collapseExpandedPlayer skipped its pop because the calling '
            'context unmounted while clear() was in flight — the learner is '
            'stranded on the loading placeholder.',
      );
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/');
    },
  );
}
