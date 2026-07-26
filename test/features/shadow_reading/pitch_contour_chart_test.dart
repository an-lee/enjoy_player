// Shadow-reading widget + pure-data coverage.
import 'package:enjoy_player/features/shadow_reading/domain/echo_region_analysis.dart';
import 'package:enjoy_player/features/shadow_reading/domain/waveform_envelope.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/pitch_contour_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EchoRegionSeriesPoint', () {
    test('copyWith replaces only the named fields', () {
      const a = EchoRegionSeriesPoint(t: 0.5, ampRef: 0.3, pitchRefHz: 200);
      final b = a.copyWith(ampUser: 0.7, pitchUserHz: 220);
      expect(b.t, 0.5);
      expect(b.ampRef, 0.3);
      expect(b.pitchRefHz, 200);
      expect(b.ampUser, 0.7);
      expect(b.pitchUserHz, 220);
    });

    test('value equality compares all fields', () {
      const a = EchoRegionSeriesPoint(t: 0.5, ampRef: 0.3, pitchRefHz: 200);
      const b = EchoRegionSeriesPoint(t: 0.5, ampRef: 0.3, pitchRefHz: 200);
      const c = EchoRegionSeriesPoint(t: 0.6, ampRef: 0.3, pitchRefHz: 200);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      expect(a, isNot(equals(c)));
    });
  });

  group('mergeUserPitchOntoReference', () {
    test('returns empty list when reference is empty', () {
      expect(
        mergeUserPitchOntoReference(
          referencePoints: const [],
          userPoints: const [
            EchoRegionSeriesPoint(t: 0, ampRef: 0.2, pitchRefHz: 220),
          ],
          referenceDurationSec: 4,
          userDurationSec: 3,
        ),
        isEmpty,
      );
    });

    test('clears user overlays when userPoints empty', () {
      const ref = [
        EchoRegionSeriesPoint(
          t: 0,
          ampRef: 0.1,
          pitchRefHz: 200,
          ampUser: 0.5,
          pitchUserHz: 220,
        ),
      ];
      final merged = mergeUserPitchOntoReference(
        referencePoints: ref,
        userPoints: const [],
        referenceDurationSec: 4,
        userDurationSec: 0,
      );
      expect(merged.first.ampUser, 0);
      expect(merged.first.pitchUserHz, isNull);
    });

    test('maps user pitch onto nearest reference point within tolerance', () {
      const ref = [
        EchoRegionSeriesPoint(t: 0.0, ampRef: 0.1, pitchRefHz: 200),
        EchoRegionSeriesPoint(t: 1.0, ampRef: 0.2, pitchRefHz: 200),
        EchoRegionSeriesPoint(t: 2.0, ampRef: 0.3, pitchRefHz: 200),
      ];
      // user duration 2s -> scale 2 ; user point at t=0.5 maps to ref t=1.0
      const user = [
        EchoRegionSeriesPoint(t: 0.5, ampRef: 0.7, pitchRefHz: 220),
      ];
      final merged = mergeUserPitchOntoReference(
        referencePoints: ref,
        userPoints: user,
        referenceDurationSec: 3,
        userDurationSec: 1.5,
      );
      expect(merged[0].ampUser, 0);
      expect(merged[1].ampUser, 0.7);
      expect(merged[1].pitchUserHz, 220);
      expect(merged[2].ampUser, 0);
    });

    test('ignores user points outside reference tolerance window', () {
      const ref = [
        EchoRegionSeriesPoint(t: 0.0, ampRef: 0.1, pitchRefHz: 200),
        EchoRegionSeriesPoint(t: 2.0, ampRef: 0.2, pitchRefHz: 200),
      ];
      const user = [EchoRegionSeriesPoint(t: 99, ampRef: 0.7, pitchRefHz: 220)];
      final merged = mergeUserPitchOntoReference(
        referencePoints: ref,
        userPoints: user,
        referenceDurationSec: 2,
        userDurationSec: 1,
      );
      expect(merged.every((p) => p.ampUser == 0), isTrue);
      expect(merged.every((p) => p.pitchUserHz == null), isTrue);
    });
  });

  group('EchoMergedSeriesMemo', () {
    test('returns the same instance for identical inputs', () {
      const refResult = EchoRegionAnalysisResult(
        points: [EchoRegionSeriesPoint(t: 0, ampRef: 0.1, pitchRefHz: 200)],
        durationSeconds: 2,
        sampleRate: 8000,
      );
      const userResult = EchoRegionAnalysisResult(
        points: [EchoRegionSeriesPoint(t: 0, ampRef: 0.7, pitchRefHz: 220)],
        durationSeconds: 2,
        sampleRate: 8000,
      );
      final memo = EchoMergedSeriesMemo();
      final a = memo.resolve(
        reference: refResult,
        user: userResult,
        referenceDurationSec: 2,
        userDurationSec: 2,
      );
      final b = memo.resolve(
        reference: refResult,
        user: userResult,
        referenceDurationSec: 2,
        userDurationSec: 2,
      );
      expect(identical(a, b), isTrue);
    });

    test('recomputes after invalidate()', () {
      const refResult = EchoRegionAnalysisResult(
        points: [EchoRegionSeriesPoint(t: 0, ampRef: 0.1, pitchRefHz: 200)],
        durationSeconds: 2,
        sampleRate: 8000,
      );
      final memo = EchoMergedSeriesMemo();
      memo.resolve(
        reference: refResult,
        user: null,
        referenceDurationSec: 2,
        userDurationSec: 0,
      );
      memo.invalidate();
      final after = memo.resolve(
        reference: refResult,
        user: null,
        referenceDurationSec: 2,
        userDurationSec: 0,
      );
      expect(after, isNotEmpty);
    });

    test('returns empty when reference is null', () {
      final memo = EchoMergedSeriesMemo();
      expect(
        memo.resolve(
          reference: null,
          user: null,
          referenceDurationSec: 1,
          userDurationSec: 1,
        ),
        isEmpty,
      );
    });
  });

  group('buildSeriesPoints', () {
    test('zips envelope + pitch lists into echo series points', () {
      final envelope = [
        const WaveformPoint(t: 0.0, amp: 0.1),
        const WaveformPoint(t: 0.5, amp: 0.4),
      ];
      final pitches = <double?>[200, null];
      final points = buildSeriesPoints(
        envelope: envelope,
        pitchHzList: pitches,
      );
      expect(points, hasLength(2));
      expect(points[0].t, 0.0);
      expect(points[0].ampRef, 0.1);
      expect(points[0].pitchRefHz, 200);
      expect(points[1].pitchRefHz, isNull);
      expect(points[1].ampUser, 0);
    });
  });

  group('PitchContourVisibility', () {
    test('copyWith replaces only the named fields', () {
      const a = PitchContourVisibility();
      final b = a.copyWith(showWaveform: false);
      expect(b.showWaveform, isFalse);
      expect(b.showReference, isTrue);
      expect(b.showUser, isTrue);
    });

    test('value equality + hashCode match for identical visibilities', () {
      const a = PitchContourVisibility(showWaveform: false);
      const b = PitchContourVisibility(showWaveform: false);
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
      const c = PitchContourVisibility();
      expect(a, isNot(equals(c)));
    });
  });

  group('PitchContourChart widget', () {
    Widget chartHost(Widget child) => MaterialApp(home: Scaffold(body: child));

    testWidgets('returns SizedBox.shrink for empty points', (tester) async {
      await tester.pumpWidget(
        chartHost(
          const PitchContourChart(
            points: [],
            referenceColor: Colors.red,
            userColor: Colors.blue,
          ),
        ),
      );
      expect(find.byType(PitchContourChart), findsOneWidget);
      // The empty-points branch returns SizedBox.shrink directly (no CustomPaint
      // inside the chart subtree).
      expect(
        find.descendant(
          of: find.byType(PitchContourChart),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });

    testWidgets('renders the CustomPaint for non-empty points', (tester) async {
      await tester.pumpWidget(
        chartHost(
          const PitchContourChart(
            points: [
              EchoRegionSeriesPoint(t: 0.0, ampRef: 0.2, pitchRefHz: 200),
              EchoRegionSeriesPoint(t: 0.5, ampRef: 0.4, pitchRefHz: 220),
              EchoRegionSeriesPoint(t: 1.0, ampRef: 0.3, pitchRefHz: 180),
            ],
            referenceColor: Colors.red,
            userColor: Colors.blue,
            progress: 0.5,
          ),
        ),
      );
      expect(find.byType(PitchContourChart), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PitchContourChart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });

    testWidgets('handles visibility flags with no pitch/user', (tester) async {
      await tester.pumpWidget(
        chartHost(
          const PitchContourChart(
            points: [
              EchoRegionSeriesPoint(t: 0.0, ampRef: 0.2),
              EchoRegionSeriesPoint(t: 1.0, ampRef: 0.2),
            ],
            referenceColor: Colors.red,
            userColor: Colors.blue,
            visibility: PitchContourVisibility(
              showWaveform: false,
              showReference: false,
              showUser: false,
            ),
          ),
        ),
      );
      expect(find.byType(PitchContourChart), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(PitchContourChart),
          matching: find.byType(CustomPaint),
        ),
        findsOneWidget,
      );
    });
  });
}
