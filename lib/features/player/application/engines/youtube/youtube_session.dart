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
  /// [playAttemptExpiry] shortens the D8 budget's lifetime for tests
  /// (defaults to [immediatePauseWindow]).
  YoutubeSession({Duration? playAttemptExpiry})
    : _playAttemptExpiry = playAttemptExpiry ?? immediatePauseWindow;

  /// How long after its resolving playing episode the D8 budget stays
  /// armed (see [userPlayInFlight]). No timer — retired lazily, so
  /// fake-async widget tests never see a pending timer from an armed
  /// budget.
  final Duration _playAttemptExpiry;

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
  Completer<void>? _surfaceDetached;
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

  /// An explicit play-intent command is still the live transport intent.
  /// Grants the poll loop exactly one automatic retry when a pause is
  /// confirmed almost immediately after playback started — the page player
  /// state machine can "correct" a freshly started video back to paused
  /// before it settles; one retry after it settles recovers without UX.
  ///
  /// The latch spans the WHOLE attempt: arming (play command) → the first
  /// `playing` ([notePlayingConfirmed] deliberately keeps it armed — a play
  /// is only fulfilled once playback outlives the immediate-pause window,
  /// which is exactly the window the page's correction lands in) →
  /// consumption (the retry itself, a rejecting/error transition, or any
  /// explicit pause-intent command via [noteUserPauseCommand], so a
  /// deliberate app pause is never auto-resumed). Fulfillment is enforced
  /// lazily by the [userPlayInFlight] getter: the budget retires
  /// [_playAttemptExpiry] after the playing episode that resolved the
  /// arming command — keyed to THAT episode, not to whatever episode is
  /// current, so a later page-UI resume the app never commanded cannot
  /// revive a stale budget.
  ///
  /// Irreducible tradeoff: a DOM `pause` carries no initiator, so a pause
  /// made through YouTube's own in-page controls within the window of an
  /// app-commanded start is indistinguishable from a page correction and
  /// is retried once — self-limiting, since the budget is then spent.
  bool _userPlayInFlight = false;

  /// When the playing episode that resolved the current armed attempt
  /// started, or null while the attempt has not reached `playing` yet.
  DateTime? _playBudgetEpisodeAt;

  /// Wall-clock of the poll loop's last D8 retry issue.
  DateTime? _lastAutoPlayRetryAt;

  /// Cap on automatic retries per user play command (D8 escalation — the
  /// field-observed echo-mode wedge survived the first retry).
  static const int maxAutoRetries = 2;

  /// Auto retries issued since the last play-intent command.
  int _autoRetriesIssued = 0;

  /// The current playing episode was produced by an auto retry (set when
  /// the retry is issued, consumed by the next `playing` transition).
  bool _pendingAutoRetryAttribution = false;

  /// The most recent playing episode was produced by an auto retry.
  bool _lastPlayingFromAutoRetry = false;

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

  /// The D8 budget is live only while its attempt is unresolved in time:
  /// armed AND (no resolving playing episode yet, or that episode started
  /// within [_playAttemptExpiry]). This is the fulfillment condition from
  /// the field doc — a play attempt resolves once its playback outlives the
  /// immediate window — without a timer.
  bool get userPlayInFlight {
    final episodeAt = _playBudgetEpisodeAt;
    return _userPlayInFlight &&
        (episodeAt == null ||
            DateTime.now().difference(episodeAt) < _playAttemptExpiry);
  }

  DateTime? get lastAutoPlayRetryAt => _lastAutoPlayRetryAt;
  int get autoRetriesIssued => _autoRetriesIssued;
  bool get lastPlayingFromAutoRetry => _lastPlayingFromAutoRetry;
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
    _playBudgetEpisodeAt = null;
    _tapToPlayHintActive = false;
    _loggedFirstPlaying = false;
    resetWatchPageExpectations(firstPlaying: false);
    _firstBufferingOffReceived = false;
    _explicitPlayAttempted = false;
    _userPlayInFlight = false;
    _lastAutoPlayRetryAt = null;
    _autoRetriesIssued = 0;
    _lastPlayingFromAutoRetry = false;
    _pendingAutoRetryAttribution = false;
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
    _playBudgetEpisodeAt = null;
    _tapToPlayHintActive = false;
    _explicitPlayAttempted = false;
    _userPlayInFlight = false;
    _lastAutoPlayRetryAt = null;
    _autoRetriesIssued = 0;
    _lastPlayingFromAutoRetry = false;
    _pendingAutoRetryAttribution = false;
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
    // Fresh attempt: its fulfillment clock starts at ITS resolving playing
    // episode, not at a previous attempt's.
    _playBudgetEpisodeAt = null;
    _autoRetriesIssued = 0;
    _lastPlayingFromAutoRetry = false;
    _pendingAutoRetryAttribution = false;
    if (_buffering && !_playing) {
      emitBuffering(false);
    }
  }

  /// An explicit pause-intent command is on the wire (engine
  /// [pause]/[stop]/the pause branch of [playOrPause]). Consumes the D8
  /// retry budget so a deliberate pause is never auto-resumed — without
  /// this, a user pausing within the immediate-pause window of a fresh
  /// start would be un-paused by the retry. Also drops auto-retry
  /// attribution (escalation must stop for a deliberate pause) and
  /// delegates the budget consumption to [clearUserPlayInFlight] so it
  /// stays defined in exactly one place (issue #627).
  void noteUserPauseCommand() {
    _lastPlayingFromAutoRetry = false;
    _pendingAutoRetryAttribution = false;
    clearUserPlayInFlight();
  }

  /// Records that the poll loop just spent the D8 budget on a retry. The
  /// audible policy's post-restore heal suppresses itself while a retry is
  /// this recent — both target the same page-corrected pause, and a double
  /// `playVideo` breaks the "re-issues play exactly once" accounting.
  /// Also steps the escalation bookkeeping: counts the retry against
  /// [maxAutoRetries] and arms attribution so the playing episode this
  /// retry produces is recognized as auto-retry-origin.
  void noteAutoPlayRetry() {
    _lastAutoPlayRetryAt = DateTime.now();
    _autoRetriesIssued++;
    _pendingAutoRetryAttribution = true;
  }

  /// `playing` observed (DOM event or poll). The in-flight play latch stays
  /// armed: the attempt resolves only when playback outlives the
  /// immediate-pause window (or a failure/pause-intent transition consumes
  /// it). Clearing it here made the D8 retry unreachable for the very
  /// sequence it exists for — the page's post-`playing` correction always
  /// confirmed after the latch was gone.
  void notePlayingConfirmed() {
    _pausedPollStreak = 0;
    _playbackCompleted = false;
    // Attribution latches per EPISODE (the false→true transition): the poll
    // loop re-confirms playing on every tick, and a per-call consumption let
    // those ticks erase the auto-retry attribution ~250 ms into the retried
    // episode — the escalation arm then never fired for the second wedge
    // pause (field round 5: one retry logged, none after).
    final wasPlaying = _playing;
    if (!wasPlaying) {
      _lastPlayingFromAutoRetry = _pendingAutoRetryAttribution;
      _pendingAutoRetryAttribution = false;
    }
    emitPlaying(true);
  }

  /// A programmatic play promise rejected (autoplay policy) or the element
  /// errored: the unresolved user play settles as not-playing.
  void noteUserPlayUnresolved() {
    _userPlayInFlight = false;
    _pendingAutoRetryAttribution = false;
    _lastPlayingFromAutoRetry = false;
    emitPlaying(false);
    emitBuffering(false);
  }

  /// End of media observed (DOM `ended` or poll `s` = 2).
  void noteEnded() {
    _pausedPollStreak = 0;
    _userPlayInFlight = false;
    _pendingAutoRetryAttribution = false;
    _lastPlayingFromAutoRetry = false;
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

  void noteWebViewUnmounted() {
    _webViewMounted = false;
    final waiter = _surfaceDetached;
    _surfaceDetached = null;
    if (waiter != null && !waiter.isCompleted) {
      waiter.complete();
    }
  }

  /// Completes when the WebView widget has unmounted, or immediately if it
  /// is not mounted. Does not wait for native view destruction.
  Future<void> awaitSurfaceDetached() async {
    if (!_webViewMounted) return;
    final waiter = _surfaceDetached ??= Completer<void>();
    return waiter.future;
  }

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
      if (_userPlayInFlight && _playBudgetEpisodeAt == null) {
        // Start the armed attempt's fulfillment clock at the episode that
        // resolved it. Later episodes (page-UI resumes, the D8 retry's own
        // play after the budget is spent) must not refresh it.
        _playBudgetEpisodeAt = _lastPlayingAt;
      }
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
