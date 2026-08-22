/// Deterministic end-of-media completion loop (ADR-0044).
library;

import 'dart:async';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/domain/echo_window.dart';
import 'package:enjoy_player/features/player/domain/player_settings.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';

final _log = logNamed('CompletionLoop');

/// The echo facts the loop needs for [MediaEndDecision.segment] replays.
typedef CompletionEchoSnapshot = ({bool active, double startTimeSeconds});

/// Generation-guarded await-completion loop shared by every [PlayerEngine].
///
/// Mirrors the generation-counter + single-flight pattern from
/// `EchoEnforcer._epoch` / `PlayerController._openGeneration`: the transport
/// drives itself off `await`ed completion futures instead of polling the
/// position stream, and every in-flight await captures a generation id so a
/// stale completion from a previous media (or a duplicate `completed` event
/// from mpv) is a no-op.
///
/// This is the **single consumer** of [PlayerEngine.completed] for repeat
/// policy — engine-internal poll loops (e.g. YouTube) only surface the
/// end-of-media transition and never decide the repeat action themselves.
class CompletionLoop {
  CompletionLoop({
    required this._engine,
    required this._activeMediaId,
    required this._isDisposed,
    required this._repeatMode,
    required this._echoSnapshot,
  });

  final PlayerEngine Function() _engine;
  final String? Function() _activeMediaId;
  final bool Function() _isDisposed;
  final RepeatMode Function() _repeatMode;
  final CompletionEchoSnapshot Function() _echoSnapshot;

  /// Incremented on every event that invalidates the current playback stint
  /// (openMedia, clear, abandonPendingOpen, user seek, disposal). The loop
  /// captures it at start and re-checks after every `await` — a stale
  /// completion that observes a bumped generation is a no-op (ADR-0044).
  int _playbackGen = 0;

  /// Completer used to cancel the in-flight `completed` await when the
  /// generation changes under the loop. Created per-iteration, completed by
  /// [bump], and cleared after the await resolves.
  Completer<void>? _completionCancel;

  /// Generation of the currently running loop, or `null` when none. Keyed by
  /// generation (not a bare bool) so a bumped loop that is still draining
  /// cannot block [arm] for the new stint, and its late `finally` cannot clear
  /// a newer loop's marker.
  int? _activeLoopGen;

  /// Bumps the playback generation and cancels any in-flight completion await.
  void bump() {
    _playbackGen++;
    final c = _completionCancel;
    _completionCancel = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Starts (or restarts) the loop for the current playback stint. Safe to
  /// call unconditionally — if a loop is already running for the current
  /// generation it is a no-op. A loop from a stale generation (mid-drain
  /// after [bump]) does not block a fresh start: every action re-checks the
  /// generation before acting.
  void arm() {
    if (_isDisposed()) return;
    if (_activeMediaId() == null) return;
    if (_activeLoopGen == _playbackGen) return;
    unawaited(_run(_playbackGen));
  }

  Future<void> _run(int gen) async {
    _activeLoopGen = gen;
    try {
      while (gen == _playbackGen && !_isDisposed()) {
        final mediaId = _activeMediaId();
        if (mediaId == null) return;

        final completed = await _awaitCompletionOrCancel(gen);
        if (!completed || gen != _playbackGen || _isDisposed()) return;
        if (_activeMediaId() != mediaId) return;

        final decision = decideOnMediaEnd(repeatMode: _repeatMode());
        _log.fine('completion fired for $mediaId; decision=$decision');
        switch (decision) {
          case StopAtEnd():
            return;
          case LoopMedia():
            await _replayFrom(Duration.zero, gen);
            if (gen != _playbackGen || _isDisposed()) return;
          case LoopSegment():
            final echo = _echoSnapshot();
            if (!echo.active) return;
            await _replayFrom(durationFromSeconds(echo.startTimeSeconds), gen);
            if (gen != _playbackGen || _isDisposed()) return;
        }
      }
    } finally {
      if (_activeLoopGen == gen) _activeLoopGen = null;
    }
  }

  /// Seeks to [target] and resumes playback after end-of-media. The engine's
  /// end-of-media latch is cleared first so `play()` drives the loaded media
  /// directly instead of restarting from the beginning (which would discard
  /// the seek). Late generation changes are caught by the caller's post-await
  /// re-check.
  Future<void> _replayFrom(Duration target, int gen) async {
    final engine = _engine();
    engine.resetCompletionFlag();
    await engine.seek(target);
    if (gen != _playbackGen || _isDisposed()) return;
    await engine.play();
  }

  /// Races `engine.completed.first` against a cancellation completer that is
  /// completed by [bump]. Returns `true` on real completion, `false` on
  /// cancel / stream close.
  Future<bool> _awaitCompletionOrCancel(int gen) async {
    final engine = _engine();
    final completer = Completer<bool>();
    late StreamSubscription<void> sub;

    _completionCancel = Completer<void>();
    final cancel = _completionCancel!;

    void resolve(bool value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    sub = engine.completed.listen(
      (_) => resolve(true),
      onDone: () => resolve(false),
      onError: (Object _, StackTrace _) => resolve(false),
    );

    unawaited(cancel.future.then((_) => resolve(false)));

    try {
      return await completer.future;
    } finally {
      // Only clear if this iteration still owns the slot — a fresh loop may
      // have armed a new cancel completer while this one drained.
      if (identical(_completionCancel, cancel)) _completionCancel = null;
      await sub.cancel();
    }
  }
}
