/// Pure word-loop tick decisions (no Flutter, no engine).
library;

enum WordLoopTickDecision { ok, wrap, cancel }

/// How to treat [positionMs] while a word loop `[startMs, endMs)` is active.
///
/// Just past the end (engine tick granularity) wraps. A jump well outside
/// the window (scrub) cancels.
WordLoopTickDecision decideWordLoopTick({
  required int positionMs,
  required int startMs,
  required int endMs,
}) {
  if (endMs <= startMs) return WordLoopTickDecision.cancel;
  if (positionMs >= startMs && positionMs < endMs) {
    return WordLoopTickDecision.ok;
  }
  if (positionMs >= endMs && positionMs < endMs + 300) {
    return WordLoopTickDecision.wrap;
  }
  return WordLoopTickDecision.cancel;
}
