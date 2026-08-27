/// Position/duration polling loop for the YouTube watch WebView.
library;

import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_audible_playback_policy.dart';
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

/// Periodic DOM poll for `<video>` play state (see [YoutubeStatePoller]).
class YoutubeWebViewPollLoop {
  YoutubeWebViewPollLoop({
    required this.session,
    required this.webController,
    required this.onFirstPlaying,
    this.onPlaybackProgress,
    YoutubePollFn? pollFn,
    YoutubeRetryPlayFn? retryPlay,
  }) : pollFn = pollFn ?? YoutubeStatePoller.poll,
       retryPlay = retryPlay ?? YoutubeWebViewBridge.play;

  final YoutubeSession session;
  final InAppWebViewController? Function() webController;
  final YoutubeFirstPlayingFn onFirstPlaying;

  /// Notifies when position advances (volume-restore progress gate).
  final YoutubePlaybackProgressFn? onPlaybackProgress;

  final YoutubePollFn pollFn;

  /// One-shot play re-issue for the immediate-pause retry (D8).
  final YoutubeRetryPlayFn retryPlay;

  Timer? _pollTimer;
  Timer? _pollKickTimer;

  bool get isRunning => _pollTimer != null;

  void scheduleKick() {
    _pollKickTimer?.cancel();
    _pollKickTimer = Timer(const Duration(milliseconds: 500), () {
      _pollKickTimer = null;
      if (!session.disposed) start();
    });
  }

  void start() {
    if (_pollTimer != null) return;
    session.resetPauseStreak();
    _pollTimer = Timer.periodic(
      YoutubeAudiblePlaybackPolicy.pollTick,
      (_) => _tick(),
    );
  }

  void stop() {
    _pollTimer?.cancel();
    _pollTimer = null;
    _pollKickTimer?.cancel();
    _pollKickTimer = null;
  }

  Future<void> _tick() async {
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
                  final immediate = session.isImmediatePause(DateTime.now());
                  final retry = decideImmediatePauseRetry(
                    immediate: immediate,
                    userPlayInFlight: session.userPlayInFlight,
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
                      // Consume the one-shot budget before re-playing so a
                      // second immediate pause surfaces to the user instead
                      // of looping.
                      session.clearUserPlayInFlight();
                      _logPoll.info(
                        'youtube immediate pause retry vid='
                        '${session.videoId}',
                      );
                      unawaited(retryPlay(webController()));
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
              case PollIdleTick():
                session.resetPauseStreak();
            }
          },
    );
  }
}
