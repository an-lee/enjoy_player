import 'dart:typed_data';

import 'package:enjoy_player/features/shadow_reading/domain/waveform_envelope.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('computePeakEnvelope', () {
    test('returns empty list for empty samples', () {
      expect(computePeakEnvelope(Float32List(0), 44100), isEmpty);
    });

    test('returns empty list for invalid sample rate', () {
      final samples = Float32List.fromList([0.1, 0.2, 0.3]);
      expect(computePeakEnvelope(samples, 0), isEmpty);
      expect(computePeakEnvelope(samples, -1), isEmpty);
      expect(computePeakEnvelope(samples, double.infinity), isEmpty);
      expect(computePeakEnvelope(samples, double.nan), isEmpty);
    });

    test('produces correct number of points for peak envelope', () {
      // 1000 samples at 1000 Hz = 1 second, request 10 points.
      final samples = Float32List(1000);
      for (var i = 0; i < 1000; i++) {
        samples[i] = 0.5;
      }
      final result = computePeakEnvelope(samples, 1000, points: 10);
      expect(result.length, 10);
    });

    test('normalizes amplitudes to [0, 1] range', () {
      final samples = Float32List.fromList([0.0, 0.5, 1.0, 0.5, 0.0]);
      final result = computePeakEnvelope(
        samples,
        5,
        points: 5,
        enhanceContrast: false,
      );
      for (final pt in result) {
        expect(pt.amp, greaterThanOrEqualTo(0.0));
        expect(pt.amp, lessThanOrEqualTo(1.0));
      }
      // The max sample (1.0) should produce amp=1.0.
      final maxAmp = result.map((p) => p.amp).reduce((a, b) => a > b ? a : b);
      expect(maxAmp, closeTo(1.0, 1e-9));
    });

    test('time values span [0, duration]', () {
      final samples = Float32List(2000); // 2 seconds at 1000 Hz.
      for (var i = 0; i < 2000; i++) {
        samples[i] = 0.3;
      }
      final result = computePeakEnvelope(samples, 1000, points: 20);
      expect(result.first.t, closeTo(0.0, 1e-9));
      expect(result.last.t, closeTo(2.0, 1e-9));
    });

    test('rms envelope type computes RMS values', () {
      final samples = Float32List.fromList([0.5, 0.5, 0.5, 0.5]);
      final result = computePeakEnvelope(
        samples,
        4,
        points: 4,
        envelopeType: WaveformEnvelopeKind.rms,
        enhanceContrast: false,
      );
      expect(result, isNotEmpty);
      // All samples equal → RMS = 0.5, normalized to 1.0.
      for (final pt in result) {
        expect(pt.amp, closeTo(1.0, 1e-6));
      }
    });

    test('hybrid envelope blends peak and RMS', () {
      final samples = Float32List.fromList([1.0, 0.5, 1.0, 0.5]);
      final result = computePeakEnvelope(
        samples,
        4,
        points: 4,
        envelopeType: WaveformEnvelopeKind.hybrid,
        enhanceContrast: false,
      );
      expect(result, isNotEmpty);
      // Hybrid = 0.6*peak + 0.4*rms. All values should be positive.
      for (final pt in result) {
        expect(pt.amp, greaterThan(0.0));
        expect(pt.amp, lessThanOrEqualTo(1.0));
      }
    });

    test('enhanceContrast applies sqrt and dampens quiet parts', () {
      // One loud sample and one very quiet sample.
      final samples = Float32List.fromList([1.0, 0.001]);
      final withContrast = computePeakEnvelope(
        samples,
        2,
        points: 2,
        enhanceContrast: true,
      );
      final withoutContrast = computePeakEnvelope(
        samples,
        2,
        points: 2,
        enhanceContrast: false,
      );
      // With contrast: sqrt(0.001)≈0.0316, which is <0.1 so dampened *0.5≈0.0158.
      // Without contrast: 0.001.
      // sqrt boosts quiet parts but dampening applies, overall the loud part
      // stays at 1.0 in both cases.
      expect(withContrast[0].amp, closeTo(1.0, 1e-9));
      expect(withoutContrast[0].amp, closeTo(1.0, 1e-9));
      // The quiet part with contrast: sqrt(0.001)*0.5 ≈ 0.0158.
      expect(withContrast[1].amp, lessThan(0.05));
    });

    test('clamps points parameter to [8, 2000]', () {
      final samples = Float32List(100);
      for (var i = 0; i < 100; i++) {
        samples[i] = 0.5;
      }
      // Request 2 points → clamped to 8.
      final result = computePeakEnvelope(samples, 100, points: 2);
      expect(result.length, greaterThanOrEqualTo(8));
    });

    test('handles single sample', () {
      final samples = Float32List.fromList([0.8]);
      final result = computePeakEnvelope(samples, 1, points: 8);
      expect(result, isNotEmpty);
      // Single bucket → t=0.
      expect(result.first.t, 0.0);
    });
  });
}
