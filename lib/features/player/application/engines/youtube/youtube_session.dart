/// Playback state and broadcast streams for [YoutubePlayerEngine].
library;

import 'dart:async';

import 'package:flutter/material.dart';

/// Owns YouTube open state, transport snapshot, and engine event streams.
class YoutubeSession {
  YoutubeSession();

  final StreamController<Duration> positionCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<Duration> durationCtrl =
      StreamController<Duration>.broadcast();
  final StreamController<bool> playingCtrl = StreamController<bool>.broadcast();
  final StreamController<bool> bufferingCtrl =
      StreamController<bool>.broadcast();
  final StreamController<void> completedCtrl =
      StreamController<void>.broadcast();

  final GlobalKey webViewHostKey = GlobalKey();
  final ValueNotifier<int> mountTick = ValueNotifier(0);
  final Stream<double> aspectStream = Stream<double>.value(16 / 9);

  String videoId = '';
  String? posterUrl;
  bool mountRequested = false;
  bool webViewMounted = false;
  bool loggedFirstPlaying = false;
  bool watchPageLoadStopReceived = false;
  bool awaitingColdInitialNavigation = false;
  bool nonWatchRecoveryScheduled = false;
  bool disposed = false;
  bool playbackCompleted = false;
  bool firstBufferingOffReceived = false;

  bool playing = false;
  bool buffering = true;
  bool tapToPlayHintActive = false;

  Timer? _tapToPlayHintTimer;
  static const Duration _tapToPlayHintDelay = Duration(milliseconds: 1200);

  Duration lastPosition = Duration.zero;
  Duration lastDuration = Duration.zero;

  double volumeNormalized = 1;
  double? pendingSeekSeconds;

  int pausedPollStreak = 0;
  static const int pauseConfirmPollTicks = 3;

  Stopwatch? initStopwatch;

  Stream<Duration> get position => positionCtrl.stream;
  Stream<Duration> get duration => durationCtrl.stream;
  Stream<bool> get playingStream => playingCtrl.stream;
  Stream<bool> get bufferingStream => bufferingCtrl.stream;
  Stream<void> get completed => completedCtrl.stream;

  bool get shouldMountWebView => mountRequested && !disposed;

  ({bool playing, bool buffering}) get transportSnapshot =>
      (playing: playing, buffering: buffering);

  void setPosterUrl(String? url) => posterUrl = url;

  /// Transitions [playbackCompleted] to true and emits a [completed] event.
  /// Idempotent — only the first call emits; subsequent calls are a no-op.
  /// Callers that reset [playbackCompleted] to false (e.g. [resetForOpen])
  /// re-arm the emission for the next end-of-media.
  void markCompleted() {
    if (playbackCompleted) return;
    playbackCompleted = true;
    if (!disposed && !completedCtrl.isClosed) {
      completedCtrl.add(null);
    }
  }

  void resetForOpen(String newVideoId) {
    _cancelHint();
    tapToPlayHintActive = false;
    loggedFirstPlaying = false;
    watchPageLoadStopReceived = false;
    awaitingColdInitialNavigation = false;
    nonWatchRecoveryScheduled = false;
    firstBufferingOffReceived = false;
    videoId = newVideoId;
    playbackCompleted = false;
    emitBuffering(true);
    emitPlaying(false);
    emitPosition(Duration.zero);
    emitDuration(Duration.zero);
  }

  void resetForClear({bool keepMounted = false}) {
    _cancelHint();
    tapToPlayHintActive = false;
    videoId = '';
    mountRequested = keepMounted;
    playbackCompleted = false;
    watchPageLoadStopReceived = false;
    awaitingColdInitialNavigation = false;
    nonWatchRecoveryScheduled = false;
    emitPlaying(false);
    emitBuffering(false);
    emitPosition(Duration.zero);
    mountTick.value++;
  }

  void requestMount() {
    if (disposed) return;
    // Idempotent: re-entrant calls (e.g. loading stage + open coordinator)
    // must not notify [mountTick] again — that can hit ValueListenableBuilder
    // listeners during an ancestor build (setState-during-build).
    if (mountRequested) return;
    mountRequested = true;
    mountTick.value++;
  }

  void emitPosition(Duration d) {
    if (disposed || positionCtrl.isClosed) return;
    if (d == lastPosition) return;
    lastPosition = d;
    positionCtrl.add(d);
  }

  void emitDuration(Duration d) {
    if (disposed || durationCtrl.isClosed) return;
    if (d == lastDuration) return;
    lastDuration = d;
    durationCtrl.add(d);
  }

  void emitPlaying(bool v) {
    if (disposed || playingCtrl.isClosed) return;
    if (v == playing) return;
    playing = v;
    playingCtrl.add(v);
    if (v) {
      _cancelHint();
      if (tapToPlayHintActive) {
        tapToPlayHintActive = false;
        mountTick.value++;
      }
    }
  }

  void emitBuffering(bool v) {
    if (disposed || bufferingCtrl.isClosed) return;
    if (v == buffering) return;
    buffering = v;
    bufferingCtrl.add(v);
    if (!v && !firstBufferingOffReceived) {
      firstBufferingOffReceived = true;
      mountTick.value++;
    }
    if (v) {
      _cancelHint();
      if (tapToPlayHintActive) {
        tapToPlayHintActive = false;
        mountTick.value++;
      }
    } else {
      _scheduleHint();
    }
  }

  void _scheduleHint() {
    if (loggedFirstPlaying || disposed) return;
    _tapToPlayHintTimer?.cancel();
    _tapToPlayHintTimer = Timer(_tapToPlayHintDelay, () {
      _tapToPlayHintTimer = null;
      if (disposed || loggedFirstPlaying || playing || buffering) return;
      if (!tapToPlayHintActive) {
        tapToPlayHintActive = true;
        mountTick.value++;
      }
    });
  }

  void _cancelHint() {
    _tapToPlayHintTimer?.cancel();
    _tapToPlayHintTimer = null;
  }

  void logInitPhase(String phase, void Function(String message) log) {
    final ms = initStopwatch?.elapsedMilliseconds;
    final message = 'youtube init $phase${ms != null ? ' +${ms}ms' : ''}';
    if (phase == 'load_stop' || phase == 'first_playing') {
      log(message);
    }
  }

  Future<void> closeStreams() async {
    _cancelHint();
    disposed = true;
    mountRequested = false;
    mountTick.value++;
    await positionCtrl.close();
    await durationCtrl.close();
    await playingCtrl.close();
    await bufferingCtrl.close();
    await completedCtrl.close();
  }
}
