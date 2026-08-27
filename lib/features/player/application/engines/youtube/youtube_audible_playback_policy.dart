/// Audible-playback policy for the YouTube watch WebView (issue #628).
///
/// One owner for the whole mute-start → restore → heal choreography under
/// Chromium's autoplay gesture lock, and for every timing constant it
/// depends on. Previously the policy lived in comments and private helpers
/// smeared across [YoutubeWebViewEvents], [YoutubeSession], and
/// [YoutubeWebViewController]; each play-then-pause fix had to coordinate
/// them in lockstep.
///
/// The gesture-lock rules this module encodes:
///
/// - A muted start bypasses the gesture lock; a later programmatic unmute
///   without fresh user activation pauses the element ("Unmuting failed and
///   the element was paused instead") — the play-then-pause root cause.
/// - Therefore the unmute runs **at most once per watch document**
///   (see [YoutubeSession.needsVolumeRestore]), only after playback has
///   actually started and progressed, and is followed by a one-shot heal
///   that re-issues play if the unmute tripped the lock.
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';

final _logPolicy = logNamed('YouTubeAudiblePlaybackPolicy');

/// Re-applies the user's volume to the page player (mute/unmute/setVolume).
typedef YoutubeReapplyVolumeFn = Future<void> Function();

/// Heal play (defaults to [YoutubeWebViewBridge.play], which preserves
/// audible state).
typedef YoutubeHealPlayFn = Future<void> Function();

/// Owns the audible-start choreography and its clock.
///
/// The session remains the state store (armed flag, per-document restore
/// pin, progress ticks); this module drives the transitions and owns every
/// duration. The joint invariant —
///
///     pauseConfirm (pauseConfirmPollTicks × pollTick)
///       <  postRestoreHealDelay
///       <  YoutubeSession.tapToPlayHintDelay
///
/// — is asserted in `youtube_audible_playback_policy_test.dart` so the three
/// constraints can no longer drift independently.
class YoutubeAudiblePlaybackPolicy {
  YoutubeAudiblePlaybackPolicy({
    required this.session,
    required this.reapplyVolume,
    required this.healPlay,
    Duration? volumeRestoreDelay,
    Duration? volumeRestoreFallback,
    Duration? postRestoreHealDelay,
  }) : volumeRestoreDelay =
           volumeRestoreDelay ??
           (defaultTargetPlatform == TargetPlatform.windows
               ? windowsVolumeRestoreDelay
               : Duration.zero),
       volumeRestoreFallback =
           volumeRestoreFallback ?? defaultVolumeRestoreFallback,
       postRestoreHealDelay =
           postRestoreHealDelay ?? defaultPostRestoreHealDelay;

  /// Poll-loop cadence (canonical home here so the joint invariant above is
  /// checkable against it).
  static const Duration pollTick = Duration(milliseconds: 250);

  /// Legacy minimum settle before progress-gated unmute (Windows first play).
  /// Progress confirmation is preferred; this delay is only a lower bound when
  /// progress arrives earlier than the platform settle window.
  static const Duration windowsVolumeRestoreDelay = Duration(milliseconds: 400);

  /// Progress-gated restore gives up after this long without advancement.
  static const Duration defaultVolumeRestoreFallback = Duration(
    milliseconds: 1500,
  );

  /// How long after a volume restore to check whether the unmute tripped the
  /// WebView's autoplay gesture lock (which pauses the element). Must exceed
  /// the poll loop's pause-confirmation window
  /// ([YoutubeSession.pauseConfirmPollTicks] × [pollTick]) so a real pause is
  /// already reflected in [YoutubeSession.playing]; must stay short enough to
  /// beat the tap-to-play recovery hint.
  static const Duration defaultPostRestoreHealDelay = Duration(
    milliseconds: 900,
  );

  final Duration volumeRestoreDelay;
  final Duration volumeRestoreFallback;
  final Duration postRestoreHealDelay;

  final YoutubeSession session;
  final YoutubeReapplyVolumeFn reapplyVolume;
  final YoutubeHealPlayFn healPlay;

  Timer? _volumeRestoreFallbackTimer;
  DateTime? _volumeRestoreArmedAt;

  /// `playing` observed: arm the per-document restore if this document has
  /// not been restored yet. Later `playing` events in an already-restored
  /// document must NOT re-unmute — every programmatic unMute is a pause
  /// trigger under the gesture lock, so redundancy here is the bug.
  void onPlaying() {
    if (session.disposed || !session.needsVolumeRestore) return;
    _armProgressGatedVolumeRestore();
  }

  /// DOM `pause` while a restore is pending: the element never got audible
  /// progress, so the pending unmute is abandoned.
  void onPause() => cancelPending();

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

  /// Abandons any pending restore (explicit play, reload, dispose paths).
  void cancelPending() {
    _volumeRestoreFallbackTimer?.cancel();
    _volumeRestoreFallbackTimer = null;
    _volumeRestoreArmedAt = null;
    session.clearVolumeRestorePending();
  }

  void _armProgressGatedVolumeRestore() {
    cancelPending();
    session.armVolumeRestorePending(baseline: session.lastPosition);
    _volumeRestoreArmedAt = DateTime.now();
    _logPolicy.fine(
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

  Future<void> _restoreVolume({required String reason}) async {
    if (session.disposed || !session.playing) return;
    session.clearVolumeRestorePending();
    _volumeRestoreFallbackTimer?.cancel();
    _volumeRestoreFallbackTimer = null;
    _volumeRestoreArmedAt = null;
    try {
      await reapplyVolume();
      session.noteVolumeRestored();
      _logPolicy.fine(
        'youtube volume restored vid=${session.videoId} reason=$reason',
      );
      unawaited(_healPostRestorePause());
    } on Object catch (error, stackTrace) {
      _logPolicy.warning(
        'youtube volume restore failed vid=${session.videoId} reason=$reason',
        error,
        stackTrace,
      );
    }
  }

  /// One-shot self-heal for the gesture-lock failure mode: the unmute made
  /// the element audible without user activation and the WebView paused it
  /// right after. Re-issues play exactly once with audible state preserved —
  /// on engines that allow audible starts this recovers invisibly; where the
  /// start is genuinely refused, the poll loop's recovery hint remains the
  /// fallback.
  Future<void> _healPostRestorePause() async {
    await Future<void>.delayed(postRestoreHealDelay);
    if (session.disposed ||
        session.playing ||
        session.playbackCompleted ||
        session.needsVolumeRestore) {
      return;
    }
    _logPolicy.info('youtube post-restore pause heal vid=${session.videoId}');
    unawaited(healPlay());
  }
}
