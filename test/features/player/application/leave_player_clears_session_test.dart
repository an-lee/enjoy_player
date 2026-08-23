import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/player/application/leave_player_session.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_review_practice.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

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

class _FakeVocabSession extends VocabularyReviewSession {
  _FakeVocabSession(this._initial);
  final ReviewSessionState _initial;

  @override
  ReviewSessionState build() => _initial;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('shouldClearLiveSessionOnRouteChange', () {
    test('clears off player with a live session', () {
      expect(
        shouldClearLiveSessionOnRouteChange(
          onPlayerRoute: false,
          hasLiveSession: true,
          practiceOwnsVideoStage: false,
        ),
        isTrue,
      );
    });

    test('does not clear on the player route', () {
      expect(
        shouldClearLiveSessionOnRouteChange(
          onPlayerRoute: true,
          hasLiveSession: true,
          practiceOwnsVideoStage: false,
        ),
        isFalse,
      );
    });

    test('skips clear when vocabulary clip owns the stage', () {
      expect(
        shouldClearLiveSessionOnRouteChange(
          onPlayerRoute: false,
          hasLiveSession: true,
          practiceOwnsVideoStage: true,
        ),
        isFalse,
      );
    });
  });

  group('clearLivePlaybackSessionIfNeeded', () {
    testWidgets('calls clear when leaving the player', (tester) async {
      final controller = _RecordingPlayerController(_session());
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerControllerProvider.overrideWith(() => controller),
            vocabularyReviewSessionProvider.overrideWith(
              () => _FakeVocabSession(const ReviewSessionState(queue: [])),
            ),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                widgetRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await clearLivePlaybackSessionIfNeeded(widgetRef, onPlayerRoute: false);
      expect(controller.clearCalls, 1);
    });

    testWidgets('does not clear when practice owns video stage', (
      tester,
    ) async {
      final controller = _RecordingPlayerController(_session());
      late WidgetRef widgetRef;
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            playerControllerProvider.overrideWith(() => controller),
            vocabularyReviewSessionProvider.overrideWith(
              () => _FakeVocabSession(
                const ReviewSessionState(
                  queue: [],
                  practicePhase: ReviewPracticePhase.clipReady,
                ),
              ),
            ),
          ],
          child: MaterialApp(
            theme: ThemeData(
              extensions: [
                EnjoyThemeTokens.build(
                  ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF)),
                ),
              ],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Consumer(
              builder: (context, ref, _) {
                widgetRef = ref;
                return const SizedBox.shrink();
              },
            ),
          ),
        ),
      );

      await clearLivePlaybackSessionIfNeeded(widgetRef, onPlayerRoute: false);
      expect(controller.clearCalls, 0);
    });
  });
}
