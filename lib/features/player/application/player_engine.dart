/// Abstraction over playback backends: [MediaKitPlayerEngine] (default) and [YouTubePlayerEngine].
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:enjoy_player/data/files/security_scoped_bookmark.dart';
import 'package:enjoy_player/features/player/application/player_engine_constants.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';

/// Contract implemented by [MediaKitPlayerEngine] / [YouTubePlayerEngine]; fakes in tests.
///
/// Transport + streams + capabilities only. Widget building is *not* part of
/// the contract: the presentation layer mounts a per-engine stage for the
/// active engine (see `buildPlayerVideoStage`, issue #664) and reads the
/// non-widget inputs each concrete engine publishes.
abstract class PlayerEngine {
  Stream<Duration> get position;

  Stream<Duration> get duration;

  Stream<bool> get playing;

  Stream<bool> get buffering;

  /// Fires when the current media reaches the end (ADR-0044).
  ///
  /// - **MediaKit**: forwards `media_kit`'s `Player.stream.completed`.
  /// - **YouTube**: synthesized from the HTML5 `<video>` `ended` event / poll
  ///   loop at ~250 ms resolution (ADR-0015).
  ///
  /// May fire duplicate or late events across seeks; callers must guard with a
  /// generation counter (see `PlayerController._playbackGen`).
  Stream<void> get completed;

  /// libmpv / media_kit subtitle tracks; `null` when unsupported (e.g. WebView).
  Stream<mk.Tracks>? get mkTracksStream;

  /// Whether [screenshot] can produce stored video thumbnails (false for WebView).
  bool get supportsVideoPosterCapture;

  /// Whether [disableRenderedSubtitles] does anything. YouTube / WebView
  /// engines have no embedded subtitle track to disable.
  bool get supportsSubtitleDisabling;

  /// Whether this engine plays YouTube sources (WebView-backed). Capability
  /// flag so call sites never need to know the concrete engine class.
  bool get supportsYouTubePlayback;

  /// Completes when the engine's video surface is usable after `open`.
  /// Native engines are ready immediately; the WebView engine awaits mount.
  Future<void> awaitSurfaceReady();

  /// Completes when this engine's platform view has been dropped (or was
  /// never mounted). Used by the YouTube → MediaKit swap so mpv is not
  /// allocated while InAppWebView is still tearing down.
  Future<void> awaitSurfaceDetached();

  /// Allows native backend allocation (MediaKit `[Player]`). YouTube is a
  /// no-op. Must run *after* the previous engine's surface has detached so
  /// the first mpv construct cannot race WebView destroy.
  void prepareNativeBackend();

  /// Poster shown while the surface is loading/buffering; `null` for engines
  /// that render decoded frames directly.
  String? get posterUrl;

  void setPosterUrl(String? url);

  /// Id of the currently-open YouTube video; empty when not applicable.
  String get currentVideoId;

  /// Marks the start of open-time init instrumentation. Engines without init
  /// timing treat this as a no-op.
  void markOpenTimingStart();

  /// Clears any end-of-media latch so the next [play] drives the loaded
  /// media directly instead of restarting from the beginning. Engines
  /// without a completion latch treat this as a no-op (ADR-0044).
  void resetCompletionFlag();

  /// Teardown used by `PlayerController.clear`. The WebView engine idles and
  /// keeps its process alive (optionally still mounted); native engines stop.
  Future<void> teardownAfterClear({required bool keepSurfaceMounted});

  /// Current transport flags for seeding [StreamProvider]s.
  ({bool playing, bool buffering}) get transportSnapshot;

  /// Display aspect ratio for letterboxing (width / height).
  Stream<double> get videoAspectRatioStream;

  /// When false, [PlayerSurfaceHost] unmounts the engine's stage while parked
  /// off-screen. MediaKit's Android `Texture` / Surface stays black if it is
  /// first laid out off-screen; YouTube's WebView must stay mounted.
  bool get keepSurfaceWhenParked;

  Future<void> open(PlayableSource source);

  Future<void> disableRenderedSubtitles();

  Future<void> seek(Duration target);

  Future<void> setRate(double rate);

  /// [volume] is 0.0–1.0 (mapped to player units in implementation).
  Future<void> setVolumeNormalized(double volume);

  Future<void> playOrPause();

  Future<void> play();

  Future<void> pause();

  Future<void> stop();

  /// Encoded frame capture (`image/jpeg`, `image/png`, or raw when [format] is null).
  Future<Uint8List?> screenshot({String? format});

  /// YouTube: attach the WebView. MediaKit: no-op — [VideoController] is
  /// created when the on-screen [Video] stage builds.
  void warmVideoSurface();

  Future<void> dispose();
}

double aspectRatioFromVideoParams(mk.VideoParams vp, mk.PlayerState state) {
  if (vp.aspect != null && vp.aspect! > 0) {
    return vp.aspect!;
  }
  final ww = vp.dw ?? vp.w ?? state.width;
  final hh = vp.dh ?? vp.h ?? state.height;
  if (ww != null && hh != null && ww > 0 && hh > 0) {
    return ww / hh;
  }
  return 16 / 9;
}

/// Single [mk.Player] instance — ADR-0003 / ADR-0015.
///
/// The native mpv player is constructed lazily on first access (not in the
/// constructor) so swapping between YouTube and local media does not stall the
/// main isolate with an unnecessary native allocation (issue #283, P8).
class MediaKitPlayerEngine implements PlayerEngine {
  MediaKitPlayerEngine();

  mk.Player? __player;

  /// Set by [prepareNativeBackend] after the previous platform view has
  /// detached. Only the video stage consults it (via [nativeBackendAllowed]):
  /// the stream/snapshot getters read `__player` without ever constructing,
  /// and the command path ([_player]) allocates mpv unconditionally — the
  /// WebView-detach wait lives in the swap (player_engine_binding), not in a
  /// getter (2026-08-30 field report, issue #658).
  var _nativeBackendAllowed = false;

  /// Whether [prepareNativeBackend] has approved native allocation. Read by
  /// the MediaKit video stage (`presentation/widgets/media_kit_video_stage.dart`)
  /// so it mounts a plain black placeholder — never a [VideoController] —
  /// until the previous engine's WebView has detached.
  bool get nativeBackendAllowed => _nativeBackendAllowed;

  mk.Player get _player => __player ??= mk.Player();

  mk.Player get player => _player;

  /// Handle for the currently-held macOS security-scoped resource grant, if
  /// any. Owned by this engine and paired with [releaseBookmark] before the
  /// next `open()` or on `dispose()`. See ADR-0060.
  int? _scopeToken;

  VideoController? _videoController;

  static VideoControllerConfiguration get _videoControllerConfiguration {
    if (Platform.isAndroid || Platform.isIOS) {
      return const VideoControllerConfiguration();
    }
    // Desktop: software output. HW textures can stay black until a later
    // Flutter layout (Windows D3D, macOS OpenGL, Linux EGL — ADR-0048).
    return const VideoControllerConfiguration(
      width: kVideoControllerWidth,
      height: kVideoControllerHeight,
      hwdec: 'auto-safe',
      enableHardwareAcceleration: false,
    );
  }

  VideoController get videoController {
    return _videoController ??= VideoController(
      _player,
      configuration: _videoControllerConfiguration,
    );
  }

  @override
  Stream<Duration> get position =>
      __player?.stream.position ?? const Stream<Duration>.empty();

  /// [_player.stream.duration] is a broadcast stream that does not replay.
  /// [PlayerController] subscribes after `open` + other awaits, so the first
  /// duration event can be missed on Android. Seed from [_player.state.duration].
  @override
  Stream<Duration> get duration {
    final player = __player;
    if (player == null) return const Stream<Duration>.empty();
    return Stream.multi((controller) {
      final current = player.state.duration;
      if (current > Duration.zero) {
        controller.add(current);
      }
      final sub = player.stream.duration.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<bool> get playing =>
      __player?.stream.playing ?? const Stream<bool>.empty();

  @override
  Stream<bool> get buffering =>
      __player?.stream.buffering ?? const Stream<bool>.empty();

  @override
  Stream<void> get completed =>
      __player?.stream.completed ?? const Stream<void>.empty();

  @override
  Stream<mk.Tracks>? get mkTracksStream => __player?.stream.tracks;

  @override
  bool get supportsVideoPosterCapture => true;

  @override
  bool get supportsSubtitleDisabling => true;

  @override
  bool get supportsYouTubePlayback => false;

  @override
  Future<void> awaitSurfaceReady() async {}

  @override
  Future<void> awaitSurfaceDetached() async {}

  @override
  void prepareNativeBackend() {
    _nativeBackendAllowed = true;
  }

  @override
  String? get posterUrl => null;

  @override
  void setPosterUrl(String? url) {}

  @override
  String get currentVideoId => '';

  @override
  void markOpenTimingStart() {}

  @override
  void resetCompletionFlag() {}

  @override
  Future<void> teardownAfterClear({required bool keepSurfaceMounted}) => stop();

  @override
  ({bool playing, bool buffering}) get transportSnapshot {
    final player = __player;
    if (player == null) {
      return (playing: false, buffering: false);
    }
    return (playing: player.state.playing, buffering: player.state.buffering);
  }

  @override
  bool get keepSurfaceWhenParked => false;

  @override
  Stream<double> get videoAspectRatioStream {
    final player = __player;
    if (player == null) return const Stream<double>.empty();
    return player.stream.videoParams
        .map((vp) => aspectRatioFromVideoParams(vp, player.state))
        .distinct((a, b) => (a - b).abs() < kAspectRatioEpsilon);
  }

  @override
  Future<void> open(PlayableSource source) async {
    final uri = switch (source) {
      LocalFilePlayableSource(:final uri) => uri,
      RemoteUrlPlayableSource(:final uri) => uri,
      YoutubePlayableSource() => throw UnsupportedError(
        'MediaKitPlayerEngine cannot open YouTube',
      ),
    };
    // Release any prior scope before we open the new source — libmpv will
    // read from the URL immediately, so the grant must cover the new path.
    final previousToken = _scopeToken;
    if (previousToken != null) {
      _scopeToken = null;
      await SecurityScopedBookmarkChannel.releaseBookmark(previousToken);
    }
    if (source is LocalFilePlayableSource) {
      _scopeToken = source.scopeToken;
    }
    await _player.open(mk.Media(uri));
  }

  @override
  Future<void> disableRenderedSubtitles() =>
      _player.setSubtitleTrack(mk.SubtitleTrack.no());

  @override
  Future<void> seek(Duration target) => _player.seek(target);

  @override
  Future<void> setRate(double rate) => _player.setRate(rate);

  @override
  Future<void> setVolumeNormalized(double volume) =>
      _player.setVolume(volume.clamp(0, 1) * kVolumeScale);

  @override
  Future<void> playOrPause() => _player.playOrPause();

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<Uint8List?> screenshot({String? format}) =>
      _player.screenshot(format: format);

  @override
  void warmVideoSurface() {
    // Do not construct [VideoController] here. media_kit binds the native
    // texture one frame after [VideoController] is created; if that happens
    // with no [Video] widget mounted, Windows/Android stay black until a later
    // layout. The MediaKit video stage creates the controller on first
    // build.
  }

  @override
  Future<void> dispose() async {
    final token = _scopeToken;
    if (token != null) {
      _scopeToken = null;
      await SecurityScopedBookmarkChannel.releaseBookmark(token);
    }
    await __player?.dispose();
    __player = null;
  }
}
