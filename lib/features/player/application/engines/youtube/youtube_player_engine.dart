/// YouTube playback via mobile watch WebView + HTML5 `<video>` (ADR-0015).
library;

import 'dart:async';

import 'package:flutter/foundation.dart'
    show defaultTargetPlatform, TargetPlatform;
import 'package:flutter/material.dart' hide RepeatMode;
import 'package:flutter/services.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/platform/linux_platform_availability.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_poster.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'youtube_session.dart';
import 'youtube_webview_controller.dart';
import 'youtube_webview_host.dart';
import 'youtube_webview_bridge.dart';

final _logYoutube = logNamed('YouTubePlayerEngine');

/// See [YoutubeWebViewBridge.watchUri] — not iframe embed.
class YoutubePlayerEngine implements PlayerEngine {
  YoutubePlayerEngine() : _session = YoutubeSession() {
    _webView = YoutubeWebViewController(
      session: _session,
      onStallRecovery: () => _webView.recoverStalledPlayback(),
      onLogInitPhase: (phase) => _session.logInitPhase(phase, _logYoutube.info),
    );
  }

  final YoutubeSession _session;
  late final YoutubeWebViewController _webView;

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
    _session.requestMount();
    _logInitPhase('mount_requested');
  }

  /// Completes when the WebView is mounted or [timeout] elapses.
  Future<bool> _awaitWebViewMounted({
    Duration timeout = const Duration(seconds: 8),
  }) async {
    _ensureWebViewAttached();
    if (_session.webViewMounted) return true;
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (_session.webViewMounted) return true;
      await Future<void>.delayed(const Duration(milliseconds: 40));
    }
    return _session.webViewMounted;
  }

  @override
  Future<void> awaitSurfaceReady() => _awaitWebViewMounted().then((_) {});

  @override
  Future<void> teardownAfterClear({required bool keepSurfaceMounted}) =>
      _webView.idleAfterClear(keepMounted: keepSurfaceMounted);

  Widget _buildWebViewHost() {
    return YoutubeWebViewHost(
      key: _session.webViewHostKey,
      controller: _webView,
      currentVideoId: () => _session.videoId,
    );
  }

  @override
  Future<void> open(PlayableSource source) async {
    if (!youtubeEngineAvailableOnLinux &&
        defaultTargetPlatform == TargetPlatform.linux) {
      throw UnsupportedError(
        'YouTube is not yet available on Linux — coming soon '
        '(ADR-0048, R1 / R6: webview2gtk-4.0 dependency).',
      );
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
  Widget buildVideoStage({
    required BuildContext context,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const SizedBox.shrink();
    }

    return StreamBuilder<bool>(
      stream: buffering,
      initialData: _session.buffering,
      builder: (context, snapshot) {
        final showPoster = snapshot.data ?? _session.buffering;
        return ValueListenableBuilder<int>(
          valueListenable: _session.mountTick,
          builder: (context, _, _) {
            return Stack(
              fit: StackFit.expand,
              children: [
                const ColoredBox(color: Colors.black),
                if (_session.shouldMountWebView) _buildWebViewHost(),
                if (_session.tapToPlayHintActive && !showPoster)
                  _YoutubeTapToPlayHint(
                    label:
                        AppLocalizations.of(context)?.youtubeTapToPlayHint ??
                        'Tap to play',
                  ),
                YoutubeVideoPoster(
                  primaryUrl: _session.posterUrl,
                  visible: showPoster,
                ),
              ],
            );
          },
        );
      },
    );
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
        // In-flight latch + stale-buffering clear live in the transition.
        _session.beginUserPlay();
        _logYoutube.fine(
          'youtube playOrPause command vid=${_session.videoId} '
          'sessionPlaying=${_session.playing} '
          'buffering=${_session.buffering}',
        );
        try {
          await YoutubeWebViewBridge.playOrPause(controller);
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
        _session.emitBuffering(true);
        _session.emitPlaying(false);
        _webView.onExplicitPlayAttempt();
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

class _YoutubeTapToPlayHint extends StatelessWidget {
  const _YoutubeTapToPlayHint({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    // IgnorePointer: empty regions must still reach the WebView so a real
    // user gesture can satisfy platform autoplay policy.
    return IgnorePointer(
      ignoring: true,
      child: ColoredBox(
        color: Colors.black45,
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.play_circle_outline,
                size: 64,
                color: Colors.white70,
              ),
              const SizedBox(height: 12),
              Text(
                label,
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.white70, fontSize: 16),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
