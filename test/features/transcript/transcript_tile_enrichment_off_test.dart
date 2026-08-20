/// Issue #540 §12 non-regression check, adapted to the shipped gating.
///
/// The global `transcript.timelineEnrichment` toggle was superseded by
/// ADR-0076/0078 (always-on enrichment + per-consumer karaoke/IPA switches),
/// so the guarantee to pin is: a cue carrying nested word/phone data renders
/// byte-identically to a line-only cue while every consumer switch is off.
///
/// This compares the two renderings directly against each other rather than
/// against a committed golden PNG. The claim is a relative one (enriched ==
/// flat), so both frames are rasterized in the same run — there is no stored
/// reference to drift as fonts, Flutter versions, or host platforms change.
library;

import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
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

/// Plain (non-GoogleFonts) typography so the rasterization is deterministic and
/// the tile never hits the network-fetching fallback styles.
const _typography = TranscriptTypographyTokens(
  useSerif: false,
  bodyStyle: TextStyle(fontSize: 16, height: 1.6),
  secondaryStyle: TextStyle(fontSize: 13.5, height: 1.55),
  timestampStyle: TextStyle(fontSize: 12),
);

const _captureKey = ValueKey('enrichment-capture');

/// Pumps [line] into the tile harness and returns the rasterized tile as PNG
/// bytes.
///
/// The image work has to run inside [WidgetTester.runAsync]; `toImage` awaits
/// real engine callbacks that never settle under the default fake-async clock.
Future<Uint8List> _render(WidgetTester tester, TranscriptLine line) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
        ...transcriptIpaOverlayOffOverrides(),
      ],
      child: MaterialApp(
        theme: ThemeData(extensions: const [_typography]),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: SizedBox(
            width: 480,
            child: RepaintBoundary(
              key: _captureKey,
              child: TranscriptLineTile(
                line: line,
                mediaId: 'test',
                secondaryText: null,
                isActive: false,
                inEcho: false,
                groupedInEcho: false,
                selectable: false,
                onTap: () {},
              ),
            ),
          ),
        ),
      ),
    ),
  );

  // Guards against the comparison passing vacuously on two empty frames.
  expect(find.byType(TranscriptLineTile), findsOneWidget);
  expect(tester.getSize(find.byKey(_captureKey)).height, greaterThan(0));

  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(_captureKey),
  );
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage(pixelRatio: 1.0);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  });
  return bytes!;
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

      final flatBytes = await _render(tester, flat);
      final enrichedBytes = await _render(tester, enriched);

      expect(enrichedBytes, equals(flatBytes));
    },
  );
}
