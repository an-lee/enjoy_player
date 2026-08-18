/// Issue #540 §12 non-regression snapshot, adapted to the shipped gating.
///
/// The global `transcript.timelineEnrichment` toggle was superseded by
/// ADR-0076/0078 (always-on enrichment + per-consumer karaoke/IPA switches),
/// so the guarantee to pin is: a cue carrying nested word/phone data renders
/// byte-identically to a line-only cue while every consumer switch is off.
/// Both tiles compare against the SAME golden file.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/typography.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../helpers/transcript_settings_overrides.dart';

class _BlurMode extends TranscriptBlurMode {
  _BlurMode(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

/// Plain (non-GoogleFonts) typography so the golden is deterministic and the
/// tile never hits the network-fetching fallback styles.
const _typography = TranscriptTypographyTokens(
  useSerif: false,
  bodyStyle: TextStyle(fontSize: 16, height: 1.6),
  secondaryStyle: TextStyle(fontSize: 13.5, height: 1.55),
  timestampStyle: TextStyle(fontSize: 12),
);

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
      ...transcriptIpaOverlayOffOverrides(),
    ],
    child: MaterialApp(
      theme: ThemeData(extensions: const [_typography]),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: SizedBox(width: 480, child: child)),
    ),
  );
}

TranscriptLineTile _tile(TranscriptLine line) {
  return TranscriptLineTile(
    line: line,
    mediaId: 'test',
    secondaryText: null,
    isActive: false,
    inEcho: false,
    groupedInEcho: false,
    selectable: false,
    onTap: () {},
  );
}

void main() {
  testWidgets(
    'enriched cue with all switches off renders byte-identical to a flat cue',
    (tester) async {
      tester.view.physicalSize = const Size(960, 400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      const flat = TranscriptLine(
        text: 'Hello world',
        startMs: 1000,
        durationMs: 2000,
      );
      const enriched = TranscriptLine(
        text: 'Hello world',
        startMs: 1000,
        durationMs: 2000,
        timeline: [
          TranscriptWord(
            text: 'Hello',
            startMs: 0,
            durationMs: 800,
            phones: [
              TranscriptPhone(
                phone: 'h',
                text: 'h',
                startTime: 1.0,
                endTime: 1.1,
                wordIndex: 0,
              ),
              TranscriptPhone(
                phone: 'ə',
                text: 'ə',
                startTime: 1.1,
                endTime: 1.5,
                wordIndex: 0,
              ),
              TranscriptPhone(
                phone: 'oʊ',
                text: 'oʊ',
                startTime: 1.5,
                endTime: 1.8,
                wordIndex: 0,
              ),
            ],
          ),
          TranscriptWord(text: 'world', startMs: 800, durationMs: 1200),
        ],
      );

      await tester.pumpWidget(_harness(_tile(flat)));
      await expectLater(
        find.byType(TranscriptLineTile),
        matchesGoldenFile('goldens/transcript_tile_enrichment_off.png'),
      );

      await tester.pumpWidget(_harness(_tile(enriched)));
      await expectLater(
        find.byType(TranscriptLineTile),
        matchesGoldenFile('goldens/transcript_tile_enrichment_off.png'),
      );
    },
  );
}
