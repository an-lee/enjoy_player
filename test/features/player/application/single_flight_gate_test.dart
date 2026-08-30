/// Unit tests for the shared generation-guard / single-flight primitive.
library;

import 'dart:async';

import 'package:enjoy_player/features/player/application/single_flight_gate.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SingleFlightGate generation', () {
    test('isStale is false for a fresh capture and true after a bump', () {
      final gate = SingleFlightGate();
      final gen = gate.generation;

      expect(gate.isStale(gen), isFalse);
      gate.bump();
      expect(gate.isStale(gen), isTrue);
      expect(gate.generation, gen + 1);
    });

    test('bump returns the new generation', () {
      final gate = SingleFlightGate();
      expect(gate.bump(), gate.generation);
    });

    test(
      'cancel invalidates captured generations and drops the slot',
      () async {
        final gate = SingleFlightGate();
        final gen = gate.generation;
        final wedged = Completer<void>();
        final done = gate.run(wedged.future);

        expect(gate.inFlight, isTrue);
        gate.cancel();

        expect(gate.isStale(gen), isTrue);
        expect(gate.inFlight, isFalse);

        // The abandoned op settles late; its release must not restore it.
        wedged.complete();
        await done;
        expect(gate.inFlight, isFalse);
      },
    );
  });

  group('SingleFlightGate slot', () {
    test(
      'run claims the slot synchronously and clears it on completion',
      () async {
        final gate = SingleFlightGate();
        final op = Completer<void>();
        final done = gate.run(op.future);

        expect(gate.inFlight, isTrue);
        expect(gate.pending, same(op.future));

        op.complete();
        await done;
        expect(gate.inFlight, isFalse);
        expect(gate.pending, isNull);
      },
    );

    test('run rethrows the op error and still clears the slot', () async {
      final gate = SingleFlightGate();
      final op = Completer<void>();

      final done = gate.run(op.future);
      op.completeError(StateError('seek wedged'));

      await expectLater(done, throwsStateError);
      expect(gate.inFlight, isFalse);
    });

    test('a draining op cannot reclaim a slot it no longer owns', () async {
      final gate = SingleFlightGate();
      final wedged = Completer<void>();
      final done = gate.run(wedged.future);

      // Bounded-wait pattern: the caller gave up and released the slot.
      gate.release(wedged.future);
      expect(gate.inFlight, isFalse);

      final next = Completer<void>();
      final nextDone = gate.run(next.future);
      expect(gate.pending, same(next.future));

      // The wedged op finally settles; its release must be a no-op.
      wedged.complete();
      await done;
      expect(gate.pending, same(next.future));

      next.complete();
      await nextDone;
      expect(gate.inFlight, isFalse);
    });

    test('release is a no-op for a future that never owned the slot', () {
      final gate = SingleFlightGate();
      final held = Completer<void>().future;

      gate.release(held);
      expect(gate.inFlight, isFalse);
    });
  });
}
