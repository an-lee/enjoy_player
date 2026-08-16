import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_blur_text.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../helpers/transcript_settings_overrides.dart';

class _BlurMode extends TranscriptBlurMode {
  _BlurMode(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

void main() {
  testWidgets(
    'blur on: 10k-line transcript scrolls without errors and applies blur to '
    'viewport-visible tiles',
    (tester) async {
      const lineCount = 10000;
      final lines = List.generate(
        lineCount,
        (i) => TranscriptLine(
          text: 'Line $i — quick brown fox jumps over the lazy dog',
          startMs: i * 1000,
          durationMs: 1000,
        ),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            transcriptBlurModeProvider.overrideWith(() => _BlurMode(true)),
            ...transcriptWordPracticeOffOverrides(),
          ],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: ListView.builder(
                itemCount: lines.length,
                itemBuilder: (context, i) => TranscriptLineTile(
                  line: lines[i],
                  mediaId: 'm1',
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
      );
      await tester.pumpAndSettle();

      expect(find.byType(TranscriptBlurText), findsWidgets);
      final first = tester
          .widgetList<TranscriptBlurText>(find.byType(TranscriptBlurText))
          .first;
      expect(first.revealed, isFalse);

      await tester.fling(find.byType(ListView), const Offset(0, -4000), 8000);
      await tester.pumpAndSettle();
      expect(tester.takeException(), isNull);
    },
  );
}
