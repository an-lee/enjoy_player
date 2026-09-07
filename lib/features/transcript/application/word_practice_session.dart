/// Ephemeral chosen-word and word-loop state for one open media.
library;

import 'package:enjoy_player/core/analytics/analytics.dart';
import 'package:enjoy_player/core/analytics/analytics_events.dart';
import 'package:enjoy_player/core/analytics/analytics_provider.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/features/settings/application/ipa_overlay_settings.dart';

part 'word_practice_session.g.dart';

@immutable
class WordPracticeState {
  const WordPracticeState({
    this.chosenLineIndex,
    this.chosenWordIndex,
    this.loopLineIndex,
    this.loopWordIndex,
    this.loopStartMs,
    this.loopEndMs,
  });

  final int? chosenLineIndex;
  final int? chosenWordIndex;
  final int? loopLineIndex;
  final int? loopWordIndex;
  final int? loopStartMs;
  final int? loopEndMs;

  bool get isLooping =>
      loopStartMs != null && loopEndMs != null && loopEndMs! > loopStartMs!;

  WordPracticeState copyWith({
    int? chosenLineIndex,
    int? chosenWordIndex,
    int? loopLineIndex,
    int? loopWordIndex,
    int? loopStartMs,
    int? loopEndMs,
    bool clearChosen = false,
    bool clearLoop = false,
  }) {
    return WordPracticeState(
      chosenLineIndex: clearChosen
          ? null
          : (chosenLineIndex ?? this.chosenLineIndex),
      chosenWordIndex: clearChosen
          ? null
          : (chosenWordIndex ?? this.chosenWordIndex),
      loopLineIndex: clearLoop ? null : (loopLineIndex ?? this.loopLineIndex),
      loopWordIndex: clearLoop ? null : (loopWordIndex ?? this.loopWordIndex),
      loopStartMs: clearLoop ? null : (loopStartMs ?? this.loopStartMs),
      loopEndMs: clearLoop ? null : (loopEndMs ?? this.loopEndMs),
    );
  }
}

@Riverpod(keepAlive: true)
class WordPracticeSession extends _$WordPracticeSession {
  /// When the current loop window was opened — for practice duration.
  DateTime? _loopStartedAt;

  Analytics get _analytics => ref.read(analyticsProvider);

  @override
  WordPracticeState build(String mediaId) {
    ref.listen(ipaOverlaySettingsProvider, (prev, next) {
      if (next.value != true) {
        state = const WordPracticeState();
      }
    });
    return const WordPracticeState();
  }

  void chooseWord({required int lineIndex, required int wordIndex}) {
    state = state.copyWith(
      chosenLineIndex: lineIndex,
      chosenWordIndex: wordIndex,
    );
  }

  void startLoop({
    required int lineIndex,
    required int wordIndex,
    required int startMs,
    required int endMs,
  }) {
    if (endMs <= startMs) return;
    _loopStartedAt = DateTime.now();
    _analytics.capture(
      AnalyticsEvents.practiceSessionStarted,
      properties: AnalyticsEvents.practiceStarted(
        surface: AnalyticsEvents.surfaceWordPractice,
        itemCount: 1,
      ),
    );
    state = state.copyWith(
      chosenLineIndex: lineIndex,
      chosenWordIndex: wordIndex,
      loopLineIndex: lineIndex,
      loopWordIndex: wordIndex,
      loopStartMs: startMs,
      loopEndMs: endMs,
    );
  }

  void clearLoop() {
    _captureIfLoopActive();
    state = state.copyWith(clearLoop: true);
  }

  void clearAll() {
    _captureIfLoopActive();
    state = const WordPracticeState();
  }

  /// Emits the loop-practice completion when a loop window is actually open.
  void _captureIfLoopActive() {
    final startedAt = _loopStartedAt;
    if (startedAt == null) return;
    _loopStartedAt = null;
    _analytics.capture(
      AnalyticsEvents.practiceSessionCompleted,
      properties: AnalyticsEvents.practiceCompleted(
        surface: AnalyticsEvents.surfaceWordPractice,
        durationSeconds: DateTime.now().difference(startedAt).inSeconds,
        itemsCompleted: 1,
      ),
    );
  }
}
