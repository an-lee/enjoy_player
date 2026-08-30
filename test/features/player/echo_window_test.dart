import 'package:enjoy_player/features/player/domain/echo_window.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('normalizeEchoWindow', () {
    test('returns null when inactive', () {
      expect(
        normalizeEchoWindow((
          active: false,
          startTimeSeconds: 1,
          endTimeSeconds: 2,
          durationSeconds: 10.0,
        )),
        isNull,
      );
    });

    test('clamps to duration', () {
      final w = normalizeEchoWindow((
        active: true,
        startTimeSeconds: 0,
        endTimeSeconds: 100,
        durationSeconds: 10.0,
      ));
      expect(w!.start, 0);
      expect(w.end, 10.0);
    });

    test('widens a sub-guard window to the minimum playable width', () {
      // 20 ms < endGuard (40 ms): every position would fire pause-and-rewind.
      final w = normalizeEchoWindow((
        active: true,
        startTimeSeconds: 1.0,
        endTimeSeconds: 1.02,
        durationSeconds: 10.0,
      ));
      expect(
        w!.end - w.start,
        closeTo(
          defaultEchoEndGuardSeconds + defaultEchoSeekEpsilonSeconds,
          1e-9,
        ),
      );
      expect(w.start, 1.0);
    });

    test('drops a minimum-width window that cannot fit the media', () {
      // Remaining tail is shorter than endGuard + seekEpsilon — no way to
      // build a window the enforcer can hold without looping.
      final w = normalizeEchoWindow((
        active: true,
        startTimeSeconds: 9.99,
        endTimeSeconds: 10.0,
        durationSeconds: 10.0,
      ));
      expect(w, isNull);
    });

    test('does not widen windows already past the minimum', () {
      final w = normalizeEchoWindow((
        active: true,
        startTimeSeconds: 1.0,
        endTimeSeconds: 1.2,
        durationSeconds: 10.0,
      ));
      expect(w!.start, 1.0);
      expect(w.end, 1.2);
    });
  });

  test('rewinding to a normalized sub-guard window start stays playable', () {
    // The busy-loop: pause-and-rewind seeks to `start`, and if `start` is
    // already past `end - endGuard` the next tick fires pause-and-rewind
    // again. After widening, the rewind target must be playable.
    final w = normalizeEchoWindow((
      active: true,
      startTimeSeconds: 4.0,
      endTimeSeconds: 4.03,
      durationSeconds: 30.0,
    ))!;
    expect(decideEchoPlaybackTime(w.start, w), isA<EchoOk>());
    expect(clampSeekTimeToEchoWindow(w.start, w), w.start);
  });

  test('clampSeekTimeToEchoWindow stays before end', () {
    final w = (start: 1.0, end: 3.0);
    final t = clampSeekTimeToEchoWindow(10.0, w);
    expect(t, lessThan(w.end));
    expect(t, greaterThanOrEqualTo(w.start));
  });

  test('decideEchoPlaybackTime pauses-and-rewinds near end', () {
    final w = (start: 1.0, end: 2.0);
    final d = decideEchoPlaybackTime(2.0, w);
    expect(d, isA<EchoPauseAndRewind>());
    expect((d as EchoPauseAndRewind).timeSeconds, w.start);
  });

  test('decideEchoPlaybackTime clamps before start-guard', () {
    final w = (start: 1.0, end: 2.0);
    final d = decideEchoPlaybackTime(0.5, w);
    expect(d, isA<EchoClamp>());
    expect((d as EchoClamp).timeSeconds, w.start);
  });

  test('decideEchoPlaybackTime clamps NaN to window start', () {
    final w = (start: 1.0, end: 2.0);
    final d = decideEchoPlaybackTime(double.nan, w);
    expect(d, isA<EchoClamp>());
    expect((d as EchoClamp).timeSeconds, w.start);
  });

  test('decideEchoPlaybackTime is ok inside window', () {
    final w = (start: 1.0, end: 2.0);
    final d = decideEchoPlaybackTime(1.5, w);
    expect(d, isA<EchoOk>());
  });
}
