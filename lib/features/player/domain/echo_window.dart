/// Echo (shadow reading) playback window — ported from web `echo-utils.ts`.
library;

/// Inclusive start (seconds), exclusive-ish end (playback stays strictly before end).
typedef EchoWindow = ({double start, double end});

typedef NormalizeEchoWindowInput = ({
  bool active,
  double startTimeSeconds,
  double endTimeSeconds,
  double? durationSeconds,
});

sealed class EchoPlaybackDecision {
  const EchoPlaybackDecision();

  static const EchoPlaybackDecision ok = EchoOk();

  static EchoPlaybackDecision clamp(double timeSeconds) =>
      EchoClamp(timeSeconds);

  static EchoPlaybackDecision pauseAndRewind(double timeSeconds) =>
      EchoPauseAndRewind(timeSeconds);
}

final class EchoOk extends EchoPlaybackDecision {
  const EchoOk();
}

final class EchoClamp extends EchoPlaybackDecision {
  const EchoClamp(this.timeSeconds);
  final double timeSeconds;
}

/// Pause playback and rewind for replay from segment start (shadow-reading UX).
final class EchoPauseAndRewind extends EchoPlaybackDecision {
  const EchoPauseAndRewind(this.timeSeconds);
  final double timeSeconds;
}

const double defaultEchoSeekEpsilonSeconds = 0.02;
const double defaultEchoEndGuardSeconds = 0.04;
const double defaultEchoStartGuardSeconds = 0.02;

/// Converts seconds to the millisecond integer used by persistence / engine
/// seeks. Centralized so the s/ms boundary lives in one place (the DB stores
/// ms; echo state + decisions work in seconds).
Duration durationFromSeconds(double seconds) =>
    Duration(milliseconds: (seconds * 1000).round());

/// Inverse of [durationFromSeconds].
double secondsFromDuration(Duration duration) =>
    duration.inMilliseconds / 1000.0;

/// Converts a millisecond integer (DB column) to seconds.
double secondsFromMs(int milliseconds) => milliseconds / 1000.0;

/// Converts seconds to a millisecond integer (DB column).
int msFromSeconds(double seconds) => (seconds * 1000).round();

double _clamp(double value, double min, double max) =>
    value < min ? min : (value > max ? max : value);

bool _isFiniteNumber(num? value) => value != null && value.isFinite;

/// Normalize and validate the echo window (same rules as TS).
EchoWindow? normalizeEchoWindow(NormalizeEchoWindowInput input) {
  if (!input.active) return null;
  if (!_isFiniteNumber(input.startTimeSeconds) ||
      !_isFiniteNumber(input.endTimeSeconds)) {
    return null;
  }

  final hasValidDuration =
      input.durationSeconds != null &&
      input.durationSeconds!.isFinite &&
      input.durationSeconds! > 0;
  final maxTime = hasValidDuration ? input.durationSeconds! : double.infinity;

  final start = _clamp(input.startTimeSeconds, 0, maxTime);
  final end = _clamp(input.endTimeSeconds, 0, maxTime);

  if (!start.isFinite || !end.isFinite) return null;
  if (end <= start) return null;

  // A window narrower than `endGuard + seekEpsilon` has no playable position:
  // the end guard fires pause-and-rewind the instant the rewind-to-start seek
  // lands, looping seek → pause → seek (issue #659 — arbitrary start/end query
  // params or a sub-40 ms cue). Widen to the minimum; when the media is too
  // short to allow even that, drop the window — enforcing it can only churn.
  final minEnd =
      start + defaultEchoEndGuardSeconds + defaultEchoSeekEpsilonSeconds;
  if (minEnd > maxTime) return null;
  if (end < minEnd) return (start: start, end: minEnd);

  return (start: start, end: end);
}

/// Clamp seek target into echo window (prefer strictly before end).
double clampSeekTimeToEchoWindow(
  double requestedTimeSeconds,
  EchoWindow window, {
  double seekEpsilonSeconds = defaultEchoSeekEpsilonSeconds,
}) {
  if (!_isFiniteNumber(requestedTimeSeconds)) return window.start;

  final maxPlayable = window.start > window.end - seekEpsilonSeconds
      ? window.start
      : window.end - seekEpsilonSeconds;
  return _clamp(requestedTimeSeconds, window.start, maxPlayable);
}

/// Decide playback correction on each time tick.
EchoPlaybackDecision decideEchoPlaybackTime(
  double currentTimeSeconds,
  EchoWindow window, {
  double startGuardSeconds = defaultEchoStartGuardSeconds,
  double endGuardSeconds = defaultEchoEndGuardSeconds,
}) {
  if (!_isFiniteNumber(currentTimeSeconds)) {
    return EchoPlaybackDecision.clamp(window.start);
  }

  if (currentTimeSeconds < window.start - startGuardSeconds) {
    return EchoPlaybackDecision.clamp(window.start);
  }

  if (currentTimeSeconds >= window.end - endGuardSeconds) {
    return EchoPlaybackDecision.pauseAndRewind(window.start);
  }

  return EchoPlaybackDecision.ok;
}
