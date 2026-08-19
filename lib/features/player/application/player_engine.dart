/// Abstraction over playback backends: [MediaKitPlayerEngine] (default) and [YouTubePlayerEngine].
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:media_kit_video/media_kit_video.dart';

import 'package:enjoy_player/features/player/application/player_engine_constants.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';

/// Contract implemented by [MediaKitPlayerEngine] / [YouTubePlayerEngine]; fakes in tests.
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

  /// Current transport flags for seeding [StreamProvider]s.
  ({bool playing, bool buffering}) get transportSnapshot;

  /// Display aspect ratio for letterboxing (width / height).
  Stream<double> get videoAspectRatioStream;

  /// When false, [PlayerSurfaceHost] omits [buildVideoStage] while parked
  /// off-screen. MediaKit's Android `Texture` / Surface stays black if it is
  /// first laid out off-screen; YouTube's WebView must stay mounted.
  bool get keepSurfaceWhenParked;

  Widget buildVideoStage({
    required BuildContext context,
    required double maxWidth,
    required double maxHeight,
  });

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

  mk.Player get _player => __player ??= mk.Player();

  mk.Player get player => _player;

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
  Stream<Duration> get position => _player.stream.position;

  /// [_player.stream.duration] is a broadcast stream that does not replay.
  /// [PlayerController] subscribes after `open` + other awaits, so the first
  /// duration event can be missed on Android. Seed from [_player.state.duration].
  @override
  Stream<Duration> get duration {
    return Stream.multi((controller) {
      final current = _player.state.duration;
      if (current > Duration.zero) {
        controller.add(current);
      }
      final sub = _player.stream.duration.listen(
        controller.add,
        onError: controller.addError,
        onDone: controller.close,
      );
      controller.onCancel = sub.cancel;
    });
  }

  @override
  Stream<bool> get playing => _player.stream.playing;

  @override
  Stream<bool> get buffering => _player.stream.buffering;

  @override
  Stream<void> get completed => _player.stream.completed;

  @override
  Stream<mk.Tracks>? get mkTracksStream => _player.stream.tracks;

  @override
  bool get supportsVideoPosterCapture => true;

  @override
  bool get supportsSubtitleDisabling => true;

  @override
  ({bool playing, bool buffering}) get transportSnapshot =>
      (playing: _player.state.playing, buffering: _player.state.buffering);

  @override
  bool get keepSurfaceWhenParked => false;

  @override
  Stream<double> get videoAspectRatioStream => _player.stream.videoParams
      .map((vp) => aspectRatioFromVideoParams(vp, _player.state))
      .distinct((a, b) => (a - b).abs() < kAspectRatioEpsilon);

  @override
  Widget buildVideoStage({
    required BuildContext context,
    required double maxWidth,
    required double maxHeight,
  }) {
    if (maxWidth <= 0 || maxHeight <= 0) {
      return const SizedBox.shrink();
    }

    // Fill the host slot and let [Video] letterbox. An outer [ClipRect] plus a
    // child taller than the slot makes Android's Surface/Texture stay black
    // until a later layout (transcript splitter / rotation).
    return ColoredBox(
      color: Colors.black,
      child: _MediaKitVideoStage(
        controller: videoController,
        maxWidth: maxWidth,
        maxHeight: maxHeight,
      ),
    );
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
    // layout. [_MediaKitVideoStage] creates the controller on first build.
  }

  @override
  Future<void> dispose() async {
    await __player?.dispose();
    __player = null;
  }
}

/// Mounts media_kit [Video] and relayouts it once the native texture exists.
///
/// A kick on the first Flutter frame is too early — [Texture] is still a
/// 1×1 placeholder, so the layout is a no-op. Dragging the transcript splitter
/// works because it changes the viewport *after* frames are flowing. Listen
/// for texture id/rect (and first-frame) and then pulse [Video] width/height.
class _MediaKitVideoStage extends StatefulWidget {
  const _MediaKitVideoStage({
    required this.controller,
    required this.maxWidth,
    required this.maxHeight,
  });

  final VideoController controller;
  final double maxWidth;
  final double maxHeight;

  @override
  State<_MediaKitVideoStage> createState() => _MediaKitVideoStageState();
}

class _MediaKitVideoStageState extends State<_MediaKitVideoStage> {
  var _nudge = false;
  var _kicked = false;

  @override
  void initState() {
    super.initState();
    widget.controller.id.addListener(_onTexture);
    widget.controller.rect.addListener(_onTexture);
    _onTexture();
    unawaited(_kickAfterFirstFrame());
  }

  @override
  void didUpdateWidget(covariant _MediaKitVideoStage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Loading 16:9 → side-by-side chrome is a large viewport change. The first
    // kick already ran; without another pulse the Texture stays black until
    // the user resizes the window / splitter.
    final dw = (oldWidget.maxWidth - widget.maxWidth).abs();
    final dh = (oldWidget.maxHeight - widget.maxHeight).abs();
    if (dw > kVideoTextureKickMinViewportDelta ||
        dh > kVideoTextureKickMinViewportDelta) {
      _kicked = false;
      _scheduleKick();
    }
  }

  @override
  void dispose() {
    widget.controller.id.removeListener(_onTexture);
    widget.controller.rect.removeListener(_onTexture);
    super.dispose();
  }

  Future<void> _kickAfterFirstFrame() async {
    try {
      await widget.controller.waitUntilFirstFrameRendered;
    } on Object {
      return;
    }
    if (!mounted) return;
    _scheduleKick();
  }

  void _onTexture() {
    final id = widget.controller.id.value;
    final rect = widget.controller.rect.value;
    if (id == null || rect == null || rect.width <= 1 || rect.height <= 1) {
      return;
    }
    _scheduleKick();
  }

  void _scheduleKick() {
    if (_kicked) return;
    WidgetsBinding.instance.addPostFrameCallback((_) => _kick());
  }

  void _kick() {
    if (!mounted || _kicked) return;
    _kicked = true;
    setState(() => _nudge = true);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() => _nudge = false);
    });
  }

  @override
  Widget build(BuildContext context) {
    final inset = _nudge ? kVideoTextureKickInset : 0.0;
    final w = widget.maxWidth > inset
        ? widget.maxWidth - inset
        : widget.maxWidth;
    final h = widget.maxHeight > inset
        ? widget.maxHeight - inset
        : widget.maxHeight;
    return ExcludeSemantics(
      child: Video(
        controller: widget.controller,
        controls: null,
        width: w,
        height: h,
        fit: BoxFit.contain,
        fill: Colors.black,
        subtitleViewConfiguration: const SubtitleViewConfiguration(
          visible: false,
        ),
      ),
    );
  }
}
