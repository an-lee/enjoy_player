import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_markup.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../helpers/transcript_settings_overrides.dart';

class _KaraokeOff extends KaraokeHighlightSettings {
  @override
  Future<bool> build() async => false;
}

class _BlurMode extends TranscriptBlurMode {
  _BlurMode(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

const _nested = TranscriptLine(
  text: 'Hello world',
  startMs: 0,
  durationMs: 2000,
  timeline: [
    TranscriptWord(text: 'Hello', startMs: 0, durationMs: 800),
    TranscriptWord(text: 'world', startMs: 800, durationMs: 800),
  ],
);

Widget _harness({
  required Widget child,
  bool practice = true,
  bool blur = false,
}) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(blur)),
      karaokeHighlightSettingsProvider.overrideWith(_KaraokeOff.new),
      if (practice)
        ...transcriptWordPracticeOnOverrides()
      else
        ...transcriptWordPracticeOffOverrides(),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets('practice on: timestamp tap still line-seeks', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        child: TranscriptLineTile(
          line: _nested,
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          selectable: false,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text(formatTranscriptTimestampMs(0)));
    expect(taps, 1);
  });

  testWidgets('practice on: tap second timed word does not fire line onTap', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        child: SizedBox(
          width: 400,
          child: TranscriptLineTile(
            line: _nested,
            mediaId: 'test',
            secondaryText: null,
            isActive: false,
            inEcho: false,
            selectable: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('Hello world'));
    await tester.tapAt(Offset(rect.left + rect.width * 0.8, rect.center.dy));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('practice off: word tap still fires line onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        practice: false,
        child: SizedBox(
          width: 400,
          child: TranscriptLineTile(
            line: _nested,
            mediaId: 'test',
            secondaryText: null,
            isActive: false,
            inEcho: false,
            selectable: false,
            onTap: () => taps++,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final rect = tester.getRect(find.text('Hello world'));
    await tester.tapAt(Offset(rect.left + rect.width * 0.8, rect.center.dy));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('selectable row does not word-seek; onTap is unused', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        child: TranscriptLineTile(
          line: _nested,
          mediaId: 'test',
          secondaryText: null,
          isActive: true,
          inEcho: false,
          selectable: true,
          onTap: () => taps++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(InkWell), findsNothing);
    expect(taps, 0);
  });

  testWidgets(
    'practice on + unrevealed blur: timed-word tap still line-seeks',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          blur: true,
          child: SizedBox(
            width: 400,
            child: TranscriptLineTile(
              line: _nested,
              mediaId: 'test',
              secondaryText: null,
              isActive: false,
              inEcho: false,
              selectable: false,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final rect = tester.getRect(find.text('Hello world'));
      await tester.tapAt(Offset(rect.left + rect.width * 0.8, rect.center.dy));
      await tester.pump();
      expect(taps, 1);
    },
  );
}
