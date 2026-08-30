/// Position/duration polling loop for the YouTube watch WebView.
library;

import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_audible_playback_policy.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_play_retry_policy.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_state_poller.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';

typedef YoutubeFirstPlayingFn = void Function();
typedef YoutubePlaybackProgressFn = void Function(Duration position);

/// Injectable poll body for unit tests (defaults to [YoutubeStatePoller.poll]).
typedef YoutubePollFn =
    Future<void> Function({
      required bool disposed,
      required InAppWebViewController? web,
      required void Function({
        required Duration position,
        Duration? newDuration,
        required bool jsPaused,
        required bool jsEnded,
      })
      onResult,
    });

/// Injectable immediate-pause retry play (defaults to
/// [YoutubeWebViewBridge.play]).
typedef YoutubeRetryPlayFn = Future<void> Function(InAppWebViewController? web);

final _logPoll = logNamed('YouTubeWebViewPollLoop');

/// DOM poll for `<video>` play state (see [YoutubeStatePoller]).
///
/// A one-shot [Timer] chain, not [Timer.periodic]: the cadence is a decision
/// made per tick. While anything is live — playing, an unconfirmed pause
/// streak, a paused position that is still moving — it is [pollTick]; once a
/// pause is CONFIRMED and quiet it backs off to [pausedPollBackoff] (issue
/// #662), and [start] puts it back on every play intent or state transition.
class YoutubeWebViewPollLoop {
  YoutubeWebViewPollLoop({
    required this.session,
    required this.webController,
    required this.onFirstPlaying,
    this.onPlaybackProgress,
    this.pollTick = YoutubeAudiblePlaybackPolicy.pollTick,
    this.pausedPollBackoff = defaultPausedPollBackoff,
    YoutubePollFn? pollFn,
    YoutubeRetryPlayFn? retryPlay,
  }) : pollFn = pollFn ?? YoutubeStatePoller.poll,
       // The default retry re-asserts the page's pinned focus first (focus
       // loss was one field-confirmed pause trigger) and then plays only
       // once the element actually has data — the wedge's dominant cause is
       // buffer exhaustion (pause ctx pstate=3, decoder starved ~10× below
       // realtime), and an immediate re-play just re-exhausts the buffer.
       retryPlay =
           retryPlay ??
           ((web) async {
             await YoutubeWebViewBridge.refocusWindow(web);
             await YoutubeWebViewBridge.playWhenReady(web);
           });

  /// Cadence once a pause is confirmed AND the position has stopped moving
  /// (issue #662). Shadow reading pauses a lot, and every tick is a JS
  /// evaluation inside the WebView; 250 ms buys nothing on a paused element.
  /// Never applied before a pause is confirmed — the confirmation window
  /// itself ([YoutubeSession.pauseConfirmPollTicks] × [pollTick], which the
  /// audible-playback joint invariant is checked against) must keep its full
  /// resolution, and an idle-but-never-played document still needs fast
  /// sampling to catch its first metadata.
  static const Duration defaultPausedPollBackoff = Duration(seconds: 1);

  final YoutubeSession session;
  final InAppWebViewController? Function() webController;
  final YoutubeFirstPlayingFn onFirstPlaying;

  /// Notifies when position advances (volume-restore progress gate).
  final YoutubePlaybackProgressFn? onPlaybackProgress;

  final YoutubePollFn pollFn;

  /// One-shot play re-issue for the immediate-pause retry (D8).
  final YoutubeRetryPlayFn retryPlay;

  /// Live cadence — [YoutubeAudiblePlaybackPolicy.pollTick] is the canonical
  /// home of the default (the pause-confirmation invariant reads against it).
  final Duration pollTick;

  /// Cadence while a confirmed pause sits quiet; see
  /// [defaultPausedPollBackoff].
  final Duration pausedPollBackoff;

  Timer? _pollTimer;
  Timer? _pollKickTimer;

  /// A poll is awaited but not finished yet. The timer chain does not wait
  /// for the previous callback, so a read that outlives one [pollTick] — a
  /// heavy page, the inject sweep, a GC pause — used to let the next tick
  /// issue a second read while the first was still outstanding. Two
  /// overlapping reads resolve in completion order, not issue order, so the
  /// OLDER DOM snapshot could apply last: a stale `s=1` landing after
  /// end-of-media runs [YoutubeSession.notePlayingConfirmed], which clears
  /// `_playbackCompleted` and re-emits `playing=true` on a video that is
  /// already over (issue #655). Dropping the tick rather than queuing it
  /// keeps the cadence self-correcting — the next period samples the DOM
  /// again, so a slow page loses nothing but the ordering hazard.
  bool _pollInFlight = false;

  /// A pause has been confirmed since the last play intent. The backoff is
  /// keyed to a CONFIRMED pause only: [decidePollTransition] reports
  /// [PauseStreaking] while Dart still believes it is playing, and every
  /// later paused read is a [PollIdleTick], so "idle" alone would back the
  /// loop off before it ever confirmed anything.
  bool _pauseConfirmed = false;

  /// The confirmed pause is not producing new information — the position has
  /// stopped moving since the previous read.
  bool _pauseQuiet = false;

  /// Position from the previous read; the "quiet" half of the backoff test.
  Duration _lastReadPosition = Duration.zero;

  bool get isRunning => _pollTimer != null;

  void scheduleKick() {
    _pollKickTimer?.cancel();
    _pollKickTimer = Timer(const Duration(milliseconds: 500), () {
      _pollKickTimer = null;
      if (!session.disposed) start();
    });
  }

  void start() {
    // A play intent (or any state transition) restores the fast cadence even
    // while the loop is already running — a backed-off loop must not stretch
    // the wait for the first read after a play command. Re-arming rather than
    // early-returning keeps the old "start twice is one timer" property.
    _pauseConfirmed = false;
    _pauseQuiet = false;
    session.resetPauseStreak();
    _pollTimer?.cancel();
    _scheduleNext();
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollKickTimer?.cancel();
    _pollKickTimer = null;
  }

  void _scheduleNext() {
    _pollTimer = Timer(
      _pauseConfirmed && _pauseQuiet ? pausedPollBackoff : pollTick,
      _onTick,
    );
  }

  /// One-shot chain link. Re-arms BEFORE the read so the cadence stays
  /// independent of read latency — exactly the [Timer.periodic] property the
  /// in-flight guard was written against.
  void _onTick() {
    _scheduleNext();
    unawaited(_tick());
  }

  Future<void> _tick() async {
    // See [_pollInFlight]: one read at a time, never two overlapping ones.
    if (_pollInFlight) return;
    _pollInFlight = true;
    // `finally`, not the happy path: a pollFn that throws must not leave the
    // guard latched and silently starve the loop while `isRunning` stays true.
    try {
      await pollFn(
        disposed: session.disposed,
        web: webController(),
        onResult:
            ({
              required Duration position,
              Duration? newDuration,
              required bool jsPaused,
              required bool jsEnded,
            }) {
              if (session.disposed) return;
              session.emitPosition(position);
              // "Quiet" is measured against the previous read, before any of
              // the transitions below touch session state.
              final positionMoved = position != _lastReadPosition;
              _lastReadPosition = position;
              if (newDuration != null &&
                  newDuration > Duration.zero &&
                  newDuration != session.lastDuration) {
                session.emitDuration(newDuration);
              }
              if (!jsPaused && !jsEnded) {
                onPlaybackProgress?.call(position);
              }
              final transition = decidePollTransition(
                jsEnded: jsEnded,
                jsPaused: jsPaused,
                playing: session.playing,
                pausedPollStreak: session.pausedPollStreak,
                pauseConfirmThreshold: YoutubeSession.pauseConfirmPollTicks,
                playbackCompleted: session.playbackCompleted,
              );
              switch (transition) {
                case MediaJustEnded():
                  // Surface the transition only — the transport's CompletionLoop
                  // is the single consumer of `completed` for repeat policy
                  // (ADR-0044). Stop polling; the loop's replay re-arms it via
                  // the explicit-play path.
                  session.noteEnded();
                  stop();
                case PauseStreaking(:final confirmed, :final newStreak):
                  session.notePauseStreak(newStreak);
                  if (confirmed) {
                    // Confirmed AND the frame has stopped moving → the only
                    // state [pausedPollBackoff] may apply to.
                    _pauseConfirmed = true;
                    _pauseQuiet = !positionMoved;
                    final immediate = session.isImmediatePause();
                    // The budget, its coverage arms, and the escalation cap
                    // live in the retry policy (issue #665); this loop only
                    // supplies the session facts that veto a retry.
                    final retry = session.playRetry.decideConfirmedPause(
                      immediate: immediate,
                      disposed: session.disposed,
                      playbackCompleted: session.playbackCompleted,
                    );
                    _logPoll.fine(
                      'youtube pause confirmed vid=${session.videoId} '
                      'positionMs=${position.inMilliseconds} '
                      'immediate=$immediate '
                      'explicitPlay=${session.explicitPlayAttempted}',
                    );
                    if (immediate) {
                      _logPoll.info(
                        'youtube immediate pause vid=${session.videoId} '
                        'positionMs=${position.inMilliseconds}',
                      );
                    }
                    session.notePauseConfirmed();
                    switch (retry) {
                      case RetryPlayOnce():
                        // Consume the command budget before re-playing; further
                        // retries for this pause chain come from the capped
                        // escalation arm (auto-retry attribution), so a
                        // deliberate pause is never fought indefinitely.
                        session.clearUserPlayInFlight();
                        // Timestamp the issue: the audible policy's
                        // post-restore heal suppresses itself while a retry
                        // is this recent (same pause, one play).
                        session.noteAutoPlayRetry();
                        _logPoll.info(
                          'youtube immediate pause retry vid='
                          '${session.videoId}',
                        );
                        unawaited(
                          retryPlay(webController()).catchError((
                            Object error,
                            StackTrace stackTrace,
                          ) {
                            // The budget is already spent; surface the failed
                            // retry instead of an unhandled zone error that
                            // reads as a crash with no context.
                            _logPoll.warning(
                              'youtube immediate pause retry failed '
                              'vid=${session.videoId}',
                              error,
                              stackTrace,
                            );
                          }),
                        );
                      case SurfacePause():
                        if (immediate || session.explicitPlayAttempted) {
                          session.scheduleRecoveryHint();
                        }
                    }
                    // Keep polling after pause so a subsequent play attempt can
                    // detect DOM state even if `playing`/`playRejected` is missed.
                    // Position updates while paused are cheap; stop only on ended.
                  }
                case PollPlaying():
                  session.notePlayingConfirmed();
                  onFirstPlaying();
                  if (session.buffering) {
                    session.emitBuffering(false);
                  }
                  // Any sign of life returns the loop to the fast cadence.
                  _pauseConfirmed = false;
                  _pauseQuiet = false;
                case PollIdleTick():
                  session.resetPauseStreak();
                  // An idle tick is what a confirmed pause looks like from
                  // here on (see [_pauseConfirmed]) — a seek-while-paused
                  // briefly un-quiets it, and the next stable read re-arms
                  // the backoff. Before any pause is confirmed this must
                  // leave the cadence alone: a document that has never
                  // played is still waiting for its first metadata.
                  if (_pauseConfirmed) {
                    _pauseQuiet = !positionMoved;
                  }
              }
            },
      );
    } finally {
      _pollInFlight = false;
    }
  }
}
