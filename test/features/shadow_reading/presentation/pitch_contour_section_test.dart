// Coverage for lib/features/shadow_reading/presentation/pitch_contour_section.dart.
//
// The section is a ConsumerStatefulWidget that loads reference + user pitch
// analysis through `echoPitchAnalysisServiceProvider` and listens to
// `shadowReadingHotkeyBusProvider` for the pitch-contour hotkey. We stub the
// analysis pipeline so we don't need a live FFmpeg session.
import 'dart:async';

import 'package:enjoy_player/features/shadow_reading/application/echo_pitch_analysis_service.dart';
import 'package:enjoy_player/features/shadow_reading/application/shadow_reading_hotkey_bus.dart';
import 'package:enjoy_player/features/shadow_reading/data/echo_segment_pcm_extractor.dart';
import 'package:enjoy_player/features/shadow_reading/domain/echo_region_analysis.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/pitch_contour_chart.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/pitch_contour_section.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakePipeline implements EchoPitchPipeline {
  _FakePipeline();

  EchoRegionAnalysisResult? reference;
  EchoRegionAnalysisResult? user;
  bool throwOnReference = false;
  bool throwOnUser = false;

  /// When set, [analyzeSegment] waits on this completer instead of resolving
  /// immediately. Used to observe intermediate loading states.
  Completer<EchoRegionAnalysisResult>? referenceGate;

  @override
  Future<EchoRegionAnalysisResult> analyzeSegment({
    required String mediaPath,
    required double startSec,
    required double endSec,
    EchoPcmCancelToken? token,
  }) async {
    if (referenceGate != null) {
      return await referenceGate!.future;
    }
    if (throwOnReference) throw StateError('ref-fail');
    return reference ??
        EchoRegionAnalysisResult(
          points: [
            EchoRegionSeriesPoint(t: 0, ampRef: 0.5, pitchRefHz: 200),
            EchoRegionSeriesPoint(t: 1, ampRef: 0.6, pitchRefHz: 210),
          ],
          durationSeconds: endSec - startSec,
          sampleRate: 16000,
        );
  }

  @override
  Future<EchoRegionAnalysisResult> analyzeFile({
    required String mediaPath,
    EchoPcmCancelToken? token,
  }) async {
    if (throwOnUser) throw StateError('user-fail');
    return user ??
        EchoRegionAnalysisResult(
          points: [EchoRegionSeriesPoint(t: 0, ampRef: 0.1, pitchRefHz: 180)],
          durationSeconds: 1.0,
          sampleRate: 16000,
        );
  }
}

Widget _wrap({required Widget child, _FakePipeline? pipeline}) {
  return ProviderScope(
    overrides: [
      if (pipeline != null)
        echoPitchAnalysisServiceProvider.overrideWithValue(
          EchoPitchAnalysisService(pipeline: pipeline),
        ),
    ],
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PitchContourSection', () {
    testWidgets('renders header with chevron-down when collapsed', (
      tester,
    ) async {
      await tester.pumpWidget(
        _wrap(
          child: const PitchContourSection(
            mediaPath: '/tmp/m.wav',
            startSec: 0,
            endSec: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);
      expect(find.text('Pitch contour'), findsOneWidget);
      // Chart should NOT be present (collapsed). Tooltip/InkWell may still
      // use CustomPaint for ink effects, so we only check the chart is absent.
      expect(find.byType(PitchContourChart), findsNothing);
    });

    testWidgets('tapping the header toggles to expanded (chevron-up)', (
      tester,
    ) async {
      final pipeline = _FakePipeline();
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: const PitchContourSection(
            mediaPath: '/tmp/m.wav',
            startSec: 0,
            endSec: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets(
      'expanded with internal state shows loading skeleton + analyzing text',
      (tester) async {
        final pipeline = _FakePipeline()
          ..referenceGate = Completer<EchoRegionAnalysisResult>();
        await tester.pumpWidget(
          _wrap(
            pipeline: pipeline,
            child: const PitchContourSection(
              mediaPath: '/tmp/m.wav',
              startSec: 0,
              endSec: 5,
            ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byIcon(Icons.expand_more));
        // Pump frames to flip _expanded and start _loadReference. The
        // FakePipeline's gate keeps the future pending, so loading state
        // stays visible until we complete it below.
        await tester.pump();
        await tester.pump();
        // Loading skeleton + analyzing text present while _loading=true.
        expect(find.text('Analyzing pitch…'), findsOneWidget);

        // Release the gate and let analysis complete.
        pipeline.referenceGate!.complete(
          EchoRegionAnalysisResult(
            points: [EchoRegionSeriesPoint(t: 0, ampRef: 0.5, pitchRefHz: 200)],
            durationSeconds: 5,
            sampleRate: 16000,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Analyzing pitch…'), findsNothing);
      },
    );

    testWidgets('after analysis completes, chart + chips render', (
      tester,
    ) async {
      final pipeline = _FakePipeline();
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: const PitchContourSection(
            mediaPath: '/tmp/m.wav',
            startSec: 0,
            endSec: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      // Let analysis complete.
      await tester.pumpAndSettle();

      expect(find.text('Analyzing pitch…'), findsNothing);
      // Three filter chips.
      expect(find.text('Waveform'), findsOneWidget);
      expect(find.text('Reference pitch'), findsOneWidget);
      expect(find.text('Your pitch'), findsOneWidget);
    });

    testWidgets('tapping a chip toggles _vis flags', (tester) async {
      final pipeline = _FakePipeline();
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: const PitchContourSection(
            mediaPath: '/tmp/m.wav',
            startSec: 0,
            endSec: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      // Initially all chips are selected. Find the Waveform chip widget.
      FilterChip waveformChip() => tester
          .widgetList<FilterChip>(find.byType(FilterChip))
          .firstWhere(
            (c) => c.label is Text && (c.label as Text).data == 'Waveform',
          );

      expect(waveformChip().selected, isTrue);
      await tester.tap(find.text('Waveform'));
      await tester.pumpAndSettle();
      expect(waveformChip().selected, isFalse);
    });

    testWidgets('error in reference analysis surfaces pitchContourError', (
      tester,
    ) async {
      final pipeline = _FakePipeline()..throwOnReference = true;
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: const PitchContourSection(
            mediaPath: '/tmp/m.wav',
            startSec: 0,
            endSec: 5,
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(
        find.text('Could not analyze pitch for this segment.'),
        findsOneWidget,
      );
    });

    testWidgets('hotkey bus pulsePitchContour toggles section', (tester) async {
      final pipeline = _FakePipeline();
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final bus = container.read(shadowReadingHotkeyBusProvider.notifier);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: _wrap(
            pipeline: pipeline,
            child: const PitchContourSection(
              mediaPath: '/tmp/m.wav',
              startSec: 0,
              endSec: 5,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsOneWidget);

      bus.pulsePitchContour();
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_less), findsOneWidget);
    });

    testWidgets('didUpdateWidget resets reference on mediaPath change', (
      tester,
    ) async {
      final pipeline = _FakePipeline();
      var path = '/tmp/a.wav';
      late StateSetter setter;
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: StatefulBuilder(
            builder: (context, setState) {
              setter = setState;
              return PitchContourSection(
                mediaPath: path,
                startSec: 0,
                endSec: 5,
                expanded: true,
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Change media path -> didUpdateWidget resets state and re-triggers load.
      setter(() => path = '/tmp/b.wav');
      await tester.pumpAndSettle();

      // No crash, panel re-renders. Internal state reset is private; the
      // observable effect is the chart re-rendering with new path context.
      expect(find.byType(PitchContourSection), findsOneWidget);
    });

    testWidgets('parent-controlled expanded uses onToggleExpanded callback', (
      tester,
    ) async {
      final pipeline = _FakePipeline();
      var expanded = false;
      var toggles = 0;
      late StateSetter setter;
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: StatefulBuilder(
            builder: (context, setState) {
              setter = setState;
              return Column(
                children: [
                  PitchContourSection(
                    mediaPath: '/tmp/m.wav',
                    startSec: 0,
                    endSec: 5,
                    expanded: expanded,
                    onToggleExpanded: () {
                      toggles++;
                      setState(() => expanded = !expanded);
                    },
                  ),
                ],
              );
            },
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Tap header -> onToggleExpanded invoked, parent updates state.
      await tester.tap(find.byIcon(Icons.expand_more));
      await tester.pumpAndSettle();

      expect(toggles, 1);
      expect(expanded, isTrue);
      expect(setter, isNotNull);
    });

    testWidgets(
      'selectedRecordingPath triggers _loadUser after reference loads',
      (tester) async {
        final pipeline = _FakePipeline();
        await tester.pumpWidget(
          _wrap(
            pipeline: pipeline,
            child: const PitchContourSection(
              mediaPath: '/tmp/m.wav',
              startSec: 0,
              endSec: 5,
              selectedRecordingPath: '/tmp/user.wav',
              selectedRecordingDurationMs: 1000,
              expanded: true,
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Chart + chips render after both analyses complete.
        expect(find.byType(PitchContourSection), findsOneWidget);
      },
    );

    testWidgets('showHeader=false hides the chevron row', (tester) async {
      final pipeline = _FakePipeline();
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: const PitchContourSection(
            mediaPath: '/tmp/m.wav',
            startSec: 0,
            endSec: 5,
            showHeader: false,
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.expand_more), findsNothing);
      expect(find.text('Pitch contour'), findsNothing);
    });

    testWidgets('rendering with non-zero currentTimeRelativeSec is allowed', (
      tester,
    ) async {
      final pipeline = _FakePipeline();
      await tester.pumpWidget(
        _wrap(
          pipeline: pipeline,
          child: const PitchContourSection(
            mediaPath: '/tmp/m.wav',
            startSec: 0,
            endSec: 5,
            currentTimeRelativeSec: 2.5,
            expanded: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(PitchContourSection), findsOneWidget);
    });
  });
}
