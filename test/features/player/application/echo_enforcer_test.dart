import 'dart:async';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_enforcer.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_player_engine.dart';

void main() {
  // Echo segment 0–5 s over two cues at 0–2 s and 2–5 s.
  List<TranscriptLine> lines() => const [
    TranscriptLine(text: 'a', startMs: 0, durationMs: 2000),
    TranscriptLine(text: 'b', startMs: 2000, durationMs: 3000),
  ];

  test(
    'reset during an in-flight enforcement drops the queued clamp seek',
    () async {
      final h = _Harness(lines: lines());
      addTearDown(h.dispose);
      h.activateEcho(startSeconds: 0, endSeconds: 5);

      // Reactive pause-and-rewind, with its rewind seek held in flight.
      final gate = Completer<void>();
      h.engine.seekGate = gate;
      final tick = h.enforcer.enforceTick(4.97);
      await Future<void>.delayed(Duration.zero);
      expect(h.engine.pauseCallCount, 1);
      expect(h.engine.seekCalls, [Duration.zero]);

      // A user seek queues behind it, then the media is switched (reset) before
      // the rewind settles.
      final clamp = h.enforcer.clampAndSeek(9.0);
      h.enforcer.reset();
      gate.complete();

      // Nothing may be sought on the (new) engine: the stale request would land
      // unclamped there, its echo being inactive.
      expect(
        await clamp,
        9.0,
        reason: 'the abandoned request is reported back unclamped',
      );
      expect(h.engine.seekCalls, hasLength(1));
      await tick;
    },
  );

  test(
    'a never-settling enforcement is released by the wait timeout',
    () async {
      final h = _Harness(lines: lines());
      addTearDown(h.dispose);
      h.activateEcho(startSeconds: 0, endSeconds: 5);

      // The rewind seek never completes (wedged engine).
      h.engine.seekGate = Completer<void>();
      unawaited(h.enforcer.enforceTick(4.97));
      await Future<void>.delayed(Duration.zero);
      expect(h.engine.pauseCallCount, 1);

      final clamped = await h.enforcer.clampAndSeek(
        9.0,
        waitTimeout: const Duration(milliseconds: 20),
      );

      expect(
        clamped,
        9.0,
        reason: 'returns instead of hanging on the wedged op',
      );
      expect(h.engine.seekCalls, hasLength(1));

      // The slot is released, so enforcement keeps working for the session.
      expect(
        await h.enforcer.clampAndSeek(
          3.0,
          waitTimeout: const Duration(milliseconds: 20),
        ),
        3.0,
      );
      expect(h.engine.seekCalls, hasLength(2));
    },
  );

  test('window derivation is memoized across position events', () async {
    final h = _Harness(lines: lines());
    addTearDown(h.dispose);
    h.activateEcho(startSeconds: 0, endSeconds: 5);

    for (var i = 0; i < 20; i++) {
      await h.enforcer.enforceTick(1.0 + i * 0.01);
    }
    expect(
      h.lineProbeCalls,
      1,
      reason: 'the derivation must not run on every position event',
    );

    // ...but an input that actually changed must re-derive, not serve stale
    // boundaries.
    h.durationSeconds = 60;
    await h.enforcer.enforceTick(1.0);
    expect(h.lineProbeCalls, 2);
  });

  test('an override window is never served from the cache', () async {
    final h = _Harness(lines: lines());
    addTearDown(h.dispose);
    h.activateEcho(startSeconds: 0, endSeconds: 5);

    await h.enforcer.enforceTick(3.0);
    expect(h.lineProbeCalls, 1);

    // A freshly tapped cue wins over the cached window...
    await h.enforcer.clampAndSeek(9.0, override: (start: 1, end: 2));
    expect(h.engine.seekCalls, [const Duration(milliseconds: 1980)]);

    // ...without clobbering the cache for the reactive ticks.
    await h.enforcer.enforceTick(3.0);
    expect(h.lineProbeCalls, 1);
  });
}

/// Wires an [EchoEnforcer] to a [FakePlayerEngine] through a real container so
/// the echo mode notifier and the provider reads behave as in production.
class _Harness {
  _Harness({required this.lines}) {
    final container = ProviderContainer();
    this.container = container;
    final harness = this;
    enforcer = container.read(
      Provider<EchoEnforcer>(
        (ref) => EchoEnforcer(
          ref: ref,
          getEngine: () => engine,
          getSession: () => session,
          getLines: () {
            harness.lineProbeCalls++;
            return harness.lines;
          },
        ),
      ),
    );
  }

  final FakePlayerEngine engine = FakePlayerEngine();
  final List<TranscriptLine> lines;
  late final ProviderContainer container;
  late final EchoEnforcer enforcer;

  int lineProbeCalls = 0;

  double durationSeconds = 120;

  PlaybackSession get session => _sessionAt(durationSeconds);

  void activateEcho({
    required double startSeconds,
    required double endSeconds,
  }) {
    container
        .read(echoModeProvider.notifier)
        .activate(
          startLineIndex: 0,
          endLineIndex: lines.length - 1,
          startTimeSeconds: startSeconds,
          endTimeSeconds: endSeconds,
        );
  }

  void dispose() => container.dispose();
}

PlaybackSession _sessionAt(double durationSeconds) {
  final now = DateTime.now();
  return PlaybackSession(
    mediaId: 'media-1',
    dexieTargetType: 'Audio',
    mediaType: 'audio',
    mediaTitle: 't',
    durationSeconds: durationSeconds,
    currentTimeSeconds: 0,
    currentSegmentIndex: 0,
    language: 'en',
    startedAt: now,
    lastActiveAt: now,
  );
}
