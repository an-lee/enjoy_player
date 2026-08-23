import 'package:enjoy_player/features/player/presentation/widgets/global_transport_bar.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveNarrowTransportBudget always-on invariant (C1)', () {
    for (final width in [
      150.0,
      234.0,
      254.0,
      274.0,
      296.0,
      318.0,
      340.0,
      362.0,
      384.0,
      402.0,
      424.0,
      500.0,
    ]) {
      test('always-on flags true at ${width}px', () {
        final budget = resolveNarrowTransportBudget(
          width,
          hasTranscriptLines: true,
          showFullscreenTransport: false,
        );
        expect(budget.showEcho, isTrue, reason: 'echo always-on');
        expect(budget.showBlur, isFalse, reason: 'blur is in the CC sheet');
        expect(budget.showCc, isTrue, reason: 'cc always-on');
        expect(budget.showSpeed, isTrue, reason: 'speed always-on');
      });
    }
  });

  group('resolveNarrowTransportBudget eligibility gating (C2)', () {
    test('no transcript hides previous and next', () {
      final budget = resolveNarrowTransportBudget(
        500,
        hasTranscriptLines: false,
        showFullscreenTransport: false,
      );
      expect(budget.showPrevious, isFalse);
      expect(budget.showNext, isFalse);
    });

    test('no fullscreen transport hides fullscreen', () {
      final budget = resolveNarrowTransportBudget(
        500,
        hasTranscriptLines: true,
        showFullscreenTransport: false,
      );
      expect(budget.showFullscreen, isFalse);
    });
  });

  group('resolveNarrowTransportBudget drop order (C3)', () {
    NarrowTransportBudget at(double width) => resolveNarrowTransportBudget(
      width,
      hasTranscriptLines: true,
      showFullscreenTransport: false,
    );

    test('widest shows volume, next, and previous', () {
      final b = at(424);
      expect(b.showVolume, isTrue);
      expect(b.showNext, isTrue);
      expect(b.showPrevious, isTrue);
    });

    test('previous drops before next', () {
      final b = at(318);
      expect(b.showVolume, isTrue);
      expect(b.showNext, isTrue);
      expect(b.showPrevious, isFalse, reason: 'previous drops before next');
    });

    test('next drops before volume', () {
      final b = at(254);
      expect(b.showVolume, isTrue);
      expect(b.showNext, isFalse, reason: 'next drops before volume');
      expect(b.showPrevious, isFalse);
    });

    test('volume drops last among the droppables', () {
      final b = at(220);
      expect(b.showVolume, isFalse);
      expect(b.showNext, isFalse);
      expect(b.showPrevious, isFalse);
      expect(b.showEcho, isTrue);
      expect(b.showBlur, isFalse);
      expect(b.showCc, isTrue);
      expect(b.showSpeed, isTrue);
    });
  });

  group('resolveNarrowTransportBudget strict priority (C4)', () {
    for (var width = 200.0; width <= 500; width += 7) {
      test('no priority inversion at ${width.toInt()}px', () {
        final b = resolveNarrowTransportBudget(
          width,
          hasTranscriptLines: true,
          showFullscreenTransport: false,
        );
        if (b.showPrevious) {
          expect(b.showNext, isTrue, reason: 'previous => next');
        }
        if (b.showNext) {
          expect(b.showVolume, isTrue, reason: 'next => volume');
        }
      });
    }

    test('previous-only never occurs', () {
      for (var w = 200.0; w <= 500; w += 5) {
        final b = resolveNarrowTransportBudget(
          w,
          hasTranscriptLines: true,
          showFullscreenTransport: false,
        );
        expect(
          b.showPrevious && !b.showNext,
          isFalse,
          reason: 'previous shown without next at $w',
        );
      }
    });
  });

  group('resolveNarrowTransportBudget determinism (C6)', () {
    test('same inputs yield same output', () {
      for (var w = 200.0; w <= 500; w += 23) {
        final a = resolveNarrowTransportBudget(
          w,
          hasTranscriptLines: true,
          showFullscreenTransport: false,
        );
        final b = resolveNarrowTransportBudget(
          w,
          hasTranscriptLines: true,
          showFullscreenTransport: false,
        );
        expect(a.showPrevious, b.showPrevious);
        expect(a.showNext, b.showNext);
        expect(a.showVolume, b.showVolume);
      }
    });

    test('does not throw for tiny widths', () {
      expect(
        () => resolveNarrowTransportBudget(
          0,
          hasTranscriptLines: true,
          showFullscreenTransport: false,
        ),
        returnsNormally,
      );
    });
  });

  group('resolveNarrowTransportBudget fullscreen priority (desktop video)', () {
    test('fullscreen is highest priority (last to drop)', () {
      final b = resolveNarrowTransportBudget(
        250,
        hasTranscriptLines: true,
        showFullscreenTransport: true,
      );
      expect(b.showFullscreen, isTrue);
      expect(b.showVolume, isFalse, reason: 'volume drops before fullscreen');
    });
  });
}
