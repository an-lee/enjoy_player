/// WebView lifecycle, navigation, and DOM polling for [YoutubePlayerEngine].
library;

import 'dart:async';

import 'package:flutter_inappwebview/flutter_inappwebview.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_page_inject.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_playback_stall_watchdog.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_session.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_watch_navigation_policy.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_bridge.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_events.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_navigation.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_webview_poll_loop.dart';
import 'package:enjoy_player/features/player/domain/player_settings.dart';

final _logWebView = logNamed('YouTubeWebViewController');

/// Manages [InAppWebView] attach/load/poll for one [YoutubeSession].
class YoutubeWebViewController {
  YoutubeWebViewController({
    required this.session,
    required this.onStallRecovery,
    required this.onLogInitPhase,
    this.repeatMode,
    this.onMediaEnd,
  }) : _stallWatchdog = YoutubePlaybackStallWatchdog(
         timeout: const Duration(seconds: 12),
         onStall: (videoId) {
           if (session.playing) return;
           _logWebView.warning(
             'youtube playback stalled after load_stop vid=$videoId',
           );
           unawaited(onStallRecovery());
         },
       ) {
    _events = YoutubeWebViewEvents(
      session: session,
      webController: () => _webController,
      onFirstPlaying: onFirstPlayingFromSession,
      startPolling: () => _pollLoop.start(),
      stopPolling: () => _pollLoop.stop(),
      reapplyVolume: reapplyVolume,
      seekTo: (d) => YoutubeWebViewBridge.seekToSeconds(
        _webController,
        d.inMilliseconds / 1000.0,
      ),
    );
    _pollLoop = YoutubeWebViewPollLoop(
      session: session,
      webController: () => _webController,
      onFirstPlaying: onFirstPlayingFromSession,
      repeatMode: repeatMode,
      onMediaEnd: onMediaEnd,
      onPlaybackProgress: _events.onPlaybackProgress,
    );
    _navigation = YoutubeWebViewNavigation(
      session: session,
      webController: () => _webController,
      captureVerifyGeneration: () => _verifyGeneration,
      isVerifyGenerationStale: (gen) => gen != _verifyGeneration,
      bumpNavGeneration: () => ++_navGeneration,
      currentNavGeneration: () => _navGeneration,
      onStaleWebView: () {
        _webController = null;
        session.webViewMounted = false;
        _pollLoop.stop();
        session.mountTick.value++;
      },
    );
  }

  final YoutubeSession session;
  final Future<void> Function() onStallRecovery;
  final void Function(String phase) onLogInitPhase;
  final RepeatMode Function()? repeatMode;
  final void Function()? onMediaEnd;

  static const int maxStallRecoveries = 1;

  final YoutubePlaybackStallWatchdog _stallWatchdog;
  late final YoutubeWebViewEvents _events;
  late final YoutubeWebViewPollLoop _pollLoop;
  late final YoutubeWebViewNavigation _navigation;

  InAppWebViewController? _webController;
  int _verifyGeneration = 0;
  int _navGeneration = 0;
  int _stallRecoveryCount = 0;
  bool _rejectingNativeFullscreen = false;

  InAppWebViewController? get webController => _webController;

  void markOpenTimingStart() {
    _stallWatchdog.cancel();
    _navigation.cancelNudge();
    _events.cancelPendingVolumeRestore();
    _bumpVerifyGeneration();
    session.initStopwatch = Stopwatch()..start();
    session.loggedFirstPlaying = false;
    session.watchPageLoadStopReceived = false;
    session.awaitingColdInitialNavigation = false;
    session.nonWatchRecoveryScheduled = false;
    _stallRecoveryCount = 0;
    onLogInitPhase('open_start');
  }

  void prepareWatchReload({
    required bool resetFirstPlaying,
    bool resetStallRecovery = true,
  }) {
    _stallWatchdog.cancel();
    _navigation.cancelNudge();
    _events.cancelPendingVolumeRestore();
    _bumpVerifyGeneration();
    session.watchPageLoadStopReceived = false;
    session.awaitingColdInitialNavigation = false;
    session.nonWatchRecoveryScheduled = false;
    if (resetFirstPlaying) {
      session.loggedFirstPlaying = false;
    }
    if (resetStallRecovery) {
      _stallRecoveryCount = 0;
    }
  }

  void onFirstPlayingFromSession() {
    _stallWatchdog.onFirstPlaying();
    if (!session.loggedFirstPlaying) {
      session.loggedFirstPlaying = true;
      _navigation.cancelNudge();
      onLogInitPhase('first_playing');
    }
  }

  /// Cancels autoplay assist (nudge / stall reload) around an explicit play.
  void onExplicitPlayAttempt() {
    session.markExplicitPlayAttempt();
    _navigation.cancelNudge();
    _stallWatchdog.cancel();
    _pollLoop.start();
  }

  Future<void> idleAfterClear({bool keepMounted = false}) async {
    _stallWatchdog.cancel();
    _navigation.cancelNudge();
    _events.cancelPendingVolumeRestore();
    _bumpVerifyGeneration();
    session.resetForClear(keepMounted: keepMounted);
    _pollLoop.stop();
    final navGen = ++_navGeneration;
    final controller = _webController;
    if (controller == null) return;
    await YoutubeWebViewBridge.loadIdlePage(controller);
    if (_navGeneration != navGen &&
        session.videoId.isNotEmpty &&
        identical(_webController, controller)) {
      unawaited(_navigation.loadCurrentVideoIfAttached());
    }
  }

  Future<void> dispose() async {
    _stallWatchdog.cancel();
    _navigation.cancelNudge();
    _events.cancelPendingVolumeRestore();
    _bumpVerifyGeneration();
    _pollLoop.stop();
  }

  Future<void> onSignInNavigationBlocked(InAppWebViewController controller) =>
      _navigation.onSignInNavigationBlocked(
        controller,
        prepareWatchReload: () => prepareWatchReload(resetFirstPlaying: false),
      );

  Future<void> onWebViewProcessTerminated() =>
      _navigation.onWebViewProcessTerminated(
        prepareWatchReload: () => prepareWatchReload(resetFirstPlaying: true),
      );

  void onWebViewCreated(
    InAppWebViewController controller, {
    bool initialWatchUrlRequested = false,
  }) {
    _webController = controller;
    session.webViewMounted = true;
    onLogInitPhase('webview_created');

    if (initialWatchUrlRequested && session.videoId.isNotEmpty) {
      session.awaitingColdInitialNavigation = true;
    }

    controller.addJavaScriptHandler(
      handlerName: 'onAdReload',
      callback: (List<dynamic> args) {
        if (args.isNotEmpty) {
          session.pendingSeekSeconds = (args[0] as num?)?.toDouble() ?? 0;
        }
        return null;
      },
    );

    controller.addJavaScriptHandler(
      handlerName: 'onVideoEvent',
      callback: _events.handle,
    );

    if (session.videoId.isNotEmpty && !initialWatchUrlRequested) {
      unawaited(_navigation.loadCurrentVideoIfAttached());
      unawaited(
        _navigation.ensureWatchPageLoadedAfterDelay(
          skipIfLoadStopReceived: true,
        ),
      );
    } else if (session.videoId.isNotEmpty) {
      unawaited(
        _navigation.ensureWatchPageLoadedAfterDelay(
          delay: YoutubeWebViewNavigation.coldMountVerifyDelay,
          skipIfLoadStopReceived: true,
        ),
      );
    }
  }

  void onWebViewDisposed(InAppWebViewController? controller) {
    if (identical(_webController, controller)) {
      _webController = null;
      session.webViewMounted = false;
      session.awaitingColdInitialNavigation = false;
      _navigation.cancelNudge();
      _events.cancelPendingVolumeRestore();
      _bumpVerifyGeneration();
      _pollLoop.stop();
      // Defer: notifying during StatefulElement.unmount locks the tree
      // (ValueListenableBuilder markNeedsBuild assertion).
      scheduleMicrotask(() {
        session.mountTick.value++;
      });
    }
  }

  Future<void> onPageFinished(
    InAppWebViewController controller,
    String? url,
  ) async {
    if (!isYoutubeWatchPageLoadStopUrl(url)) {
      if (url != null && !url.startsWith('about:')) {
        _logWebView.fine('youtube skip load_stop url=$url');
      }
      _navigation.scheduleNonWatchRecovery();
      return;
    }
    session.awaitingColdInitialNavigation = false;
    session.watchPageLoadStopReceived = true;
    session.nonWatchRecoveryScheduled = false;
    onLogInitPhase('load_stop');
    if (!session.loggedFirstPlaying) {
      _stallWatchdog.onLoadStop(session.videoId);
      _navigation.schedulePlaybackNudge();
    } else {
      _stallWatchdog.cancel();
      _navigation.cancelNudge();
    }
    await injectYoutubeMobileWatchPage(controller);
    _pollLoop.scheduleKick();
  }

  Future<void> recoverStalledPlayback() async {
    await _navigation.recoverStalledPlayback(
      maxStallRecoveries: maxStallRecoveries,
      stallRecoveryCount: () => _stallRecoveryCount,
      setStallRecoveryCount: (c) => _stallRecoveryCount = c,
      prepareWatchReload: () => prepareWatchReload(
        resetFirstPlaying: false,
        resetStallRecovery: false,
      ),
      cancelStallWatchdog: _stallWatchdog.cancel,
    );
  }

  Future<void> loadCurrentVideoIfAttached() =>
      _navigation.loadCurrentVideoIfAttached();

  Future<void> reapplyVolume() async {
    await YoutubeWebViewBridge.setVolume(
      _webController,
      session.volumeNormalized,
    );
  }

  Future<void> exitNativeFullscreen(InAppWebViewController controller) async {
    if (_rejectingNativeFullscreen) return;
    _rejectingNativeFullscreen = true;
    try {
      await YoutubeWebViewBridge.forceInlinePlayback(controller);
    } catch (e, st) {
      _logWebView.fine('Failed to force inline playback', e, st);
    } finally {
      _rejectingNativeFullscreen = false;
    }
  }

  Future<void> onNativeFullscreenExit(InAppWebViewController controller) async {
    await YoutubeWebViewBridge.forceInlinePlayback(controller);
    if (session.playing && !session.playbackCompleted) {
      await YoutubeWebViewBridge.play(controller);
    }
  }

  void stopPolling() => _pollLoop.stop();

  void _bumpVerifyGeneration() => _verifyGeneration++;
}
