/// YouTube playback via mobile watch WebView + HTML5 `<video>` (ADR-0015).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart' as mk;

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/platform/linux_platform_availability.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';
import 'package:enjoy_player/features/player/domain/youtube_playback_unavailable_exception.dart';
import 'youtube_session.dart';
import 'youtube_webview_controller.dart';
import 'youtube_webview_bridge.dart';

final _logYoutube = logNamed('YouTubePlayerEngine');

/// See [YoutubeWebViewBridge.watchUri] — not iframe embed.
class YoutubePlayerEngine implements PlayerEngine {
  /// [session] is injectable so tests can drive the mount signal without a
  /// WebView backend.
  YoutubePlayerEngine({YoutubeSession? session})
    : _session = session ?? YoutubeSession() {
    _webView = YoutubeWebViewController(
      session: _session,
      onStallRecovery: () => _webView.recoverStalledPlayback(),
      onLogInitPhase: (phase) => _session.logInitPhase(phase, _logYoutube.info),
    );
  }

  final YoutubeSession _session;

  /// Last logged video-stage size (park/unpark marker — see
  /// [noteStageViewportSize]).
  double? _lastStageSizeWidth;
  double? _lastStageSizeHeight;
  late final YoutubeWebViewController _webView;

  /// Session state the video stage renders from (poster + mount latches,
  /// buffering snapshot, WebView host key). The stage lives in the
  /// presentation layer (issue #664); this is its non-widget input.
  YoutubeSession get session => _session;

  /// WebView lifecycle owner the video stage mounts (one per engine,
  /// ADR-0015).
  YoutubeWebViewController get webViewLifecycle => _webView;

  /// Notifies the engine that its video stage laid out at [width]×[height].
  ///
  /// Diagnostic marker + focus re-assert when the stage size actually
  /// changes. ADR-0066 parks overlays off-corner; YouTube keeps its last
  /// on-screen size (a 320×180 shrink was the play-then-pause stimulus —
  /// m.youtube.com treats 320 px as a compact-player breakpoint and flushes
  /// ABR). A remaining size change is therefore a real layout jump
  /// (rotation / split). Parking can still clear view focus (the plugin
  /// exposes no requestFocus); re-assert the pinned page focus. Idempotent,
  /// no-op without a live controller.
  void noteStageViewportSize({required double width, required double height}) {
    if (width == _lastStageSizeWidth && height == _lastStageSizeHeight) return;
    _lastStageSizeWidth = width;
    _lastStageSizeHeight = height;
    _logYoutube.fine(
      'youtube stage size ${width.round()}x${height.round()} '
      'vid=${_session.videoId}',
    );
    unawaited(YoutubeWebViewBridge.refocusWindow(_webView.webController));
  }

  @override
  String get currentVideoId => _session.videoId;

  @override
  String? get posterUrl => _session.posterUrl;

  @override
  bool get supportsYouTubePlayback => true;

  @override
  Stream<Duration> get position => _session.position;

  @override
  Stream<Duration> get duration => _session.duration;

  @override
  Stream<bool> get playing => _session.playingStream;

  @override
  Stream<bool> get buffering => _session.bufferingStream;

  @override
  Stream<void> get completed => _session.completed;

  @override
  Stream<mk.Tracks>? get mkTracksStream => null;

  @override
  bool get supportsVideoPosterCapture => false;

  @override
  bool get supportsSubtitleDisabling => false;

  @override
  bool get keepSurfaceWhenParked => true;

  @override
  ({bool playing, bool buffering}) get transportSnapshot =>
      _session.transportSnapshot;

  @override
  Stream<double> get videoAspectRatioStream => _session.aspectStream;

  @override
  void setPosterUrl(String? url) => _session.setPosterUrl(url);

  /// Clears the session's end-of-media latch so the next
  /// [play] call drives the `<video>` directly instead of reloading the watch
  /// page. Used by the deterministic completion loop (ADR-0044) to seek + play
  /// from an arbitrary position after end-of-media.
  @override
  void resetCompletionFlag() => _session.resetCompletionFlag();

  @override
  void markOpenTimingStart() => _webView.markOpenTimingStart();

  void _ensureWebViewAttached() {
    // ADR-0048: on opted-out platforms never request a mount — constructing
    // InAppWebView without a platform backend asserts on every rebuild.
    if (youTubeEngineOptedOutHere) return;
    _session.requestMount();
    _logInitPhase('mount_requested');
  }

  /// Completes when the WebView is mounted or [timeout] elapses.
  ///
  /// The mount is signalled by [YoutubeSession.noteWebViewMounted] (push from
  /// `onWebViewCreated`), so waiting costs no periodic timer on the UI thread
  /// — the 40 ms flag-poll used to sit on the `awaitSurfaceReady` critical
  /// path of every open (issue #661). [timeout] only bounds a surface that
  /// never mounts; the answer is still read off the session flag, exactly as
  /// before.
  Future<bool> _awaitWebViewMounted({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    if (youTubeEngineOptedOutHere) return false;
    _ensureWebViewAttached();
    if (_session.webViewMounted) return true;
    await _session.awaitWebViewMounted().timeout(timeout, onTimeout: () {});
    return _session.webViewMounted;
  }

  @override
  Future<void> awaitSurfaceReady() => _awaitWebViewMounted().then((_) {});

  @override
  Future<void> awaitSurfaceDetached() => _session.awaitSurfaceDetached();

  @override
  void prepareNativeBackend() {}

  @override
  Future<void> teardownAfterClear({required bool keepSurfaceMounted}) =>
      _webView.idleAfterClear(keepMounted: keepSurfaceMounted);

  @override
  Future<void> open(PlayableSource source) async {
    if (youTubeEngineOptedOutHere) {
      // Typed so the player surface can show the ADR-0048 "coming soon"
      // message instead of the generic open-failure body. The open
      // coordinator gates Linux YouTube opens before any engine swap; this
      // guard is defense in depth.
      throw const YouTubePlaybackUnavailableException.linuxOptedOut();
    }
    if (source is! YoutubePlayableSource) {
      throw UnsupportedError(
        'YoutubePlayerEngine requires YoutubePlayableSource',
      );
    }
    _webView.prepareWatchReload(resetFirstPlaying: true);
    _session.resetForOpen(source.videoId);
    _session.requestMount();
    if (!_session.awaitingColdInitialNavigation) {
      await _webView.loadCurrentVideoIfAttached();
    }
  }

  @override
  Future<void> disableRenderedSubtitles() async {}

  @override
  Future<void> seek(Duration target) async {
    await YoutubeWebViewBridge.seekToSeconds(
      _webView.webController,
      target.inMilliseconds / 1000.0,
    );
  }

  @override
  Future<void> setRate(double rate) async {
    await YoutubeWebViewBridge.setPlaybackRate(_webView.webController, rate);
  }

  @override
  Future<void> setVolumeNormalized(double volume) async {
    final applied = _session.storeVolumeNormalized(volume);
    await YoutubeWebViewBridge.setVolume(_webView.webController, applied);
  }

  @override
  Future<void> playOrPause() async {
    // Never branch on [_session.playing] alone — DOM can already be paused
    // while Dart still reports playing (pause confirmation lags ~750 ms).
    // After end-of-media, force the restart path instead of a DOM toggle.
    final restart = decideYouTubePlayRestart(
      playbackCompleted: _session.playbackCompleted,
    );
    switch (restart) {
      case RestartFromBeginning():
        await play();
      case ResumePlayback():
        final controller = _webView.webController;
        if (controller == null) {
          _logYoutube.warning(
            'youtube playOrPause ignored without WebView '
            'vid=${_session.videoId}',
          );
          return;
        }
        _webView.onExplicitPlayAttempt();
        _logYoutube.fine(
          'youtube playOrPause command vid=${_session.videoId} '
          'sessionPlaying=${_session.playing} '
          'buffering=${_session.buffering}',
        );
        try {
          final domDirection = await YoutubeWebViewBridge.playOrPause(
            controller,
          );
          // Latch from the direction the DOM actually took (D9) — never
          // from [_session.playing], which lags DOM pauses by up to ~750 ms.
          // Classifying from stale session state armed/consumed opposite to
          // the command really issued in exactly the windows where it
          // matters: a page-corrected pause (session still playing → toggle
          // plays → budget wrongly consumed → recovery-hint instead of the
          // silent retry), and the mirror race after the D8 retry's own
          // play (session still not-playing → toggle pauses → budget
          // wrongly armed → deliberate pause auto-resumed).
          switch (decideTransportToggleLatch(domDirection: domDirection)) {
            case ArmRetryBudget():
              _session.beginUserPlay();
            case ConsumeRetryBudget():
              _session.noteUserPauseCommand();
            case LeaveRetryBudget():
              break;
          }
          if (domDirection != null) {
            _logYoutube.fine(
              'youtube playOrPause direction=$domDirection '
              'vid=${_session.videoId}',
            );
          }
        } on Object catch (error, stackTrace) {
          _session.emitBuffering(false);
          _logYoutube.warning(
            'youtube playOrPause command failed vid=${_session.videoId}',
            error,
            stackTrace,
          );
        }
    }
  }

  @override
  Future<void> play() async {
    final restart = decideYouTubePlayRestart(
      playbackCompleted: _session.playbackCompleted,
    );
    switch (restart) {
      case RestartFromBeginning():
        _webView.prepareWatchReload(resetFirstPlaying: true);
        _session.emitPlaying(false);
        _webView.onExplicitPlayAttempt();
        // A replay after end-of-media is a play-intent command like any
        // other: the fresh document can be page-corrected back to paused
        // inside the immediate window, and the D8 retry must cover it.
        // Armed before emitBuffering(true) — beginUserPlay clears stale
        // buffering, which here is the state we are about to arm.
        _session.beginUserPlay();
        _session.emitBuffering(true);
        await _webView.loadCurrentVideoIfAttached();
      case ResumePlayback():
        final controller = _webView.webController;
        if (controller == null) {
          _logYoutube.warning(
            'youtube play ignored without WebView vid=${_session.videoId}',
          );
          return;
        }
        _webView.onExplicitPlayAttempt();
        // In-flight latch + stale-buffering clear live in the transition.
        _session.beginUserPlay();
        _logYoutube.fine(
          'youtube play command vid=${_session.videoId} '
          'buffering=${_session.buffering} '
          'explicitPlay=${_session.explicitPlayAttempted}',
        );
        try {
          await YoutubeWebViewBridge.play(controller);
        } on Object catch (error, stackTrace) {
          _session.emitBuffering(false);
          _logYoutube.warning(
            'youtube play command failed vid=${_session.videoId}',
            error,
            stackTrace,
          );
        }
    }
  }

  @override
  Future<void> pause() async {
    // Pause-intent consumes the D8 retry budget — otherwise a confirmed
    // pause right after this command (still within the immediate window of
    // a fresh start) would be auto-resumed against the caller's intent.
    _session.noteUserPauseCommand();
    _logYoutube.fine('youtube pause command vid=${_session.videoId}');
    try {
      await YoutubeWebViewBridge.pause(_webView.webController);
    } on Object catch (error, stackTrace) {
      _logYoutube.warning(
        'youtube pause command failed vid=${_session.videoId}',
        error,
        stackTrace,
      );
    }
  }

  @override
  Future<void> stop() async {
    _session.noteUserPauseCommand();
    await YoutubeWebViewBridge.stop(_webView.webController);
    _session.emitPlaying(false);
    _session.emitBuffering(false);
    _session.emitPosition(Duration.zero);
    _session.resetCompletionFlag();
  }

  @override
  Future<Uint8List?> screenshot({String? format}) async => null;

  @override
  void warmVideoSurface() => _ensureWebViewAttached();

  @override
  Future<void> dispose() async {
    await _webView.dispose();
    await _session.closeStreams();
  }

  void _logInitPhase(String phase) {
    _session.logInitPhase(phase, (m) => _logYoutube.fine(m));
  }
}
