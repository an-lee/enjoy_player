import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_markup.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class _BlurMode extends TranscriptBlurMode {
  _BlurMode(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

Widget _harness(Widget child) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
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
    'nested words do not change line text, timestamp, or semantics IPA',
    (tester) async {
      const text = 'Hello world';
      const startMs = 0;
      const durationMs = 2000;
      const lineOnly = TranscriptLine(
        text: text,
        startMs: startMs,
        durationMs: durationMs,
      );
      const nested = TranscriptLine(
        text: text,
        startMs: startMs,
        durationMs: durationMs,
        timeline: [
          TranscriptWord(
            text: 'Hello',
            phones: [
              TranscriptPhone(
                phone: 'æ̃ˈxyz',
                text: 'æ̃ˈxyz',
                startTime: 0,
                endTime: 0.1,
              ),
            ],
          ),
          TranscriptWord(text: 'world'),
        ],
      );
      final timestamp = formatTranscriptTimestampMs(startMs);

      await tester.pumpWidget(
        _harness(Column(children: [_tile(lineOnly), _tile(nested)])),
      );

      expect(find.text(text), findsNWidgets(2));
      expect(find.text(timestamp), findsNWidgets(2));
      expect(find.text('həˈloʊ'), findsNothing);
      expect(find.text('æ̃ˈxyz'), findsNothing);

      final tiles = find.byType(TranscriptLineTile);
      expect(tiles, findsNWidgets(2));
      for (var i = 0; i < 2; i++) {
        final semantics = tester.getSemantics(tiles.at(i));
        final label = semantics.label;
        expect(label, contains(text));
        expect(label, isNot(contains('həˈloʊ')));
        expect(label, isNot(contains('æ̃ˈxyz')));
      }
    },
  );
}
