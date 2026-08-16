import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/player/domain/word_loop.dart';

void main() {
  group('decideWordLoopTick', () {
    test('inside window is ok', () {
      expect(
        decideWordLoopTick(positionMs: 1200, startMs: 1000, endMs: 1500),
        WordLoopTickDecision.ok,
      );
    });

    test('just past the end wraps', () {
      expect(
        decideWordLoopTick(positionMs: 1500, startMs: 1000, endMs: 1500),
        WordLoopTickDecision.wrap,
      );
      expect(
        decideWordLoopTick(positionMs: 1799, startMs: 1000, endMs: 1500),
        WordLoopTickDecision.wrap,
      );
    });

    test('jump well outside the window cancels', () {
      expect(
        decideWordLoopTick(positionMs: 1800, startMs: 1000, endMs: 1500),
        WordLoopTickDecision.cancel,
      );
      expect(
        decideWordLoopTick(positionMs: 0, startMs: 1000, endMs: 1500),
        WordLoopTickDecision.cancel,
      );
    });

    test('invalid window cancels', () {
      expect(
        decideWordLoopTick(positionMs: 1000, startMs: 1500, endMs: 1500),
        WordLoopTickDecision.cancel,
      );
    });
  });
}
