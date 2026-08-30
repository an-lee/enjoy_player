/// Monotonic timing for the YouTube engine's protocols (issue #665).
///
/// Every elapsed-time budget in the play-then-pause saga was measured against
/// `DateTime.now()`. A wall clock is the wrong instrument for a *duration*:
/// an NTP step, a manual clock change, or a timezone/DST edit jumps every
/// budget at once — a two-second window can expire instantly or never, with
/// no log line to explain it. [Stopwatch] reads a monotonic source, so the
/// budgets below only ever measure how long *something has been true*, never
/// what the calendar says.
///
/// The clock is injected rather than constructed so tests advance protocol
/// time deterministically (`fake.advance(const Duration(seconds: 3))`)
/// instead of sleeping past a real window.
library;

/// A monotonic, injectable time source. `Duration.zero` is an arbitrary
/// epoch — only differences between two [now] reads are meaningful.
abstract interface class MonotonicClock {
  Duration now();
}

/// Production clock: [Stopwatch] is backed by the platform's monotonic timer,
/// so system clock changes cannot move it.
final class StopwatchClock implements MonotonicClock {
  StopwatchClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration now() => _stopwatch.elapsed;
}

/// A [MonotonicClock] the test owns. Production code never sees this.
final class FakeMonotonicClock implements MonotonicClock {
  Duration _now = Duration.zero;

  /// Moves the clock forward by [delta]. Never backwards — that is the whole
  /// point of the abstraction.
  void advance(Duration delta) => _now += delta;

  @override
  Duration now() => _now;
}
