/// DOM `<video>` event dispatch for [YoutubeWebViewController].
///
/// Dispatch only: transport transitions go to [YoutubeSession], the
/// audible-start choreography to [YoutubeAudiblePlaybackPolicy] (issue #628).
library;

import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_audible_playback_policy.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_video_event.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';

final _logEvents = logNamed('YouTubeWebViewEvents');

typedef YoutubeSeekFn = Future<void> Function(Duration target);
typedef YoutubePollStartFn = void Function();
typedef YoutubePollStopFn = void Function();
typedef YoutubeFirstPlayingFn = void Function();

/// Handles `onVideoEvent` JavaScript callbacks from the watch page.
class YoutubeWebViewEvents {
  YoutubeWebViewEvents({
    required this.session,
    required this.webController,
    required this.onFirstPlaying,
    required this.startPolling,
    required this.stopPolling,
    required this.seekTo,
    required this.audibility,
  });

  final YoutubeSession session;
  final InAppWebViewController? Function() webController;
  final YoutubeFirstPlayingFn onFirstPlaying;
  final YoutubePollStartFn startPolling;
  final YoutubePollStopFn stopPolling;
  final YoutubeSeekFn seekTo;

  /// Audible-start choreography owner (mute-start → restore → heal).
  final YoutubeAudiblePlaybackPolicy audibility;

  dynamic handle(List<dynamic> args) {
    if (args.isEmpty) return null;
    final event = args[0] as String;
    switch (event) {
      case YoutubeVideoEventName.play:
        // Optimistic request only — do not touch pause streak (DOM may still
        // pause before `playing`). Transport waits for authoritative `playing`.
        _logEvents.fine('youtube video play requested vid=${session.videoId}');
        break;
      case YoutubeVideoEventName.playing:
        session.notePlayingConfirmed();
        onFirstPlaying();
        session.emitBuffering(false);
        startPolling();
        applyPendingSeek();
        audibility.onPlaying();
        _logEvents.fine('youtube video playing vid=${session.videoId}');
        break;
      case YoutubeVideoEventName.pause:
        // Do NOT reset the pause streak — a DOM pause while Dart still thinks
        // playing must accumulate toward poll confirmation. Resetting here
        // previously extended the stale-`playing` window and made the next
        // transport toggle issue `pause()` instead of `play()`.
        audibility.onPause();
        final context = args.length > 1 ? '${args[1]}' : '';
        _logEvents.fine(
          'youtube video paused vid=${session.videoId}'
          '${context.isEmpty ? '' : ' ctx=$context'}',
        );
        break;
      case YoutubeVideoEventName.playRejected:
        audibility.cancelPending();
        session.noteUserPlayUnresolved();
        final reason = args.length > 1 ? '${args[1]}' : 'unknown';
        _logEvents.warning(
          'youtube play rejected vid=${session.videoId} reason=$reason '
          'explicitPlay=${session.explicitPlayAttempted}',
        );
        // Keep poll running so a later user retry can still reconcile state.
        startPolling();
        session.scheduleRecoveryHint();
        break;
      case YoutubeVideoEventName.ended:
        audibility.cancelPending();
        session.noteEnded();
        stopPolling();
        unawaited(YoutubeWebViewBridge.pause(webController()));
        break;
      case YoutubeVideoEventName.waiting:
        session.emitBuffering(true);
        _logEvents.fine('youtube video waiting vid=${session.videoId}');
        break;
      case YoutubeVideoEventName.canplay:
        if (session.buffering) {
          session.emitBuffering(false);
        }
        break;
      case YoutubeVideoEventName.loadedmetadata:
        startPolling();
        if (args.length > 1) {
          final dur = (args[1] as num).toDouble();
          if (dur > 0 && dur.isFinite) {
            session.emitDuration(Duration(milliseconds: (dur * 1000).round()));
            applyPendingSeek();
          }
        }
        break;
      case YoutubeVideoEventName.error:
        audibility.cancelPending();
        _logEvents.warning('YouTube video element error');
        session.noteUserPlayUnresolved();
        break;
      default:
        // A name the Dart side does not switch over cannot reach here without
        // failing youtube_js_protocol_contract_test first — log so a stray
        // name surfaces in diagnostics instead of vanishing.
        _logEvents.warning('youtube unknown video event name=$event');
        break;
    }
    return null;
  }

  void applyPendingSeek() {
    final secs = session.takePendingSeekSeconds();
    if (secs == null || secs <= 0) return;
    unawaited(seekTo(Duration(milliseconds: (secs * 1000).round())));
  }
}
