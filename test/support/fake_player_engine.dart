import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:media_kit/media_kit.dart' as mk;

import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';

/// Test double with controllable streams ([mkTracksStream] is null — no embedded extract).
class FakePlayerEngine implements PlayerEngine {
  FakePlayerEngine();

  final StreamController<Duration> _position =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> _duration =
      StreamController<Duration>.broadcast();
  final StreamController<bool> _playing = StreamController<bool>.broadcast();
  final StreamController<bool> _buffering = StreamController<bool>.broadcast();
  final StreamController<void> _completed = StreamController<void>.broadcast();

  final List<String> openUris = <String>[];
  final List<Duration> seekCalls = <Duration>[];
  int screenshotCalls = 0;
  int pauseCallCount = 0;

  /// When set, the next [seek] awaits this completer before resolving — used to
  /// hold an echo enforcement op in flight so tests can observe single-flight
  /// serialization. Captured and cleared on the first awaiting [seek], so the
  /// test completes its own [Completer] reference to release it.
  Completer<void>? seekGate;

  Uint8List? screenshotReturnValue;

  Future<void> Function()? openDelay;

  double lastVolume = -1;
  double lastRate = -1;

  void emitPosition(Duration d) {
    if (!_position.isClosed) _position.add(d);
  }

  void emitDuration(Duration d) {
    if (!_duration.isClosed) _duration.add(d);
  }

  /// Simulates a buffering transition (used by post-open readiness gates).
  void emitBuffering(bool value) {
    if (!_buffering.isClosed) _buffering.add(value);
  }

  /// Simulates end-of-media (fires the [completed] stream once).
  void emitCompleted() {
    if (!_completed.isClosed) _completed.add(null);
  }

  @override
  Stream<Duration> get position => _position.stream;

  @override
  Stream<Duration> get duration => _duration.stream;

  @override
  Stream<bool> get playing => _playing.stream;

  @override
  Stream<bool> get buffering => _buffering.stream;

  @override
  Stream<void> get completed => _completed.stream;

  @override
  Stream<mk.Tracks>? get mkTracksStream => null;

  bool supportsVideoPosterCaptureValue = true;

  @override
  bool get supportsVideoPosterCapture => supportsVideoPosterCaptureValue;

  @override
  bool get supportsSubtitleDisabling => true;

  bool supportsYouTubePlaybackValue = false;

  @override
  bool get supportsYouTubePlayback => supportsYouTubePlaybackValue;

  @override
  Future<void> awaitSurfaceReady() async {}

  /// When set, [awaitSurfaceDetached] waits on this completer.
  Completer<void>? surfaceDetachGate;

  @override
  Future<void> awaitSurfaceDetached() async {
    final gate = surfaceDetachGate;
    if (gate != null) await gate.future;
  }

  @override
  void prepareNativeBackend() {}

  String? posterUrlValue;

  @override
  String? get posterUrl => posterUrlValue;

  @override
  void setPosterUrl(String? url) {
    posterUrlValue = url;
  }

  String currentVideoIdValue = '';

  @override
  String get currentVideoId => currentVideoIdValue;

  int markOpenTimingStartCallCount = 0;

  @override
  void markOpenTimingStart() {
    markOpenTimingStartCallCount++;
  }

  int resetCompletionFlagCallCount = 0;

  @override
  void resetCompletionFlag() {
    resetCompletionFlagCallCount++;
  }

  int teardownAfterClearCallCount = 0;
  bool? lastTeardownKeepSurfaceMounted;

  @override
  Future<void> teardownAfterClear({required bool keepSurfaceMounted}) async {
    teardownAfterClearCallCount++;
    lastTeardownKeepSurfaceMounted = keepSurfaceMounted;
    await stop();
  }

  @override
  bool get keepSurfaceWhenParked => true;

  @override
  ({bool playing, bool buffering}) get transportSnapshot =>
      (playing: false, buffering: false);

  @override
  Stream<double> get videoAspectRatioStream => Stream<double>.value(16 / 9);

  @override
  Widget buildVideoStage({
    required BuildContext context,
    required double maxWidth,
    required double maxHeight,
  }) => const SizedBox.shrink();

  void _recordUriFromSource(PlayableSource source) {
    switch (source) {
      case LocalFilePlayableSource(:final uri):
        openUris.add(uri);
      case RemoteUrlPlayableSource(:final uri):
        openUris.add(uri);
      case YoutubePlayableSource(:final videoId):
        openUris.add('youtube:$videoId');
    }
  }

  @override
  Future<void> open(PlayableSource source) async {
    _recordUriFromSource(source);
    final delay = openDelay;
    if (delay != null) await delay();
  }

  @override
  Future<void> disableRenderedSubtitles() async {}

  @override
  Future<void> seek(Duration target) async {
    seekCalls.add(target);
    final gate = seekGate;
    if (gate != null) {
      seekGate = null;
      await gate.future;
    }
  }

  @override
  Future<void> setRate(double rate) async {
    lastRate = rate;
  }

  @override
  Future<void> setVolumeNormalized(double volume) async {
    lastVolume = volume;
  }

  int playOrPauseCallCount = 0;

  @override
  Future<void> playOrPause() async {
    playOrPauseCallCount++;
  }

  int playCallCount = 0;

  @override
  Future<void> play() async {
    playCallCount++;
  }

  @override
  Future<void> pause() async {
    pauseCallCount++;
  }

  @override
  Future<void> stop() async {
    stopCallCount++;
  }

  int stopCallCount = 0;

  @override
  Future<Uint8List?> screenshot({String? format}) async {
    screenshotCalls++;
    return screenshotReturnValue;
  }

  int warmVideoSurfaceCallCount = 0;

  @override
  void warmVideoSurface() {
    warmVideoSurfaceCallCount++;
  }

  /// When set, [dispose] waits on this completer before closing streams.
  Completer<void>? disposeGate;

  int disposeCallCount = 0;

  @override
  Future<void> dispose() async {
    disposeCallCount++;
    final gate = disposeGate;
    if (gate != null) await gate.future;
    await _position.close();
    await _duration.close();
    await _playing.close();
    await _buffering.close();
    await _completed.close();
  }
}
