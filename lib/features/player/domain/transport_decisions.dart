/// Pure-function transport decisions — extracted from the player controller,
/// interactions, and YouTube engine so every decision path can be unit-tested
/// in isolation.
///
/// Pattern: `decideX(inputs) -> sealed class` reducers. Side effects are left
/// to the single imperative consumer that `switch`es over the sealed result.
///
/// The exceptions are D8 (immediate-pause retry) and D9 (transport-toggle
/// latch): they are the restless half of the play-then-pause saga and read
/// live protocol state, so they moved into
/// `youtube_play_retry_policy.dart` next to the budget they decide about
/// (issue #665). Everything stateless stays here.
library;

import 'player_settings.dart';

// ---------------------------------------------------------------------------
// D1 — seek routing (echo-aware vs direct)
// ---------------------------------------------------------------------------

sealed class SeekRoutingDecision {
  const SeekRoutingDecision();

  static const SeekRoutingDecision throughEcho = SeekThroughEcho();
  static const SeekRoutingDecision direct = SeekDirect();
}

final class SeekThroughEcho extends SeekRoutingDecision {
  const SeekThroughEcho();
}

final class SeekDirect extends SeekRoutingDecision {
  const SeekDirect();
}

/// When echo is active, seeks should pass through the single-flight
/// [EchoEnforcer] so a user seek cannot interleave with a reactive per-tick
/// enforcement (no double-seek).
SeekRoutingDecision decideSeekRouting({required bool echoActive}) {
  if (echoActive) return SeekRoutingDecision.throughEcho;
  return SeekRoutingDecision.direct;
}

// ---------------------------------------------------------------------------
// D3 — replay target (echo start vs active-line start)
// ---------------------------------------------------------------------------

sealed class ReplayTargetDecision {
  const ReplayTargetDecision();

  static ReplayTargetDecision echoStart(double timeSeconds) =>
      ReplayToEchoStart(timeSeconds);

  static ReplayTargetDecision lineStart(double timeSeconds) =>
      ReplayToLineStart(timeSeconds);
}

final class ReplayToEchoStart extends ReplayTargetDecision {
  const ReplayToEchoStart(this.timeSeconds);
  final double timeSeconds;
}

final class ReplayToLineStart extends ReplayTargetDecision {
  const ReplayToLineStart(this.timeSeconds);
  final double timeSeconds;
}

/// When echo is active, replay jumps to the echo window start; otherwise it
/// jumps to the start of the transcript line that contains the current time.
ReplayTargetDecision decideReplayTarget({
  required bool echoActive,
  required double echoStartTimeSeconds,
  required double activeLineStartSeconds,
}) {
  if (echoActive) {
    return ReplayTargetDecision.echoStart(echoStartTimeSeconds);
  }
  return ReplayTargetDecision.lineStart(activeLineStartSeconds);
}

// ---------------------------------------------------------------------------
// D4 — progress seek (fraction → target time)
// ---------------------------------------------------------------------------

sealed class ProgressSeekDecision {
  const ProgressSeekDecision();

  static ProgressSeekDecision valid(double timeSeconds) =>
      ProgressSeekValid(timeSeconds);

  static const ProgressSeekDecision invalid = ProgressSeekInvalid();
}

final class ProgressSeekValid extends ProgressSeekDecision {
  const ProgressSeekValid(this.timeSeconds);
  final double timeSeconds;
}

final class ProgressSeekInvalid extends ProgressSeekDecision {
  const ProgressSeekInvalid();
}

/// Convert a [0, 1] progress fraction and the current duration into a seek
/// target, or signal that the seek is impossible (no / zero duration).
ProgressSeekDecision decideProgressSeekTime({
  required double fraction,
  required double durationSeconds,
}) {
  if (durationSeconds <= 0) return ProgressSeekDecision.invalid;
  final clamped = fraction.clamp(0.0, 1.0);
  final target = (durationSeconds * clamped).clamp(0.0, durationSeconds);
  return ProgressSeekDecision.valid(target);
}

// ---------------------------------------------------------------------------
// D5 — YouTube play restart
// ---------------------------------------------------------------------------

sealed class YouTubePlayRestartDecision {
  const YouTubePlayRestartDecision();

  static const YouTubePlayRestartDecision restart = RestartFromBeginning();
  static const YouTubePlayRestartDecision resume = ResumePlayback();
}

final class RestartFromBeginning extends YouTubePlayRestartDecision {
  const RestartFromBeginning();
}

final class ResumePlayback extends YouTubePlayRestartDecision {
  const ResumePlayback();
}

/// When the video previously completed playback, a new [play] must reload the
/// watch page; otherwise a simple JS `play()` call is sufficient.
YouTubePlayRestartDecision decideYouTubePlayRestart({
  required bool playbackCompleted,
}) {
  if (playbackCompleted) return YouTubePlayRestartDecision.restart;
  return YouTubePlayRestartDecision.resume;
}

// ---------------------------------------------------------------------------
// D6 — YouTube poll-loop transport-state transition
// ---------------------------------------------------------------------------

sealed class PollTransitionDecision {
  const PollTransitionDecision();
}

/// Media just finished — mark completed, stop polling, emit not playing.
final class MediaJustEnded extends PollTransitionDecision {
  const MediaJustEnded();
}

/// JS says paused but client thinks playing — increment streak. When the
/// streak crosses the confirm threshold the pause is confirmed.
final class PauseStreaking extends PollTransitionDecision {
  const PauseStreaking({required this.confirmed, required this.newStreak});
  final bool confirmed;
  final int newStreak;
}

/// JS says playing and not ended — emit playing, reset streak, clear
/// buffering if set.
final class PollPlaying extends PollTransitionDecision {
  const PollPlaying();
}

/// No-op tick — reset streak but no state change.
final class PollIdleTick extends PollTransitionDecision {
  const PollIdleTick();
}

/// Reduce the raw JS poll result + current session into the next transport
/// transition. The consumer applies side effects (stop poll, emit state, etc.)
/// via a `switch` over the result.
PollTransitionDecision decidePollTransition({
  required bool jsEnded,
  required bool jsPaused,
  required bool playing,
  required int pausedPollStreak,
  required int pauseConfirmThreshold,
  required bool playbackCompleted,
}) {
  if (jsEnded && !playbackCompleted) {
    return const MediaJustEnded();
  }
  if (jsPaused && playing && !jsEnded) {
    final newStreak = pausedPollStreak + 1;
    final confirmed = newStreak >= pauseConfirmThreshold;
    return PauseStreaking(confirmed: confirmed, newStreak: newStreak);
  }
  if (!jsPaused && !jsEnded) {
    return const PollPlaying();
  }
  return const PollIdleTick();
}

// ---------------------------------------------------------------------------
// D7 — media-end action (RepeatMode consumer)
// ---------------------------------------------------------------------------
sealed class MediaEndDecision {
  const MediaEndDecision();

  static const MediaEndDecision stop = StopAtEnd();
  static const MediaEndDecision loop = LoopMedia();
  static const MediaEndDecision loopSegment = LoopSegment();
}

final class StopAtEnd extends MediaEndDecision {
  const StopAtEnd();
}

final class LoopMedia extends MediaEndDecision {
  const LoopMedia();
}

final class LoopSegment extends MediaEndDecision {
  const LoopSegment();
}

/// When playback reaches the end of the media, decide the next action based on
/// the persisted [RepeatMode].
///
/// [RepeatMode.none]  → stop (default, current behaviour).
/// [RepeatMode.single] → restart the current media from the beginning.
/// [RepeatMode.segment] → restart from echo-window start (segment loop).
MediaEndDecision decideOnMediaEnd({required RepeatMode repeatMode}) {
  switch (repeatMode) {
    case RepeatMode.none:
      return MediaEndDecision.stop;
    case RepeatMode.single:
      return MediaEndDecision.loop;
    case RepeatMode.segment:
      return MediaEndDecision.loopSegment;
  }
}

// ---------------------------------------------------------------------------
// D8/D9 moved to youtube_play_retry_policy.dart (issue #665).
// ---------------------------------------------------------------------------
