import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final lines = <TranscriptLine>[
    const TranscriptLine(text: 'line 1', startMs: 0, durationMs: 2000),
    const TranscriptLine(text: 'line 2', startMs: 2000, durationMs: 2000),
    const TranscriptLine(text: 'line 3', startMs: 4000, durationMs: 2000),
    const TranscriptLine(text: 'line 4', startMs: 6000, durationMs: 2000),
    const TranscriptLine(text: 'line 5', startMs: 8000, durationMs: 2000),
  ];

  late ProviderContainer container;
  late EchoMode notifier;
  late EchoState lastState;

  setUp(() {
    container = ProviderContainer();
    notifier = container.read(echoModeProvider.notifier);
    lastState = EchoState.inactive;
    container.listen<EchoState>(echoModeProvider, (prev, next) {
      lastState = next;
    });
  });

  tearDown(() {
    container.dispose();
  });

  group('EchoMode', () {
    test('activate sets echo region', () {
      notifier.activate(
        startLineIndex: 1,
        endLineIndex: 2,
        startTimeSeconds: 2.0,
        endTimeSeconds: 6.0,
      );

      expect(lastState.active, isTrue);
      expect(lastState.startLineIndex, 1);
      expect(lastState.endLineIndex, 2);
      expect(lastState.startTimeSeconds, 2.0);
      expect(lastState.endTimeSeconds, 6.0);
    });

    test('deactivate resets to inactive', () {
      notifier.activate(
        startLineIndex: 1,
        endLineIndex: 2,
        startTimeSeconds: 2.0,
        endTimeSeconds: 6.0,
      );
      notifier.deactivate();

      expect(lastState, EchoState.inactive);
    });

    test('restoreFromSession activates with ms-to-seconds conversion', () {
      notifier.restoreFromSession(
        startLine: 0,
        endLine: 1,
        echoStartMs: 1000,
        echoEndMs: 4000,
      );

      expect(lastState.active, isTrue);
      expect(lastState.startLineIndex, 0);
      expect(lastState.endLineIndex, 1);
      expect(lastState.startTimeSeconds, 1.0);
      expect(lastState.endTimeSeconds, 4.0);
    });

    group('expandEchoBackward', () {
      test('extends start backward by one line', () {
        notifier.activate(
          startLineIndex: 2,
          endLineIndex: 3,
          startTimeSeconds: 4.0,
          endTimeSeconds: 8.0,
        );

        notifier.expandEchoBackward(lines);

        expect(lastState.startLineIndex, 1);
        expect(lastState.startTimeSeconds, 2.0);
        expect(lastState.endLineIndex, 3);
      });

      test('does nothing when already at first line', () {
        notifier.activate(
          startLineIndex: 0,
          endLineIndex: 2,
          startTimeSeconds: 0.0,
          endTimeSeconds: 6.0,
        );

        notifier.expandEchoBackward(lines);

        expect(lastState.startLineIndex, 0);
      });

      test('does nothing when inactive', () {
        notifier.expandEchoBackward(lines);
        expect(lastState.active, isFalse);
      });

      test('does nothing with empty lines', () {
        notifier.activate(
          startLineIndex: 1,
          endLineIndex: 2,
          startTimeSeconds: 2.0,
          endTimeSeconds: 6.0,
        );

        notifier.expandEchoBackward([]);

        expect(lastState.startLineIndex, 1);
      });
    });

    group('expandEchoForward', () {
      test('extends end forward by one line', () {
        notifier.activate(
          startLineIndex: 1,
          endLineIndex: 2,
          startTimeSeconds: 2.0,
          endTimeSeconds: 6.0,
        );

        notifier.expandEchoForward(lines);

        expect(lastState.endLineIndex, 3);
        expect(lastState.endTimeSeconds, 8.0);
        expect(lastState.startLineIndex, 1);
      });

      test('does nothing when already at last line', () {
        notifier.activate(
          startLineIndex: 2,
          endLineIndex: 4,
          startTimeSeconds: 4.0,
          endTimeSeconds: 10.0,
        );

        notifier.expandEchoForward(lines);

        expect(lastState.endLineIndex, 4);
      });

      test('does nothing when inactive', () {
        notifier.expandEchoForward(lines);
        expect(lastState.active, isFalse);
      });
    });

    group('shrinkEchoBackward', () {
      test('removes first line from echo region', () {
        notifier.activate(
          startLineIndex: 1,
          endLineIndex: 3,
          startTimeSeconds: 2.0,
          endTimeSeconds: 8.0,
        );

        notifier.shrinkEchoBackward(lines);

        expect(lastState.startLineIndex, 2);
        expect(lastState.startTimeSeconds, 4.0);
        expect(lastState.endLineIndex, 3);
      });

      test('does nothing when start equals end (single line)', () {
        notifier.activate(
          startLineIndex: 2,
          endLineIndex: 2,
          startTimeSeconds: 4.0,
          endTimeSeconds: 6.0,
        );

        notifier.shrinkEchoBackward(lines);

        expect(lastState.startLineIndex, 2);
      });

      test('does nothing when inactive', () {
        notifier.shrinkEchoBackward(lines);
        expect(lastState.active, isFalse);
      });
    });

    group('shrinkEchoForward', () {
      test('removes last line from echo region', () {
        notifier.activate(
          startLineIndex: 1,
          endLineIndex: 3,
          startTimeSeconds: 2.0,
          endTimeSeconds: 8.0,
        );

        notifier.shrinkEchoForward(lines);

        expect(lastState.endLineIndex, 2);
        expect(lastState.endTimeSeconds, 6.0);
        expect(lastState.startLineIndex, 1);
      });

      test('does nothing when end equals start (single line)', () {
        notifier.activate(
          startLineIndex: 2,
          endLineIndex: 2,
          startTimeSeconds: 4.0,
          endTimeSeconds: 6.0,
        );

        notifier.shrinkEchoForward(lines);

        expect(lastState.endLineIndex, 2);
      });

      test('does nothing when inactive', () {
        notifier.shrinkEchoForward(lines);
        expect(lastState.active, isFalse);
      });
    });
    group('re-segmented transcript (issue #659)', () {
      // `restoreFromSession` persists line indices without validation; a
      // re-import that shortened the transcript leaves them past the end.
      final shortLines = <TranscriptLine>[
        const TranscriptLine(text: 'only', startMs: 0, durationMs: 2000),
      ];

      test('restoreFromSession with out-of-range indices', () {
        notifier.restoreFromSession(
          startLine: 4,
          endLine: 4,
          echoStartMs: 8000,
          echoEndMs: 10000,
        );
        expect(lastState.active, isTrue);
        expect(lastState.startLineIndex, 4);
      });

      test('expandEchoBackward does not throw past the end', () {
        notifier.restoreFromSession(
          startLine: 4,
          endLine: 4,
          echoStartMs: 8000,
          echoEndMs: 10000,
        );

        notifier.expandEchoBackward(shortLines);

        expect(lastState.startLineIndex, 4);
        expect(lastState.endLineIndex, 4);
      });

      test('shrinkEchoBackward does not throw past the end', () {
        notifier.restoreFromSession(
          startLine: 0,
          endLine: 6,
          echoStartMs: 0,
          echoEndMs: 14000,
        );

        notifier.shrinkEchoBackward(shortLines);

        expect(lastState.startLineIndex, 0);
        expect(lastState.endLineIndex, 6);
      });

      test('shrinkEchoForward does not throw past the end', () {
        notifier.restoreFromSession(
          startLine: 0,
          endLine: 6,
          echoStartMs: 0,
          echoEndMs: 14000,
        );

        notifier.shrinkEchoForward(shortLines);

        expect(lastState.startLineIndex, 0);
        expect(lastState.endLineIndex, 6);
      });

      test('expandEchoForward does not throw with a negative start', () {
        notifier.restoreFromSession(
          startLine: -1,
          endLine: 3,
          echoStartMs: 0,
          echoEndMs: 6000,
        );

        notifier.expandEchoForward(shortLines);

        expect(lastState.startLineIndex, -1);
        expect(lastState.endLineIndex, 3);
      });

      test(
        'echo keeps working once indices fit the re-imported transcript',
        () {
          notifier.restoreFromSession(
            startLine: 0,
            endLine: 6,
            echoStartMs: 0,
            echoEndMs: 14000,
          );
          notifier.shrinkEchoForward(shortLines);
          expect(lastState.endLineIndex, 6);

          notifier.activate(
            startLineIndex: 0,
            endLineIndex: 0,
            startTimeSeconds: 0,
            endTimeSeconds: 2,
          );
          notifier.expandEchoForward(shortLines);
          expect(lastState.endLineIndex, 0);
        },
      );
    });
  });

  group('EchoState', () {
    test('equal states are equal', () {
      const a = EchoState(
        active: true,
        startLineIndex: 1,
        endLineIndex: 2,
        startTimeSeconds: 2.0,
        endTimeSeconds: 6.0,
      );
      const b = EchoState(
        active: true,
        startLineIndex: 1,
        endLineIndex: 2,
        startTimeSeconds: 2.0,
        endTimeSeconds: 6.0,
      );
      expect(a, b);
      expect(a.hashCode, b.hashCode);
    });

    test('different states are not equal', () {
      const a = EchoState(
        active: true,
        startLineIndex: 1,
        endLineIndex: 2,
        startTimeSeconds: 2.0,
        endTimeSeconds: 6.0,
      );
      const b = EchoState(
        active: true,
        startLineIndex: 0,
        endLineIndex: 2,
        startTimeSeconds: 0.0,
        endTimeSeconds: 6.0,
      );
      expect(a, isNot(b));
    });

    test('copyWith overrides specified fields only', () {
      const original = EchoState(
        active: true,
        startLineIndex: 1,
        endLineIndex: 2,
        startTimeSeconds: 2.0,
        endTimeSeconds: 6.0,
      );

      final copied = original.copyWith(startLineIndex: 0);

      expect(copied.startLineIndex, 0);
      expect(copied.endLineIndex, 2);
      expect(copied.active, isTrue);
      expect(copied.startTimeSeconds, 2.0);
    });

    test('inactive constant has expected values', () {
      expect(EchoState.inactive.active, isFalse);
      expect(EchoState.inactive.startLineIndex, -1);
      expect(EchoState.inactive.endLineIndex, -1);
    });
  });
}
