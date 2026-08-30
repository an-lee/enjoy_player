/// One owner for the YouTube immediate-pause play-retry protocol (issue #665).
///
/// The play-then-pause saga is the most-changed logic in the codebase, and its
/// budget used to be spread across four places that had to move in lockstep:
/// latch fields in `YoutubeSession`, the D8/D9 decision tables in
/// `transport_decisions.dart` (`decideImmediatePauseRetry`,
/// `decideTransportToggleLatch`), the `PauseStreaking` arm of
/// `YoutubeWebViewPollLoop`, and the recent-retry suppression in the audible
/// policy's `_healPostRestorePause`. The protocol's state, its constants, and
/// its clock now live here; the callers keep only their side effects
/// (re-issuing play, surfacing the recovery hint, and arming or consuming
/// through the session's transition verbs).
///
/// ## D8 — the one-shot immediate-pause budget, its fulfilment clock, and
/// escalation
///
/// A pause confirmed almost immediately after playback started is usually the
/// page player state machine "correcting" a freshly started video back to
/// paused before it settles; one retry after it settles recovers without UX.
///
/// The budget spans the WHOLE attempt: arming ([beginUserPlay], from a
/// play-intent command) → the first `playing`
/// ([notePlayingTransition] deliberately keeps it armed — a play is only
/// fulfilled once playback outlives the immediate-pause window, which is
/// exactly the window the page's correction lands in) → consumption (the
/// retry itself — [consumeBudget] —, a rejecting/error transition
/// ([noteUserPlayUnresolved]), end of media ([noteEnded]), or any explicit
/// pause-intent command ([noteUserPauseCommand], so a deliberate app pause is
/// never auto-resumed)). Fulfilment is enforced lazily by [userPlayInFlight]:
/// the budget retires [playAttemptExpiry] after the playing episode that
/// resolved the arming command — keyed to THAT episode, not to whatever
/// episode is current, so a later page-UI resume the app never commanded
/// cannot revive a stale budget. There is deliberately no timer: the budget is
/// retired lazily on read, so fake-async widget tests never see a pending
/// timer from an armed budget.
///
/// Coverage has two arms:
///
/// - the budget above;
/// - escalation — [lastPlayingFromAutoRetry] with [autoRetriesIssued] <
///   [maxAutoRetries] — for the field-observed echo-mode wedge (Android): the
///   page re-paused the *retried* play too (~600 ms in), spending the one-shot
///   budget and wedging playback until a manual tap. Each attempt outlived the
///   previous one, so further settled retries have a real chance; the cap
///   bounds total auto-plays per user command so a deliberate pause is never
///   fought indefinitely.
///
/// Every other confirmed pause surfaces normally (the recovery hint is the
/// consumer's decision).
///
/// Irreducible tradeoff: a DOM `pause` carries no initiator, so a pause made
/// through YouTube's own in-page controls within the window of an
/// app-commanded start is indistinguishable from a page correction and is
/// retried once — self-limiting, since the budget is then spent.
///
/// ## Clock
///
/// All three budgets (immediate-pause window, attempt expiry, retry recency)
/// read the injected monotonic [MonotonicClock]. They used to be
/// `DateTime.now()` deltas, which an NTP step or a manual clock change could
/// corrupt in either direction.
library;

import 'package:enjoy_player/features/player/application/engines/youtube/youtube_monotonic_clock.dart';

/// Owns the immediate-pause retry budget, its attribution, the escalation
/// chain, and every clock the protocol reads.
///
/// Timing constraints (asserted jointly in
/// `youtube_play_retry_policy_test.dart` so they cannot drift apart):
///
///     pauseConfirm (pauseConfirmPollTicks × pollTick)
///       <  immediatePauseWindow
///       <= playAttemptExpiry
///     1 <= maxAutoRetries
///
/// A pause may only be retried while it is immediate, so the poll loop must be
/// able to *confirm* a pause inside the immediate window — a shorter window
/// makes the whole protocol unreachable. And the budget must outlive that same
/// window: a budget that retires before the window closes opens a dead zone
/// where a pause is immediate but uncovered.
class YouTubePlayRetryPolicy {
  /// [clock], [playAttemptExpiry], [immediatePauseWindow] and [maxAutoRetries]
  /// are injectable so tests can advance protocol time and shrink the budget
  /// deterministically instead of sleeping past the real windows.
  YouTubePlayRetryPolicy({
    MonotonicClock? clock,
    Duration? playAttemptExpiry,
    Duration? immediatePauseWindow,
    int? maxAutoRetries,
  }) : _clock = clock ?? StopwatchClock(),
       playAttemptExpiry = playAttemptExpiry ?? defaultPlayAttemptExpiry,
       immediatePauseWindow =
           immediatePauseWindow ?? defaultImmediatePauseWindow,
       maxAutoRetries = maxAutoRetries ?? defaultMaxAutoRetries;

  /// How long after playback started a confirmed pause still counts as
  /// "immediate" — i.e. as the page's post-`playing` correction rather than a
  /// deliberate pause. Gated on being longer than the poll loop's
  /// pause-confirmation window; see the class-level invariant.
  static const Duration defaultImmediatePauseWindow = Duration(seconds: 2);

  /// How long after its resolving playing episode the D8 budget stays armed
  /// (see [userPlayInFlight]). Defaults to [defaultImmediatePauseWindow]: the
  /// budget is only ever spendable on an *immediate* pause, so letting it
  /// outlive that window would be dead coverage, and cutting it shorter would
  /// open a dead zone where a pause is immediate but uncovered.
  static const Duration defaultPlayAttemptExpiry = defaultImmediatePauseWindow;

  /// Cap on automatic retries per user play command (D8 escalation — the
  /// field-observed echo-mode wedge survived the first retry).
  static const int defaultMaxAutoRetries = 2;

  final MonotonicClock _clock;

  /// Lifetime of an armed budget past its resolving playing episode.
  final Duration playAttemptExpiry;

  /// How soon after playback started a confirmed pause is "immediate".
  final Duration immediatePauseWindow;

  /// Cap on automatic retries per user play command.
  final int maxAutoRetries;

  /// An explicit play-intent command is still the live transport intent.
  bool _budgetArmed = false;

  /// When the playing episode that resolved the current armed attempt
  /// started, or null while the attempt has not reached `playing` yet.
  Duration? _budgetEpisodeAt;

  /// Protocol time of the last D8 retry issue. The audible policy's
  /// post-restore heal reads recency against it ([recentAutoRetryWithin])
  /// instead of comparing wall clocks across modules.
  Duration? _lastAutoRetryAt;

  /// Auto retries issued since the last play-intent command.
  int _autoRetriesIssued = 0;

  /// The current playing episode was produced by an auto retry (set when
  /// the retry is issued, consumed by the next `playing` transition).
  bool _pendingAutoRetryAttribution = false;

  /// The most recent playing episode was produced by an auto retry.
  bool _lastPlayingFromAutoRetry = false;

  /// This policy's view of the transport: a `playing` notice that does not
  /// change it is a poll-tick re-confirmation, not an episode transition,
  /// and must not touch the attribution latch or the clocks. The session's
  /// own emit guard already filters those; tracking it here too keeps the
  /// invariant inside the protocol's owner rather than in the funnel.
  bool _episodeLive = false;

  /// Protocol time of the most recent `playing` transition — the
  /// immediate-pause measurement ([isImmediatePause]).
  Duration? _lastPlayingAt;

  // ---------------------------------------------------------------------------
  // Reads.
  // ---------------------------------------------------------------------------

  /// The D8 budget is live only while its attempt is unresolved in time:
  /// armed AND (no resolving playing episode yet, or that episode started
  /// within [playAttemptExpiry]). This is the fulfilment condition from the
  /// field doc — a play attempt resolves once its playback outlives the
  /// immediate window — without a timer.
  bool get userPlayInFlight {
    final episodeAt = _budgetEpisodeAt;
    return _budgetArmed &&
        (episodeAt == null || _clock.now() - episodeAt < playAttemptExpiry);
  }

  /// Auto retries issued since the last play-intent command.
  int get autoRetriesIssued => _autoRetriesIssued;

  /// The most recent playing episode was produced by an auto retry.
  bool get lastPlayingFromAutoRetry => _lastPlayingFromAutoRetry;

  /// True when a pause confirmation arrives soon after playback started.
  bool isImmediatePause() {
    final started = _lastPlayingAt;
    if (started == null) return false;
    return _clock.now() - started <= immediatePauseWindow;
  }

  /// True when a D8 retry was issued less than [window] ago. The audible
  /// policy's post-restore heal suppresses itself on this — both target the
  /// same page-corrected pause, and a double `playVideo` breaks the
  /// "re-issues play exactly once" accounting.
  bool recentAutoRetryWithin(Duration window) {
    final at = _lastAutoRetryAt;
    if (at == null) return false;
    return _clock.now() - at < window;
  }

  // ---------------------------------------------------------------------------
  // Budget transitions (armed → consumed).
  // ---------------------------------------------------------------------------

  /// An explicit play command is on the wire (engine play / playOrPause).
  /// Arms a fresh attempt: its fulfilment clock starts at ITS resolving
  /// playing episode, not at a previous attempt's, and the escalation chain
  /// restarts with it.
  void beginUserPlay() {
    _budgetArmed = true;
    _budgetEpisodeAt = null;
    _autoRetriesIssued = 0;
    _lastPlayingFromAutoRetry = false;
    _pendingAutoRetryAttribution = false;
  }

  /// An explicit pause-intent command is on the wire (engine pause / stop /
  /// the pause branch of playOrPause). Consumes the D8 retry budget so a
  /// deliberate pause is never auto-resumed — without this, a user pausing
  /// within the immediate-pause window of a fresh start would be un-paused by
  /// the retry. Also drops auto-retry attribution (escalation must stop for a
  /// deliberate pause) and delegates the budget consumption to [consumeBudget]
  /// so it stays defined in exactly one place.
  void noteUserPauseCommand() {
    _lastPlayingFromAutoRetry = false;
    _pendingAutoRetryAttribution = false;
    consumeBudget();
  }

  /// Records that the poll loop just spent the D8 budget on a retry. Also
  /// steps the escalation bookkeeping: counts the retry against
  /// [maxAutoRetries] and arms attribution so the playing episode this retry
  /// produces is recognized as auto-retry-origin.
  void noteAutoPlayRetry() {
    _lastAutoRetryAt = _clock.now();
    _autoRetriesIssued++;
    _pendingAutoRetryAttribution = true;
  }

  /// Consumes the one-shot immediate-pause retry budget (D8) before the poll
  /// loop re-issues play; a second immediate pause surfaces to the user.
  void consumeBudget() => _budgetArmed = false;

  // ---------------------------------------------------------------------------
  // Episode transitions.
  // ---------------------------------------------------------------------------

  /// A `playing` transition (false→true or true→false) was emitted. Three
  /// protocol facts are keyed to the false→true direction:
  ///
  /// - the immediate-pause measurement restarts;
  /// - the armed attempt's fulfilment clock starts HERE — later episodes
  ///   (page-UI resumes, the D8 retry's own play after the budget is spent)
  ///   must not refresh it;
  /// - attribution latches per EPISODE: the poll loop re-confirms playing on
  ///   every tick, and a per-call consumption let those ticks erase the
  ///   auto-retry attribution ~250 ms into the retried episode — the
  ///   escalation arm then never fired for the second wedge pause (field
  ///   round 5: one retry logged, none after).
  ///
  /// A playing→false transition carries no protocol information: the
  /// attribution and budget latches are consumed by their own verbs instead,
  /// so a pause cannot launder the escalation chain by passing through here.
  void notePlayingTransition(bool nowPlaying) {
    if (nowPlaying == _episodeLive) return;
    _episodeLive = nowPlaying;
    if (!nowPlaying) return;
    _lastPlayingAt = _clock.now();
    if (_budgetArmed && _budgetEpisodeAt == null) {
      _budgetEpisodeAt = _lastPlayingAt;
    }
    _lastPlayingFromAutoRetry = _pendingAutoRetryAttribution;
    _pendingAutoRetryAttribution = false;
  }

  /// A programmatic play promise rejected (autoplay policy) or the element
  /// errored: the unresolved user play settles as not-playing.
  void noteUserPlayUnresolved() {
    _budgetArmed = false;
    _pendingAutoRetryAttribution = false;
    _lastPlayingFromAutoRetry = false;
  }

  /// End of media observed (DOM `ended` or poll `s` = 2) — the attempt can
  /// never be fulfilled by its own ending.
  void noteEnded() {
    _budgetArmed = false;
    _pendingAutoRetryAttribution = false;
    _lastPlayingFromAutoRetry = false;
  }

  /// Open and clear both start the protocol from scratch, so the two paths
  /// cannot drift apart.
  void reset() {
    _budgetEpisodeAt = null;
    _budgetArmed = false;
    _lastAutoRetryAt = null;
    _autoRetriesIssued = 0;
    _lastPlayingFromAutoRetry = false;
    _pendingAutoRetryAttribution = false;
    _lastPlayingAt = null;
    _episodeLive = false;
  }
}
