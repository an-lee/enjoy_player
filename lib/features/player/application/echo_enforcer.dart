/// Single-flight coordinator for echo (shadow-reading) playback enforcement.
///
/// Consolidates the two previously uncoordinated enforcement paths (the
/// reactive per-tick correction and the proactive seek clamp) behind one gate
/// so concurrent seeks can't interleave into an audible stutter. Runs the
/// decision on every position event — pause-and-rewind fires within ~50 ms of
/// the segment end instead of up to ~360 ms late under the old 400 ms bucket
/// gate (issue #280, P1/P6/M3).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_constants.dart';
import 'package:enjoy_player/features/player/application/single_flight_gate.dart';
import 'package:enjoy_player/features/player/domain/echo_window.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';

final _echoLog = logNamed('EchoEnforcer');

/// Serializes echo enforcement for one open generation.
///
/// Constructed by [PlayerController] with the same collaborators as
/// [PlayerPositionTracker]. Engine mutations (seek / pause) from both
/// [enforceTick] (reactive) and [clampAndSeek] (proactive) flow through one
/// in-flight slot: while one runs, concurrent ticks are dropped and concurrent
/// clamps wait. [reset] must be called on media switch / clear so a pending
/// pause-and-rewind neither seeks a stale engine nor leaves the slot held.
class EchoEnforcer {
  EchoEnforcer({
    required this.ref,
    required this.getEngine,
    required this.getSession,
    required this.getLines,
  });

  final Ref ref;
  final PlayerEngine Function() getEngine;
  final PlaybackSession? Function() getSession;

  /// Cached primary transcript lines for the open media (cheap read of the
  /// `transcriptLinesForMediaProvider` family while a watcher keeps it warm).
  /// Used to re-derive echo window seconds from line indices at enforcement
  /// time so a re-segmented transcript yields fresh boundaries (M4).
  final List<TranscriptLine>? Function() getLines;

  /// Generation + single-flight slot. Bumped by [reset]; in-flight ops capture
  /// the generation at start and bail if it changed, so a media switch
  /// mid-enforcement is a no-op rather than a stray seek on the next media.
  /// While one op holds the slot, concurrent ticks are dropped and concurrent
  /// clamps wait (bounded — see [clampAndSeek]).
  final SingleFlightGate _gate = SingleFlightGate();

  /// Inputs behind the memoized window in [_windowCache]: the fields the hot
  /// path can compare for free (echo state by value, session duration). The
  /// transcript is re-read on a miss only (see [_resolveWindow]). `null` until
  /// the first derivation and after [reset].
  (EchoState, double?)? _windowCacheKey;

  /// Last derived non-override window for [_windowCacheKey].
  EchoWindow? _windowCache;

  /// Reactive per-tick enforcement. Called on every position event — the
  /// decision is cheap (pure reads), so the segment-end pause fires promptly.
  /// If enforcement is already in flight, this tick is dropped (single-flight):
  /// the in-flight action already corrected playback and the next tick
  /// re-evaluates against the post-correction position.
  Future<void> enforceTick(double positionSeconds) async {
    if (_gate.inFlight) return;
    final window = _resolveWindow();
    if (window == null) return;
    final decision = decideEchoPlaybackTime(positionSeconds, window);
    if (decision is EchoOk) return;
    final epoch = _gate.generation;
    await _gate.run(_applyDecision(decision, epoch));
  }

  /// Proactive seek clamp (user tapped a cue / scrubbed). Clamps the requested
  /// target into the echo window and seeks, serialized against reactive ticks.
  /// Returns the (possibly clamped) target actually sought, or the unclamped
  /// [requestedSeconds] when nothing was sought — a [reset] landed while
  /// waiting, or the in-flight enforcement never settled within [waitTimeout].
  Future<double> clampAndSeek(
    double requestedSeconds, {
    EchoWindow? override,
    Duration waitTimeout = kEngineCommandTimeout,
  }) async {
    // Captured before the first await: if [reset] lands while we wait on an
    // in-flight enforcement, the requested target belongs to media that is
    // gone, and re-entering the loop with a fresh epoch would seek the old
    // target onto the new engine (unclamped, its echo being inactive).
    final epoch = _gate.generation;
    while (!_gate.isStale(epoch)) {
      final pending = _gate.pending;
      if (pending == null) {
        final window = _resolveWindow(override: override);
        final target = window == null
            ? requestedSeconds
            : clampSeekTimeToEchoWindow(requestedSeconds, window);
        await _gate.run(_seek(target, epoch));
        return target;
      }
      // An enforcement is running; wait for it (bounded — a wedged engine seek
      // must not hold the slot forever), then re-check.
      try {
        await pending.timeout(waitTimeout);
      } on TimeoutException {
        _echoLog.warning(
          'echo enforcement still in flight after $waitTimeout '
          '(engine seek wedged?); releasing the slot and skipping the clamp '
          'seek',
        );
        // The wedged op's own finally is guarded by identity, so clearing here
        // cannot race it out of a slot it still owns.
        _gate.release(pending);
        return requestedSeconds;
      }
    }
    return requestedSeconds;
  }

  /// Neutralizes any in-flight enforcement and releases the slot. Called on
  /// media switch / clear so a pending pause-and-rewind can't seek a stale
  /// engine or hold the slot forever (which would block all future enforcement).
  void reset() {
    _gate.cancel();
    // The window is derived from the previous media's session; re-derive for
    // the next one rather than serving a cached duration / transcript.
    _windowCacheKey = null;
    _windowCache = null;
  }

  Future<void> _applyDecision(EchoPlaybackDecision decision, int epoch) async {
    if (_gate.isStale(epoch)) return;
    switch (decision) {
      case EchoOk():
        return;
      case EchoClamp(:final timeSeconds):
        await getEngine().seek(durationFromSeconds(timeSeconds));
      case EchoPauseAndRewind(:final timeSeconds):
        await getEngine().pause();
        // A reset may have landed between pause and seek; don't seek a stale
        // engine onto the next media.
        if (_gate.isStale(epoch)) return;
        await getEngine().seek(durationFromSeconds(timeSeconds));
    }
  }

  Future<void> _seek(double targetSeconds, int epoch) async {
    if (_gate.isStale(epoch)) return;
    await getEngine().seek(durationFromSeconds(targetSeconds));
  }

  /// Resolves the effective echo window. When [override] is given (a freshly
  /// tapped cue) it wins; otherwise the derivation is memoized on its inputs
  /// (see [_deriveWindow]) so the per-position-event hot path only recomputes
  /// when the echo state or the session duration actually changed.
  EchoWindow? _resolveWindow({EchoWindow? override}) {
    final echo = ref.read(echoModeProvider);
    if (!echo.active) return null;
    final durationSeconds = getSession()?.durationSeconds;

    if (override != null) {
      return _deriveWindow(
        echo,
        durationSeconds: durationSeconds,
        override: override,
      );
    }

    // EchoState compares by value, so this is a cheap no-allocation key. A
    // transcript-only change (re-segmentation) is picked up on the next echo /
    // duration change, or on [reset] at the next media switch.
    final key = (echo, durationSeconds);
    if (_windowCacheKey == key) return _windowCache;
    final window = _deriveWindow(echo, durationSeconds: durationSeconds);
    _windowCacheKey = key;
    _windowCache = window;
    return window;
  }

  /// Derives the effective window: [override] wins; otherwise seconds come
  /// from [echo]'s line indices + current transcript (single source of truth),
  /// falling back to the seconds cached at activation / expand / shrink time
  /// when no transcript is available.
  EchoWindow? _deriveWindow(
    EchoState echo, {
    double? durationSeconds,
    EchoWindow? override,
  }) {
    final double startSeconds;
    final double endSeconds;
    if (override != null) {
      startSeconds = override.start;
      endSeconds = override.end;
    } else {
      final lines = getLines();
      startSeconds =
          _lineStartSeconds(lines, echo.startLineIndex) ??
          echo.startTimeSeconds;
      endSeconds =
          _lineEndSeconds(lines, echo.endLineIndex) ?? echo.endTimeSeconds;
    }

    return normalizeEchoWindow((
      active: true,
      startTimeSeconds: startSeconds,
      endTimeSeconds: endSeconds,
      durationSeconds: durationSeconds != null && durationSeconds > 0
          ? durationSeconds
          : null,
    ));
  }

  static double? _lineStartSeconds(List<TranscriptLine>? lines, int index) {
    if (lines == null || index < 0 || index >= lines.length) return null;
    return lines[index].startSeconds;
  }

  static double? _lineEndSeconds(List<TranscriptLine>? lines, int index) {
    if (lines == null || index < 0 || index >= lines.length) return null;
    return lines[index].endSeconds;
  }
}
