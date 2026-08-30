/// Echo / shadow-reading region state (maps web `player-echo-store`).
library;

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/domain/echo_window.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'echo_mode_provider.g.dart';

class EchoState {
  const EchoState({
    required this.active,
    required this.startLineIndex,
    required this.endLineIndex,
    required this.startTimeSeconds,
    required this.endTimeSeconds,
  });

  final bool active;
  final int startLineIndex;
  final int endLineIndex;
  final double startTimeSeconds;
  final double endTimeSeconds;

  static const inactive = EchoState(
    active: false,
    startLineIndex: -1,
    endLineIndex: -1,
    startTimeSeconds: -1,
    endTimeSeconds: -1,
  );

  EchoState copyWith({
    bool? active,
    int? startLineIndex,
    int? endLineIndex,
    double? startTimeSeconds,
    double? endTimeSeconds,
  }) {
    return EchoState(
      active: active ?? this.active,
      startLineIndex: startLineIndex ?? this.startLineIndex,
      endLineIndex: endLineIndex ?? this.endLineIndex,
      startTimeSeconds: startTimeSeconds ?? this.startTimeSeconds,
      endTimeSeconds: endTimeSeconds ?? this.endTimeSeconds,
    );
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is EchoState &&
          other.active == active &&
          other.startLineIndex == startLineIndex &&
          other.endLineIndex == endLineIndex &&
          other.startTimeSeconds == startTimeSeconds &&
          other.endTimeSeconds == endTimeSeconds;

  @override
  int get hashCode => Object.hash(
    active,
    startLineIndex,
    endLineIndex,
    startTimeSeconds,
    endTimeSeconds,
  );
}

@Riverpod(keepAlive: true)
class EchoMode extends _$EchoMode {
  @override
  EchoState build() => EchoState.inactive;

  void activate({
    required int startLineIndex,
    required int endLineIndex,
    required double startTimeSeconds,
    required double endTimeSeconds,
  }) {
    state = EchoState(
      active: true,
      startLineIndex: startLineIndex,
      endLineIndex: endLineIndex,
      startTimeSeconds: startTimeSeconds,
      endTimeSeconds: endTimeSeconds,
    );
  }

  void deactivate() {
    state = EchoState.inactive;
  }

  void restoreFromSession({
    required int startLine,
    required int endLine,
    required int echoStartMs,
    required int echoEndMs,
  }) {
    state = EchoState(
      active: true,
      startLineIndex: startLine,
      endLineIndex: endLine,
      startTimeSeconds: secondsFromMs(echoStartMs),
      endTimeSeconds: secondsFromMs(echoEndMs),
    );
  }

  /// Whether the persisted line indices still fit [lines].
  ///
  /// [restoreFromSession] persists indices without validation, so a transcript
  /// re-import that re-segmented the cues shorter leaves them past the end.
  /// Mirror [EchoEnforcer]'s line-index bounds check and no-op instead of
  /// throwing RangeError (issue #659).
  bool _indicesFitLines(List<TranscriptLine> lines) {
    final start = state.startLineIndex;
    final end = state.endLineIndex;
    return start >= 0 && end >= start && end < lines.length;
  }

  /// Add one line before the echo segment (web expand backward).
  void expandEchoBackward(List<TranscriptLine> lines) {
    if (!state.active || !_indicesFitLines(lines)) return;
    final start = state.startLineIndex;
    if (start <= 0) return;
    final nextStart = start - 1;
    state = state.copyWith(
      startLineIndex: nextStart,
      startTimeSeconds: lines[nextStart].startSeconds,
    );
  }

  /// Remove one line from the start of the echo segment (web shrink backward).
  void shrinkEchoBackward(List<TranscriptLine> lines) {
    if (!state.active || !_indicesFitLines(lines)) return;
    final start = state.startLineIndex;
    final end = state.endLineIndex;
    if (start >= end) return;
    final nextStart = start + 1;
    state = state.copyWith(
      startLineIndex: nextStart,
      startTimeSeconds: lines[nextStart].startSeconds,
    );
  }

  /// Add one line after the echo segment (web expand forward).
  void expandEchoForward(List<TranscriptLine> lines) {
    if (!state.active || !_indicesFitLines(lines)) return;
    final end = state.endLineIndex;
    if (end >= lines.length - 1) return;
    final nextEnd = end + 1;
    state = state.copyWith(
      endLineIndex: nextEnd,
      endTimeSeconds: lines[nextEnd].endSeconds,
    );
  }

  /// Remove one line from the end of the echo segment (web shrink forward).
  void shrinkEchoForward(List<TranscriptLine> lines) {
    if (!state.active || !_indicesFitLines(lines)) return;
    final start = state.startLineIndex;
    final end = state.endLineIndex;
    if (end <= start) return;
    final nextEnd = end - 1;
    state = state.copyWith(
      endLineIndex: nextEnd,
      endTimeSeconds: lines[nextEnd].endSeconds,
    );
  }
}
