/// DOM `<video>` event dispatch for [YoutubeWebViewController].
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';

final _logEvents = logNamed('YouTubeWebViewEvents');

typedef YoutubeSeekFn = Future<void> Function(Duration target);
typedef YoutubePollStartFn = void Function();
typedef YoutubePollStopFn = void Function();
typedef YoutubeFirstPlayingFn = void Function();
typedef YoutubeReapplyVolumeFn = Future<void> Function();

/// Handles `onVideoEvent` JavaScript callbacks from the watch page.
class YoutubeWebViewEvents {
  YoutubeWebViewEvents({
    required this.session,
    required this.webController,
    required this.onFirstPlaying,
    required this.startPolling,
    required this.stopPolling,
    required this.reapplyVolume,
    required this.seekTo,
    Duration? volumeRestoreDelay,
    Duration? volumeRestoreFallback,
  }) : volumeRestoreDelay =
           volumeRestoreDelay ??
           (defaultTargetPlatform == TargetPlatform.windows
               ? windowsVolumeRestoreDelay
               : Duration.zero),
       volumeRestoreFallback =
           volumeRestoreFallback ?? YoutubeSession.volumeRestoreFallback;

  /// Legacy minimum settle before progress-gated unmute (Windows first play).
  /// Progress confirmation is preferred; this delay is only a lower bound when
  /// progress arrives earlier than the platform settle window.
  static const Duration windowsVolumeRestoreDelay = Duration(milliseconds: 400);

  final Duration volumeRestoreDelay;
  final Duration volumeRestoreFallback;

  final YoutubeSession session;
  final InAppWebViewController? Function() webController;
  final YoutubeFirstPlayingFn onFirstPlaying;
  final YoutubePollStartFn startPolling;
  final YoutubePollStopFn stopPolling;
  final YoutubeReapplyVolumeFn reapplyVolume;
  final YoutubeSeekFn seekTo;

  Timer? _volumeRestoreFallbackTimer;
  DateTime? _volumeRestoreArmedAt;

  dynamic handle(List<dynamic> args) {
    if (args.isEmpty) return null;
    final event = args[0] as String;
    switch (event) {
      case 'play':
        // Optimistic request only — do not touch pause streak (DOM may still
        // pause before `playing`). Transport waits for authoritative `playing`.
        _logEvents.fine('youtube video play requested vid=${session.videoId}');
        break;
      case 'playing':
        final progressGate = !session.loggedFirstPlaying;
        session.pausedPollStreak = 0;
        session.playbackCompleted = false;
        session.emitPlaying(true);
        onFirstPlaying();
        session.emitBuffering(false);
        startPolling();
        applyPendingSeek();
        if (progressGate) {
          _armProgressGatedVolumeRestore();
        } else {
          _scheduleImmediateVolumeRestore();
        }
        _logEvents.fine('youtube video playing vid=${session.videoId}');
        break;
      case 'pause':
        // Do NOT reset [pausedPollStreak] — a DOM pause while Dart still thinks
        // playing must accumulate toward poll confirmation. Resetting here
        // previously extended the stale-`playing` window and made the next
        // transport toggle issue `pause()` instead of `play()`.
        cancelPendingVolumeRestore();
        _logEvents.fine('youtube video paused vid=${session.videoId}');
        break;
      case 'playRejected':
        cancelPendingVolumeRestore();
        session.emitPlaying(false);
        session.emitBuffering(false);
        final reason = args.length > 1 ? '${args[1]}' : 'unknown';
        _logEvents.warning(
          'youtube play rejected vid=${session.videoId} reason=$reason '
          'explicitPlay=${session.explicitPlayAttempted}',
        );
        // Keep poll running so a later user retry can still reconcile state.
        startPolling();
        session.scheduleRecoveryHint();
        break;
      case 'ended':
        session.pausedPollStreak = 0;
        cancelPendingVolumeRestore();
        session.markCompleted();
        stopPolling();
        session.emitPlaying(false);
        session.emitBuffering(false);
        unawaited(YoutubeWebViewBridge.pauseVideoElement(webController()));
        break;
      case 'waiting':
        session.emitBuffering(true);
        break;
      case 'canplay':
        if (session.buffering) {
          session.emitBuffering(false);
        }
        break;
      case 'loadedmetadata':
        startPolling();
        if (args.length > 1) {
          final dur = (args[1] as num).toDouble();
          if (dur > 0 && dur.isFinite) {
            session.emitDuration(Duration(milliseconds: (dur * 1000).round()));
            applyPendingSeek();
          }
        }
        break;
      case 'error':
        cancelPendingVolumeRestore();
        _logEvents.warning('YouTube video element error');
        session.emitPlaying(false);
        session.emitBuffering(false);
        break;
      default:
        break;
    }
    return null;
  }

  /// Called from the poll loop when `<video>.currentTime` advances.
  void onPlaybackProgress(Duration position) {
    if (!session.volumeRestorePending || session.disposed) return;
    if (!session.playing) return;
    final armedAt = _volumeRestoreArmedAt;
    if (armedAt != null) {
      final elapsed = DateTime.now().difference(armedAt);
      if (elapsed < volumeRestoreDelay) return;
    }
    if (session.noteProgressForVolumeRestore(position)) {
      unawaited(_restoreVolume(reason: 'progress'));
    }
  }

  void _armProgressGatedVolumeRestore() {
    cancelPendingVolumeRestore();
    session.armVolumeRestorePending(baseline: session.lastPosition);
    _volumeRestoreArmedAt = DateTime.now();
    _logEvents.fine(
      'youtube volume restore armed vid=${session.videoId} '
      'fallbackMs=${volumeRestoreFallback.inMilliseconds} '
      'minDelayMs=${volumeRestoreDelay.inMilliseconds}',
    );
    _volumeRestoreFallbackTimer = Timer(volumeRestoreFallback, () {
      _volumeRestoreFallbackTimer = null;
      if (session.disposed ||
          !session.playing ||
          !session.volumeRestorePending) {
        return;
      }
      unawaited(_restoreVolume(reason: 'fallback'));
    });
  }

  void _scheduleImmediateVolumeRestore() {
    cancelPendingVolumeRestore();
    unawaited(_restoreVolume(reason: 'resume'));
  }

  Future<void> _restoreVolume({required String reason}) async {
    if (session.disposed || !session.playing) return;
    session.clearVolumeRestorePending();
    _volumeRestoreFallbackTimer?.cancel();
    _volumeRestoreFallbackTimer = null;
    _volumeRestoreArmedAt = null;
    try {
      await reapplyVolume();
      _logEvents.fine(
        'youtube volume restored vid=${session.videoId} reason=$reason',
      );
    } on Object catch (error, stackTrace) {
      _logEvents.warning(
        'youtube volume restore failed vid=${session.videoId} reason=$reason',
        error,
        stackTrace,
      );
    }
  }

  void cancelPendingVolumeRestore() {
    _volumeRestoreFallbackTimer?.cancel();
    _volumeRestoreFallbackTimer = null;
    _volumeRestoreArmedAt = null;
    session.clearVolumeRestorePending();
  }

  void applyPendingSeek() {
    final secs = session.pendingSeekSeconds;
    if (secs == null || secs <= 0) return;
    session.pendingSeekSeconds = null;
    unawaited(seekTo(Duration(milliseconds: (secs * 1000).round())));
  }
}
