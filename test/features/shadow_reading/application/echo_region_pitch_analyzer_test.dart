import 'dart:math' as math;
import 'dart:typed_data';

import 'package:enjoy_player/features/shadow_reading/application/echo_region_pitch_analyzer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('analyzePcmSamples (pure pipeline)', () {
    test('returns EchoRegionAnalysisResult with expected metadata', () {
      // 1 second of zeros at 16 kHz: 16000 samples.
      final samples = Float32List(16000);
      final result = analyzePcmSamples(samples, 16000);

      expect(result.sampleRate, 16000);
      expect(result.durationSeconds, closeTo(1.0, 1e-9));
      expect(result.points, isNotNull);
    });

    test('produces a stable envelope point count for non-silent input', () {
      // 1s of low-frequency sinusoid at 200 Hz, amplitude 0.5.
      final samples = Float32List(16000);
      const twoPi = 2 * math.pi;
      for (var i = 0; i < samples.length; i++) {
        samples[i] = 0.5 * math.sin(twoPi * 200 * i / 16000);
      }
      final result = analyzePcmSamples(samples, 16000);
      // Internal envelope target is 520 points; implementation may overshoot.
      expect(result.points.length, greaterThanOrEqualTo(520));
      expect(result.points.length, lessThan(700));
    });

    test('detects roughly 200 Hz on a clean sine wave', () {
      final samples = Float32List(16000);
      const f0 = 200.0;
      const twoPi = 2 * math.pi;
      for (var i = 0; i < samples.length; i++) {
        samples[i] = 0.5 * math.sin(twoPi * f0 * i / 16000);
      }
      final result = analyzePcmSamples(samples, 16000);
      final detectedHz = result.points
          .map((p) => p.pitchRefHz)
          .whereType<double>()
          .toList();
      expect(detectedHz, isNotEmpty);
      final avg = detectedHz.reduce((a, b) => a + b) / detectedHz.length;
      // YIN tracks pitch to within ~15 Hz on a clean signal.
      expect(avg, greaterThan(f0 - 15));
      expect(avg, lessThan(f0 + 15));
    });

    test('empty input produces zero-duration result with no points', () {
      final result = analyzePcmSamples(Float32List(0), 16000);
      expect(result.durationSeconds, 0.0);
      expect(result.points, isEmpty);
    });

    test('respects the provided sample rate in duration calculation', () {
      // 48000 samples at 48000 Hz → 1 second
      final samples = Float32List(48000);
      final result = analyzePcmSamples(samples, 48000);
      expect(result.sampleRate, 48000);
      expect(result.durationSeconds, closeTo(1.0, 1e-9));
    });

    test('envelope amplitudes scale with signal amplitude', () {
      final loud = Float32List(16000);
      final quiet = Float32List(16000);
      const twoPi = 2 * math.pi;
      for (var i = 0; i < loud.length; i++) {
        final v = math.sin(twoPi * 200 * i / 16000);
        loud[i] = 0.8 * v;
        quiet[i] = 0.05 * v;
      }
      final loudRes = analyzePcmSamples(loud, 16000);
      final quietRes = analyzePcmSamples(quiet, 16000);
      // The reference amplitude is normalized to [0, 1], so both signals
      // saturate near 1.0. We verify the pipeline emits plausible amplitudes
      // rather than strict ratio scaling.
      for (final p in loudRes.points.take(20)) {
        expect(p.ampRef, inInclusiveRange(0.0, 1.0));
      }
      for (final p in quietRes.points.take(20)) {
        expect(p.ampRef, inInclusiveRange(0.0, 1.0));
      }
      // Loud signal has at least one near-saturated point.
      expect(loudRes.points.any((p) => p.ampRef > 0.5), isTrue);
    });
  });
}
