/// Watch-page load, verify, and stall-recovery navigation for YouTube WebView.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';

final _logNav = logNamed('YouTubeWebViewNavigation');

/// Load/verify/nudge helpers shared by [YoutubeWebViewController].
class YoutubeWebViewNavigation {
  YoutubeWebViewNavigation({
    required this.session,
    required this.webController,
    required this.captureVerifyGeneration,
    required this.isVerifyGenerationStale,
    required this.bumpNavGeneration,
    required this.currentNavGeneration,
    required this.onStaleWebView,
  });

  final YoutubeSession session;
  final InAppWebViewController? Function() webController;
  final int Function() captureVerifyGeneration;
  final bool Function(int gen) isVerifyGenerationStale;
  final int Function() bumpNavGeneration;
  final int Function() currentNavGeneration;
  final void Function() onStaleWebView;

  static const Duration playbackNudgeDelay = Duration(seconds: 6);
  static const Duration coldMountVerifyDelay = Duration(seconds: 10);

  Timer? _playbackNudgeTimer;

  void cancelNudge() {
    _playbackNudgeTimer?.cancel();
    _playbackNudgeTimer = null;
  }

  Future<void> loadCurrentVideoIfAttached() async {
    final controller = webController();
    if (controller == null || session.videoId.isEmpty) return;
    final videoId = session.videoId;
    final navGen = bumpNavGeneration();
    try {
      await YoutubeWebViewBridge.loadWatchPage(controller, videoId);
    } on MissingPluginException catch (e, st) {
      if (identical(webController(), controller)) {
        onStaleWebView();
      }
      _logNav.fine('Ignoring loadUrl on stale YouTube WebView', e, st);
      return;
    }
    if (currentNavGeneration() != navGen || session.videoId != videoId) return;
  }

  Future<void> ensureWatchPageLoadedAfterDelay({
    Duration delay = const Duration(seconds: 2),
    bool skipIfLoadStopReceived = false,
  }) async {
    final gen = captureVerifyGeneration();
    await Future<void>.delayed(delay);
    if (isVerifyGenerationStale(gen)) return;
    if (session.disposed ||
        session.videoId.isEmpty ||
        webController() == null) {
      return;
    }
    if (session.loggedFirstPlaying) return;
    // Do not reload over an in-flight user/app play attempt.
    if (session.explicitPlayAttempted) return;
    if (skipIfLoadStopReceived && session.watchPageLoadStopReceived) return;
    _logNav.info('youtube verify watch load vid=${session.videoId}');
    await loadCurrentVideoIfAttached();
  }

  void scheduleNonWatchRecovery() {
    if (session.disposed ||
        session.videoId.isEmpty ||
        session.loggedFirstPlaying) {
      return;
    }
    if (session.nonWatchRecoveryScheduled) return;
    session.scheduleNonWatchRecovery();
    _logNav.info('youtube non-watch load_stop; verifying watch page');
    unawaited(ensureWatchPageLoadedAfterDelay(skipIfLoadStopReceived: true));
  }

  void schedulePlaybackNudge() {
    _playbackNudgeTimer?.cancel();
    _playbackNudgeTimer = Timer(playbackNudgeDelay, () {
      _playbackNudgeTimer = null;
      if (session.disposed ||
          session.loggedFirstPlaying ||
          session.explicitPlayAttempted ||
          webController() == null) {
        return;
      }
      _logNav.info('youtube nudge play vid=${session.videoId}');
      unawaited(nudgePlaybackStart(webController()));
    });
  }

  Future<void> onWebViewProcessTerminated({
    required void Function() prepareWatchReload,
  }) async {
    final controller = webController();
    final vid = session.videoId;
    if (controller == null || vid.isEmpty || session.disposed) return;
    _logNav.warning('youtube WebView process terminated; reloading vid=$vid');
    prepareWatchReload();
    session.emitBuffering(true);
    session.emitPlaying(false);
    await YoutubeWebViewBridge.loadWatchPage(controller, vid);
  }

  Future<void> onSignInNavigationBlocked(
    InAppWebViewController controller, {
    required void Function() prepareWatchReload,
  }) async {
    final vid = session.videoId;
    if (vid.isEmpty || session.disposed) return;
    prepareWatchReload();
    _logNav.info('youtube reload after blocked sign-in vid=$vid');
    await YoutubeWebViewBridge.loadWatchPage(controller, vid);
  }

  Future<void> nudgePlaybackStart(InAppWebViewController? web) async {
    if (web == null || session.disposed || session.loggedFirstPlaying) return;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      await YoutubeWebViewBridge.forceInlinePlayback(web);
    }
    await YoutubeWebViewBridge.play(web);
  }

  Future<void> recoverStalledPlayback({
    required int maxStallRecoveries,
    required int Function() stallRecoveryCount,
    required void Function(int count) setStallRecoveryCount,
    required void Function() prepareWatchReload,
    required void Function() cancelStallWatchdog,
  }) async {
    final controller = webController();
    final vid = session.videoId;
    if (controller == null || vid.isEmpty || session.disposed) return;
    if (session.playing) {
      cancelStallWatchdog();
      return;
    }
    // User already pressed play — reload would abort the in-flight attempt.
    if (session.explicitPlayAttempted) {
      _logNav.info(
        'youtube stall recovery deferred; explicit play in progress vid=$vid',
      );
      cancelStallWatchdog();
      unawaited(nudgePlaybackStart(controller));
      return;
    }
    if (stallRecoveryCount() >= maxStallRecoveries) {
      _logNav.info(
        'youtube stall recovery limit reached vid=$vid; nudging play',
      );
      unawaited(nudgePlaybackStart(controller));
      return;
    }
    setStallRecoveryCount(stallRecoveryCount() + 1);
    cancelStallWatchdog();
    _logNav.info('youtube reload after stall vid=$vid');
    prepareWatchReload();
    session.emitBuffering(true);
    await YoutubeWebViewBridge.loadWatchPage(controller, vid);
  }
}
