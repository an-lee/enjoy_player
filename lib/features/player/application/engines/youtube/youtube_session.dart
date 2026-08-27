/// Playback state and broadcast streams for [YoutubePlayerEngine].
///
/// The session owns the Dart-side transport latches; every other module
/// (engine, events, poll loop, webview controller, navigation) changes them
/// only through the transition verbs below, so each invariant — what must be
/// cleared together, what may only transition once — is enforced in exactly
/// one place instead of at every writer (issue #627).
library;

import 'dart:async';

import 'package:flutter/foundation.dart' show ValueListenable;
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
  final ValueNotifier<int> _mountTick = ValueNotifier(0);
  final Stream<double> aspectStream = Stream<double>.value(16 / 9);

  String _videoId = '';
  String? _posterUrl;
  bool _mountRequested = false;
  bool _webViewMounted = false;
  bool _loggedFirstPlaying = false;
  bool _watchPageLoadStopReceived = false;
  bool _awaitingColdInitialNavigation = false;
  bool _nonWatchRecoveryScheduled = false;
  bool _disposed = false;
  bool _playbackCompleted = false;
  bool _firstBufferingOffReceived = false;

  bool _playing = false;
  bool _buffering = true;
  bool _tapToPlayHintActive = false;

  /// User (or app) requested play; cancels autoplay assist and arms recovery UX.
  bool _explicitPlayAttempted = false;

  /// An explicit user play has not yet resolved (playing/rejected/error).
  /// Grants the poll loop exactly one automatic retry when a pause is
  /// confirmed almost immediately after playback started — the page player
  /// state machine can "correct" a freshly started video back to paused
  /// before it settles; one retry after it settles recovers without UX.
  bool _userPlayInFlight = false;

  /// First-play unmute is deferred until [position] advances (or fallback).
  bool _volumeRestorePending = false;
  Duration? _volumeRestoreBaselinePosition;
  int _progressAdvanceTicks = 0;
  static const int progressConfirmTicks = 2;

  /// Generation of the loaded watch document. Bumped on every open and watch
  /// load stop (ads reload the page into a fresh document whose `<video>`
  /// starts muted again).
  int _documentGen = 0;

  /// [_documentGen] for which volume was last restored, or `-1` when never.
  /// The unmute runs at most once per document: redundant programmatic
  /// unMutes are pause triggers under Chromium's autoplay gesture lock (the
  /// play-then-pause root cause), so later `playing` events in an already
  /// restored document must not touch volume at all.
  int _volumeRestoredDocGen = -1;

  /// Wall-clock when [emitPlaying] last reported playing — for
  /// immediate-pause diagnostics (pause confirmed within this window).
  DateTime? _lastPlayingAt;
  static const Duration immediatePauseWindow = Duration(seconds: 2);

  Timer? _tapToPlayHintTimer;

  /// Recovery-overlay delay. Part of the audible-playback joint invariant
  /// (must exceed [YoutubeAudiblePlaybackPolicy.postRestoreHealDelay]'s
  /// check window) — asserted in the policy's tests, which is why it is
  /// public.
  static const Duration tapToPlayHintDelay = Duration(milliseconds: 1200);

  Duration _lastPosition = Duration.zero;
  Duration _lastDuration = Duration.zero;

  double _volumeNormalized = 1;
  double? _pendingSeekSeconds;

  int _pausedPollStreak = 0;
  static const int pauseConfirmPollTicks = 3;

  Stopwatch? _initStopwatch;

  // ---------------------------------------------------------------------------
  // Read surface — the latches are private; writers must use the verbs below.
  // ---------------------------------------------------------------------------

  Stream<Duration> get position => positionCtrl.stream;
  Stream<Duration> get duration => durationCtrl.stream;
  Stream<bool> get playingStream => playingCtrl.stream;
  Stream<bool> get bufferingStream => bufferingCtrl.stream;
  Stream<void> get completed => completedCtrl.stream;

  /// Read-only view: host-tree rebuilds observe, only the session mutates.
  ValueListenable<int> get mountTick => _mountTick;

  String get videoId => _videoId;
  String? get posterUrl => _posterUrl;
  bool get shouldMountWebView => _mountRequested && !_disposed;
  bool get webViewMounted => _webViewMounted;
  bool get disposed => _disposed;
  bool get playbackCompleted => _playbackCompleted;
  bool get loggedFirstPlaying => _loggedFirstPlaying;
  bool get watchPageLoadStopReceived => _watchPageLoadStopReceived;
  bool get awaitingColdInitialNavigation => _awaitingColdInitialNavigation;
  bool get nonWatchRecoveryScheduled => _nonWatchRecoveryScheduled;
  bool get tapToPlayHintActive => _tapToPlayHintActive;

  bool get playing => _playing;
  bool get buffering => _buffering;
  bool get explicitPlayAttempted => _explicitPlayAttempted;
  bool get userPlayInFlight => _userPlayInFlight;
  bool get volumeRestorePending => _volumeRestorePending;
  Duration get lastPosition => _lastPosition;
  Duration get lastDuration => _lastDuration;
  DateTime? get lastPlayingAt => _lastPlayingAt;
  double get volumeNormalized => _volumeNormalized;
  int get pausedPollStreak => _pausedPollStreak;
  int get documentGen => _documentGen;
  int get volumeRestoredDocGen => _volumeRestoredDocGen;

  ({bool playing, bool buffering}) get transportSnapshot =>
      (playing: _playing, buffering: _buffering);

  /// True when the current document still needs its first volume restore.
  bool get needsVolumeRestore =>
      _volumeRestoredDocGen != _documentGen && !_disposed;

  // ---------------------------------------------------------------------------
  // Open / clear lifecycle.
  // ---------------------------------------------------------------------------

  void setPosterUrl(String? url) => _posterUrl = url;

  /// Transitions [_playbackCompleted] to true and emits a [completed] event.
  /// Idempotent — only the first call emits; subsequent calls are a no-op.
  /// [resetCompletionFlag] re-arms the emission for the next end-of-media.
  void markCompleted() {
    if (_playbackCompleted) return;
    _playbackCompleted = true;
    if (!_disposed && !completedCtrl.isClosed) {
      completedCtrl.add(null);
    }
  }

  /// Clears the end-of-media latch so the next [play] drives the `<video>`
  /// directly instead of reloading the watch page (ADR-0044).
  void resetCompletionFlag() => _playbackCompleted = false;

  void resetForOpen(String newVideoId) {
    _cancelHint();
    _tapToPlayHintActive = false;
    _loggedFirstPlaying = false;
    resetWatchPageExpectations(firstPlaying: false);
    _firstBufferingOffReceived = false;
    _explicitPlayAttempted = false;
    _userPlayInFlight = false;
    clearVolumeRestorePending();
    noteWatchDocumentLoaded();
    _volumeRestoredDocGen = -1;
    _lastPlayingAt = null;
    _videoId = newVideoId;
    _playbackCompleted = false;
    emitBuffering(true);
    emitPlaying(false);
    emitPosition(Duration.zero);
    emitDuration(Duration.zero);
  }

  void resetForClear({bool keepMounted = false}) {
    _cancelHint();
    _tapToPlayHintActive = false;
    _explicitPlayAttempted = false;
    _userPlayInFlight = false;
    clearVolumeRestorePending();
    _volumeRestoredDocGen = -1;
    _lastPlayingAt = null;
    _videoId = '';
    _mountRequested = keepMounted;
    _playbackCompleted = false;
    resetWatchPageExpectations(firstPlaying: false);
    emitPlaying(false);
    emitBuffering(false);
    emitPosition(Duration.zero);
    bumpMountTick();
  }

  // ---------------------------------------------------------------------------
  // Transport transitions.
  //
  // The DOM event channel, the poll channel, and the engine commands all
  // funnel through these — the "clear X when Y" rules live here, once.
  // ---------------------------------------------------------------------------

  /// An explicit play command is on the wire (engine [play]/[playOrPause]).
  /// Stale buffering clears so the transport button stays retryable.
  void beginUserPlay() {
    _userPlayInFlight = true;
    if (_buffering && !_playing) {
      emitBuffering(false);
    }
  }

  /// `playing` observed (DOM event or poll): the user play resolved.
  void notePlayingConfirmed() {
    _pausedPollStreak = 0;
    _playbackCompleted = false;
    _userPlayInFlight = false;
    emitPlaying(true);
  }

  /// A programmatic play promise rejected (autoplay policy) or the element
  /// errored: the unresolved user play settles as not-playing.
  void noteUserPlayUnresolved() {
    _userPlayInFlight = false;
    emitPlaying(false);
    emitBuffering(false);
  }

  /// End of media observed (DOM `ended` or poll `s` = 2).
  void noteEnded() {
    _pausedPollStreak = 0;
    _userPlayInFlight = false;
    markCompleted();
    emitPlaying(false);
    emitBuffering(false);
  }

  /// The poll loop confirmed a pause (streak ≥ [pauseConfirmPollTicks]).
  void notePauseConfirmed() {
    _pausedPollStreak = 0;
    emitPlaying(false);
    emitBuffering(false);
  }

  /// Consumes the one-shot immediate-pause retry budget (D8) before the poll
  /// loop re-issues play; a second immediate pause surfaces to the user.
  void clearUserPlayInFlight() => _userPlayInFlight = false;

  /// Marks an intentional play command (transport / autoplay / recovery).
  void markExplicitPlayAttempt() => _explicitPlayAttempted = true;

  /// Poll bookkeeping: accumulate toward pause confirmation.
  void notePauseStreak(int streak) => _pausedPollStreak = streak;

  /// Poll bookkeeping: forget any half-confirmed pause.
  void resetPauseStreak() => _pausedPollStreak = 0;

  // ---------------------------------------------------------------------------
  // Watch-page expectations (webview controller / navigation).
  // ---------------------------------------------------------------------------

  /// Clears the "expect a watch page load stop" latches before (re)loading.
  /// [firstPlaying] also forgets that playback ever started (full reload).
  void resetWatchPageExpectations({required bool firstPlaying}) {
    _watchPageLoadStopReceived = false;
    _awaitingColdInitialNavigation = false;
    _nonWatchRecoveryScheduled = false;
    if (firstPlaying) {
      _loggedFirstPlaying = false;
    }
  }

  /// A watch-page load stop arrived: not cold-navigation, no recovery needed.
  void noteWatchPageLoaded() {
    _awaitingColdInitialNavigation = false;
    _watchPageLoadStopReceived = true;
    _nonWatchRecoveryScheduled = false;
  }

  /// The WebView mounted with an initial watch URL already navigating.
  void noteAwaitingColdInitialNavigation() =>
      _awaitingColdInitialNavigation = true;

  /// The WebView went away; its in-flight initial navigation no longer
  /// applies. (Deliberately narrow: dispose must not disturb the load-stop
  /// or recovery latches.)
  void clearAwaitingColdInitialNavigation() =>
      _awaitingColdInitialNavigation = false;

  /// First `playing` observed after an open — arms nudge/watchdog cancel.
  void markFirstPlayingLogged() => _loggedFirstPlaying = true;

  /// A non-watch load stop was seen; verify the watch page once.
  void scheduleNonWatchRecovery() => _nonWatchRecoveryScheduled = true;

  /// Starts (or restarts) open-time init instrumentation.
  void startInitTiming() => _initStopwatch = Stopwatch()..start();

  // ---------------------------------------------------------------------------
  // WebView mount state.
  // ---------------------------------------------------------------------------

  void noteWebViewMounted() => _webViewMounted = true;

  void noteWebViewUnmounted() => _webViewMounted = false;

  void requestMount() {
    if (_disposed) return;
    // Idempotent: re-entrant calls (e.g. loading stage + open coordinator)
    // must not notify [mountTick] again — that can hit ValueListenableBuilder
    // listeners during an ancestor build (setState-during-build).
    if (_mountRequested) return;
    _mountRequested = true;
    bumpMountTick();
  }

  /// Notifies host-tree listeners that session-derived UI changed.
  void bumpMountTick() => _mountTick.value++;

  /// Deferred variant for teardown paths that run during widget unmount —
  /// notifying synchronously there locks the tree.
  void scheduleMountTickBump() {
    scheduleMicrotask(bumpMountTick);
  }

  // ---------------------------------------------------------------------------
  // Volume restore (autoplay-policy latch — see YoutubeWebViewEvents).
  // ---------------------------------------------------------------------------

  void clearVolumeRestorePending() {
    _volumeRestorePending = false;
    _volumeRestoreBaselinePosition = null;
    _progressAdvanceTicks = 0;
  }

  /// Pins the current document as volume-restored so later `playing` events
  /// skip the unmute entirely (idempotence against the gesture lock).
  void noteVolumeRestored() => _volumeRestoredDocGen = _documentGen;

  /// Bumps the watch-document generation (open / watch load stop).
  void noteWatchDocumentLoaded() => _documentGen++;

  void armVolumeRestorePending({required Duration baseline}) {
    _volumeRestorePending = true;
    _volumeRestoreBaselinePosition = baseline;
    _progressAdvanceTicks = 0;
  }

  /// Returns true when [position] has advanced enough to safely unmute.
  bool noteProgressForVolumeRestore(Duration position) {
    if (!_volumeRestorePending) return false;
    final baseline = _volumeRestoreBaselinePosition ?? Duration.zero;
    if (position > baseline) {
      _progressAdvanceTicks++;
      _volumeRestoreBaselinePosition = position;
    }
    return _progressAdvanceTicks >= progressConfirmTicks;
  }

  // ---------------------------------------------------------------------------
  // Misc state.
  // ---------------------------------------------------------------------------

  /// Stores the normalized volume and returns the clamped value applied to
  /// the page player.
  double storeVolumeNormalized(double volume) {
    _volumeNormalized = volume.clamp(0, 1);
    return _volumeNormalized;
  }

  /// Seek requested from the page side (ad-reload position hand-off).
  void setPendingSeekSeconds(double? seconds) => _pendingSeekSeconds = seconds;

  /// Claims and clears the page-side pending seek.
  double? takePendingSeekSeconds() {
    final seconds = _pendingSeekSeconds;
    _pendingSeekSeconds = null;
    return seconds;
  }

  void emitPosition(Duration d) {
    if (_disposed || positionCtrl.isClosed) return;
    if (d == _lastPosition) return;
    _lastPosition = d;
    positionCtrl.add(d);
  }

  void emitDuration(Duration d) {
    if (_disposed || durationCtrl.isClosed) return;
    if (d == _lastDuration) return;
    _lastDuration = d;
    durationCtrl.add(d);
  }

  void emitPlaying(bool v) {
    if (_disposed || playingCtrl.isClosed) return;
    if (v == _playing) return;
    _playing = v;
    playingCtrl.add(v);
    if (v) {
      _lastPlayingAt = DateTime.now();
      _cancelHint();
      if (_tapToPlayHintActive) {
        _tapToPlayHintActive = false;
        bumpMountTick();
      }
    }
  }

  /// True when a pause confirmation arrives soon after playback started.
  bool isImmediatePause(DateTime now) {
    final started = _lastPlayingAt;
    if (started == null) return false;
    return now.difference(started) <= immediatePauseWindow;
  }

  void emitBuffering(bool v) {
    if (_disposed || bufferingCtrl.isClosed) return;
    if (v == _buffering) return;
    _buffering = v;
    bufferingCtrl.add(v);
    if (!v && !_firstBufferingOffReceived) {
      _firstBufferingOffReceived = true;
      bumpMountTick();
    }
    if (v) {
      _cancelHint();
      if (_tapToPlayHintActive) {
        _tapToPlayHintActive = false;
        bumpMountTick();
      }
    } else {
      _scheduleHint();
    }
  }

  void _scheduleHint() {
    if (_disposed) return;
    // Initial open: hint only before first successful playing.
    // After an explicit play that failed / immediately paused, allow recovery
    // hint even when [_loggedFirstPlaying] is already true.
    final allowRecovery = _explicitPlayAttempted && !_playing && !_buffering;
    if (_loggedFirstPlaying && !allowRecovery) return;
    _tapToPlayHintTimer?.cancel();
    _tapToPlayHintTimer = Timer(tapToPlayHintDelay, () {
      _tapToPlayHintTimer = null;
      if (_disposed || _playing || _buffering) return;
      if (_loggedFirstPlaying && !_explicitPlayAttempted) return;
      if (!_tapToPlayHintActive) {
        _tapToPlayHintActive = true;
        bumpMountTick();
      }
    });
  }

  /// Arms the recovery overlay after play rejection or immediate pause.
  void scheduleRecoveryHint() {
    if (_disposed || _playing) return;
    _scheduleHint();
  }

  void _cancelHint() {
    _tapToPlayHintTimer?.cancel();
    _tapToPlayHintTimer = null;
  }

  void logInitPhase(String phase, void Function(String message) log) {
    final ms = _initStopwatch?.elapsedMilliseconds;
    final message = 'youtube init $phase${ms != null ? ' +${ms}ms' : ''}';
    if (phase == 'load_stop' || phase == 'first_playing') {
      log(message);
    }
  }

  Future<void> closeStreams() async {
    _cancelHint();
    _disposed = true;
    _mountRequested = false;
    bumpMountTick();
    await positionCtrl.close();
    await durationCtrl.close();
    await playingCtrl.close();
    await bufferingCtrl.close();
    await completedCtrl.close();
  }
}
