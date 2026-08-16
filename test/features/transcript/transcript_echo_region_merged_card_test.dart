import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_line_recording_counts_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_echo_region_merged_card.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/transcript_settings_overrides.dart';

class _KaraokeHighlightOff extends KaraokeHighlightSettings {
  @override
  Future<bool> build() async => false;
}

void main() {
  testWidgets('echo card lays out inside a scrollable', (tester) async {
    const lines = [
      TranscriptLine(text: 'First echo line', startMs: 0, durationMs: 1000),
      TranscriptLine(text: 'Second echo line', startMs: 1000, durationMs: 1000),
    ];
    const echo = EchoState(
      active: true,
      startLineIndex: 0,
      endLineIndex: 1,
      startTimeSeconds: -1,
      endTimeSeconds: -1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transcriptLineRecordingCountsProvider(
            'media-1',
          ).overrideWithValue(const {}),
          karaokeHighlightSettingsProvider.overrideWith(
            _KaraokeHighlightOff.new,
          ),
          ...transcriptWordPracticeOffOverrides(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: const [
                EchoRegionMergedCard(
                  mediaId: 'media-1',
                  lines: lines,
                  echo: echo,
                  activeCueIndex: 0,
                  secondaryLines: [],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(tester.takeException(), isNull);
    expect(find.text('First echo line'), findsOneWidget);
    expect(find.text('Second echo line'), findsOneWidget);
  });

  testWidgets('echo card shows recording badge from counts provider', (
    tester,
  ) async {
    const lines = [
      TranscriptLine(text: 'First echo line', startMs: 0, durationMs: 1000),
      TranscriptLine(text: 'Second echo line', startMs: 1000, durationMs: 1000),
    ];
    const echo = EchoState(
      active: true,
      startLineIndex: 0,
      endLineIndex: 1,
      startTimeSeconds: -1,
      endTimeSeconds: -1,
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          transcriptLineRecordingCountsProvider(
            'media-1',
          ).overrideWithValue({0: 2}),
          karaokeHighlightSettingsProvider.overrideWith(
            _KaraokeHighlightOff.new,
          ),
          ...transcriptWordPracticeOffOverrides(),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: ListView(
              children: const [
                EchoRegionMergedCard(
                  mediaId: 'media-1',
                  lines: lines,
                  echo: echo,
                  activeCueIndex: 0,
                  secondaryLines: [],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('echo region uses compact density on mobile', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      const lines = [
        TranscriptLine(text: 'First echo line', startMs: 0, durationMs: 1000),
        TranscriptLine(
          text: 'Second echo line',
          startMs: 1000,
          durationMs: 1000,
        ),
      ];
      const echo = EchoState(
        active: true,
        startLineIndex: 0,
        endLineIndex: 1,
        startTimeSeconds: -1,
        endTimeSeconds: -1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transcriptLineRecordingCountsProvider(
              'media-1',
            ).overrideWithValue(const {}),
            karaokeHighlightSettingsProvider.overrideWith(
              _KaraokeHighlightOff.new,
            ),
            ...transcriptWordPracticeOffOverrides(),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: const EchoRegionMergedCard(
                    mediaId: 'media-1',
                    lines: lines,
                    echo: echo,
                    activeCueIndex: 0,
                    secondaryLines: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      // Mobile density was applied: the divider thickness on the
      // EchoRegionControlsBar is 0.5 (vs 1.0 desktop).
      final dividers = tester.widgetList<Divider>(find.byType(Divider));
      expect(dividers, isNotEmpty);
      expect(dividers.first.thickness, 0.5);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });

  testWidgets('echo region uses full density on desktop', (tester) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      const lines = [
        TranscriptLine(text: 'First echo line', startMs: 0, durationMs: 1000),
        TranscriptLine(
          text: 'Second echo line',
          startMs: 1000,
          durationMs: 1000,
        ),
      ];
      const echo = EchoState(
        active: true,
        startLineIndex: 0,
        endLineIndex: 1,
        startTimeSeconds: -1,
        endTimeSeconds: -1,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transcriptLineRecordingCountsProvider(
              'media-1',
            ).overrideWithValue(const {}),
            karaokeHighlightSettingsProvider.overrideWith(
              _KaraokeHighlightOff.new,
            ),
            ...transcriptWordPracticeOffOverrides(),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: SingleChildScrollView(
                child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 400),
                  child: const EchoRegionMergedCard(
                    mediaId: 'media-1',
                    lines: lines,
                    echo: echo,
                    activeCueIndex: 0,
                    secondaryLines: [],
                  ),
                ),
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
      final dividers = tester.widgetList<Divider>(find.byType(Divider));
      expect(dividers, isNotEmpty);
      expect(dividers.first.thickness, 1.0);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  });
}
