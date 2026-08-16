/// Ephemeral chosen-word and word-loop state for one open media.
library;

import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/features/settings/application/word_practice_settings.dart';

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
  @override
  WordPracticeState build(String mediaId) {
    ref.listen(wordPracticeSettingsProvider, (prev, next) {
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
    state = state.copyWith(clearLoop: true);
  }

  void clearAll() {
    state = const WordPracticeState();
  }
}
