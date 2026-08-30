/// One generation-guard / single-flight primitive for engine-adjacent async work.
library;

/// Monotonic generation guard plus an identity-guarded in-flight slot.
///
/// Four call sites (`EchoEnforcer`, `WordLoopEnforcer`,
/// `CompletionLoop`, `PlayerController._openGeneration`) hand-rolled the same
/// trio of fields — a counter that is bumped on every event that invalidates
/// the current stint, a value captured at entry, and a staleness check after
/// each `await`. This extracts the shared mechanics; the per-site *policy*
/// (what a generation means, when to bump, whether an op may be cancelled
/// mid-await) stays at the call site.
///
/// Capture-at-entry / staleness:
/// ```dart
/// final gen = gate.generation; // capture before the first await
/// await engine.seek(...);
/// if (gate.isStale(gen)) return; // a bump landed while we awaited
/// ```
///
/// Single-flight: at most one op holds [run]'s slot at a time. The slot is
/// claimed synchronously, so two synchronous position events cannot both
/// enter. Completion clears the slot only if the completing op still owns it,
/// so a slot dropped by [cancel] (or by [release]) cannot be clobbered by a
/// draining op's late `finally`.
///
/// Not every variant fits. `CompletionLoop` needs a *cancelable* await (its
/// `bump` completes a `Completer` that the in-flight await races) and keys its
/// "loop is running" marker by generation rather than by op identity — it
/// keeps those as local fields and only shares this class's *concept*.
class SingleFlightGate {
  /// Bumped by [bump] / [cancel]; ops bail when their captured value differs.
  int _generation = 0;

  /// The op currently holding the slot, or `null`. Set synchronously by
  /// [run], so the "is something in flight?" check is race-free across two
  /// synchronous events.
  Future<void>? _inFlight;

  /// The current generation. Capture it into a local before the first `await`
  /// and pass it back to [isStale] afterwards.
  int get generation => _generation;

  /// Whether [generation] has been superseded by a [bump] / [cancel].
  bool isStale(int generation) => generation != _generation;

  /// True while an op holds the slot. Callers that should drop work when an
  /// op is already running check this *before* doing anything else.
  bool get inFlight => _inFlight != null;

  /// The op currently holding the slot, or `null`.
  ///
  /// Exposed for the bounded-wait pattern: a caller that must not be held
  /// hostage by a wedged engine command awaits [pending] with a timeout and
  /// calls [release] when the timeout fires.
  Future<void>? get pending => _inFlight;

  /// Invalidates every captured generation and drops the slot.
  ///
  /// The op that was holding the slot keeps draining, but its own completion
  /// no longer finds itself in the slot (identity-guarded), and any post-`await`
  /// [isStale] check stops it from acting on the next stint.
  void cancel() {
    _generation++;
    _inFlight = null;
  }

  /// Invalidates every captured generation without touching the slot.
  ///
  /// For sites whose in-flight slot is not owned by [run] (e.g. a latch reset
  /// under other conditions) but whose captured generations must be invalidated.
  int bump() => ++_generation;

  /// Claims the slot for [op] and awaits it to completion, rethrowing any
  /// error [op] throws after clearing the slot.
  ///
  /// [op] is created by the caller so its synchronous prefix runs before the
  /// claim — exactly where the call site used to build its future.
  Future<void> run(Future<void> op) async {
    _inFlight = op;
    try {
      await op;
    } finally {
      release(op);
    }
  }

  /// Drops the slot if [op] still owns it.
  ///
  /// Called by [run]'s `finally` and directly by a caller that gave up on a
  /// wedged [pending] after its own timeout.
  void release(Future<void> op) {
    if (identical(_inFlight, op)) _inFlight = null;
  }
}
