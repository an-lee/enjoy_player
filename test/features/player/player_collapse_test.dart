import 'package:enjoy_player/core/window/window_fullscreen_provider.dart';
import 'package:enjoy_player/features/player/application/player_collapse.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

class _RecordingFullscreen extends WindowFullscreen {
  var setFullscreenCalled = false;

  @override
  bool build() => true;

  @override
  Future<void> setFullscreen(bool value) async {
    setFullscreenCalled = true;
    state = value;
  }
}

PlaybackSession _session() {
  final now = DateTime.utc(2026, 1, 1);
  return PlaybackSession(
    mediaId: 'test-media',
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

  @override
  void abandonPendingOpen() {}
}

class _EmptyVocabSession extends VocabularyReviewSession {
  @override
  ReviewSessionState build() => const ReviewSessionState(queue: []);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'collapseExpandedPlayer exits fullscreen, clears session, pops route',
    (tester) async {
      final fullscreen = _RecordingFullscreen();
      late ProviderContainer container;

      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Consumer(
              builder: (context, ref, _) {
                return ElevatedButton(
                  onPressed: () => context.push('/player/test-media'),
                  child: const Text('open'),
                );
              },
            ),
          ),
          GoRoute(
            path: '/player/:mediaId',
            builder: (context, state) {
              return Consumer(
                builder: (context, ref, _) {
                  container = ProviderScope.containerOf(context);
                  return Scaffold(
                    body: ElevatedButton(
                      onPressed: () => collapseExpandedPlayer(ref, context),
                      child: const Text('collapse'),
                    ),
                  );
                },
              );
            },
          ),
        ],
      );

      addTearDown(router.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            windowFullscreenProvider.overrideWith(() => fullscreen),
            playerControllerProvider.overrideWith(
              () => _SessionPlayerController(_session()),
            ),
            vocabularyReviewSessionProvider.overrideWith(
              _EmptyVocabSession.new,
            ),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      expect(router.state.uri.path, '/player/test-media');

      expect(container.read(playerControllerProvider), isNotNull);

      await tester.tap(find.text('collapse'));
      await tester.pumpAndSettle();

      expect(fullscreen.setFullscreenCalled, isTrue);
      expect(container.read(playerControllerProvider), isNull);
      expect(router.state.uri.path, '/');
    },
  );
}
