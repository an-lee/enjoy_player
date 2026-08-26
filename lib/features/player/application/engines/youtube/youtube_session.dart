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

  /// User (or app) requested play; cancels autoplay assist and arms recovery UX.
  bool explicitPlayAttempted = false;

  /// An explicit user play has not yet resolved (playing/rejected/error).
  /// Grants the poll loop exactly one automatic retry when a pause is
  /// confirmed almost immediately after playback started — the page player
  /// state machine can "correct" a freshly started video back to paused
  /// before it settles; one retry after it settles recovers without UX.
  bool userPlayInFlight = false;

  /// First-play unmute is deferred until [currentTime] advances (or fallback).
  bool volumeRestorePending = false;
  Duration? volumeRestoreBaselinePosition;
  int progressAdvanceTicks = 0;
  static const int progressConfirmTicks = 2;
  static const Duration volumeRestoreFallback = Duration(milliseconds: 1500);

  /// Generation of the loaded watch document. Bumped on every open and watch
  /// load stop (ads reload the page into a fresh document whose `<video>`
  /// starts muted again).
  int documentGen = 0;

  /// [documentGen] for which volume was last restored, or `-1` when never.
  /// The unmute runs at most once per document: redundant programmatic
  /// unMutes are pause triggers under Chromium's autoplay gesture lock (the
  /// play-then-pause root cause), so later `playing` events in an already
  /// restored document must not touch volume at all.
  int volumeRestoredDocGen = -1;

  /// True when the current document still needs its first volume restore.
  bool get needsVolumeRestore =>
      volumeRestoredDocGen != documentGen && !disposed;

  /// Wall-clock when [emitPlaying(true)] last succeeded — for immediate-pause
  /// diagnostics (pause confirmed within this window after first playing).
  DateTime? lastPlayingAt;
  static const Duration immediatePauseWindow = Duration(seconds: 2);

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
    explicitPlayAttempted = false;
    userPlayInFlight = false;
    clearVolumeRestorePending();
    noteWatchDocumentLoaded();
    volumeRestoredDocGen = -1;
    lastPlayingAt = null;
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
    explicitPlayAttempted = false;
    userPlayInFlight = false;
    clearVolumeRestorePending();
    volumeRestoredDocGen = -1;
    lastPlayingAt = null;
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

  /// Marks an intentional play command (transport / autoplay / recovery).
  void markExplicitPlayAttempt() {
    explicitPlayAttempted = true;
  }

  void clearVolumeRestorePending() {
    volumeRestorePending = false;
    volumeRestoreBaselinePosition = null;
    progressAdvanceTicks = 0;
  }

  /// Pins the current document as volume-restored so later `playing` events
  /// skip the unmute entirely (idempotence against the gesture lock).
  void noteVolumeRestored() {
    volumeRestoredDocGen = documentGen;
  }

  /// Bumps the watch-document generation (open / watch load stop).
  void noteWatchDocumentLoaded() {
    documentGen++;
  }

  void armVolumeRestorePending({required Duration baseline}) {
    volumeRestorePending = true;
    volumeRestoreBaselinePosition = baseline;
    progressAdvanceTicks = 0;
  }

  /// Returns true when [position] has advanced enough to safely unmute.
  bool noteProgressForVolumeRestore(Duration position) {
    if (!volumeRestorePending) return false;
    final baseline = volumeRestoreBaselinePosition ?? Duration.zero;
    if (position > baseline) {
      progressAdvanceTicks++;
      volumeRestoreBaselinePosition = position;
    }
    return progressAdvanceTicks >= progressConfirmTicks;
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
      lastPlayingAt = DateTime.now();
      _cancelHint();
      if (tapToPlayHintActive) {
        tapToPlayHintActive = false;
        mountTick.value++;
      }
    }
  }

  /// True when a pause confirmation arrives soon after [emitPlaying(true)].
  bool isImmediatePause(DateTime now) {
    final started = lastPlayingAt;
    if (started == null) return false;
    return now.difference(started) <= immediatePauseWindow;
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
    if (disposed) return;
    // Initial open: hint only before first successful playing.
    // After an explicit play that failed / immediately paused, allow recovery
    // hint even when [loggedFirstPlaying] is already true.
    final allowRecovery = explicitPlayAttempted && !playing && !buffering;
    if (loggedFirstPlaying && !allowRecovery) return;
    _tapToPlayHintTimer?.cancel();
    _tapToPlayHintTimer = Timer(_tapToPlayHintDelay, () {
      _tapToPlayHintTimer = null;
      if (disposed || playing || buffering) return;
      if (loggedFirstPlaying && !explicitPlayAttempted) return;
      if (!tapToPlayHintActive) {
        tapToPlayHintActive = true;
        mountTick.value++;
      }
    });
  }

  /// Arms the recovery overlay after play rejection or immediate pause.
  void scheduleRecoveryHint() {
    if (disposed || playing) return;
    _scheduleHint();
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
