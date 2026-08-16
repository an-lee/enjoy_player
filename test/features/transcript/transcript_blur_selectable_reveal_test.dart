import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_blur_text.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _BlurMode extends TranscriptBlurMode {
  _BlurMode(this._initial);
  final bool _initial;

  @override
  bool build() => _initial;
}

class _KaraokeHighlightOff extends KaraokeHighlightSettings {
  @override
  Future<bool> build() async => false;
}

void main() {
  Widget harness({required bool blurActive}) {
    const line = TranscriptLine(text: 'Echo cue', startMs: 0, durationMs: 2000);
    return ProviderScope(
      overrides: [
        transcriptBlurModeProvider.overrideWith(() => _BlurMode(blurActive)),
        karaokeHighlightSettingsProvider.overrideWith(_KaraokeHighlightOff.new),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: TranscriptLineTile(
            line: line,
            mediaId: 'm1',
            secondaryText: null,
            isActive: true,
            inEcho: true,
            groupedInEcho: true,
            selectable: true,
            onTap: () {},
          ),
        ),
      ),
    );
  }

  testWidgets(
    'hovering a blurred selectable cue reveals it; mouse out re-blurs',
    (tester) async {
      await tester.pumpWidget(harness(blurActive: true));
      await tester.pumpAndSettle();

      final initial = tester.widget<TranscriptBlurText>(
        find.byType(TranscriptBlurText),
      );
      expect(initial.revealed, isFalse);

      final gesture = await tester.createGesture(kind: PointerDeviceKind.mouse);
      await gesture.addPointer();
      final tileCenter = tester.getCenter(find.byType(TranscriptLineTile));
      await gesture.moveTo(tileCenter);
      await tester.pumpAndSettle();

      final revealed = tester.widget<TranscriptBlurText>(
        find.byType(TranscriptBlurText),
      );
      expect(revealed.revealed, isTrue);

      await gesture.moveTo(const Offset(-100, -100));
      await tester.pumpAndSettle();

      final reblurred = tester.widget<TranscriptBlurText>(
        find.byType(TranscriptBlurText),
      );
      expect(reblurred.revealed, isFalse);

      await gesture.removePointer();
    },
  );

  testWidgets('tapping a blurred selectable cue reveals it (hold)', (
    tester,
  ) async {
    await tester.pumpWidget(harness(blurActive: true));
    await tester.pumpAndSettle();

    final initial = tester.widget<TranscriptBlurText>(
      find.byType(TranscriptBlurText),
    );
    expect(initial.revealed, isFalse);

    await tester.tap(find.byType(SelectableText));
    await tester.pump();

    final revealed = tester.widget<TranscriptBlurText>(
      find.byType(TranscriptBlurText),
    );
    expect(revealed.revealed, isTrue);

    await tester.pump(const Duration(seconds: 4));
  });
}
