import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_blur_text.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/gestures.dart';
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
  Widget harness(Widget child, {bool blurActive = true}) {
    return ProviderScope(
      overrides: [
        transcriptBlurModeProvider.overrideWith(() => _BlurMode(blurActive)),
        ...transcriptWordPracticeOffOverrides(),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: child),
      ),
    );
  }

  testWidgets('mouse hover over a blurred cue reveals it; mouse out re-blurs', (
    tester,
  ) async {
    const line = TranscriptLine(text: 'Hover me', startMs: 0, durationMs: 2000);
    await tester.pumpWidget(
      harness(
        TranscriptLineTile(
          line: line,
          mediaId: 'm1',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          groupedInEcho: false,
          selectable: false,
          onTap: () {},
        ),
      ),
    );
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
  });

  testWidgets(
    'when blur practice is OFF the cue is always revealed regardless of hover',
    (tester) async {
      const line = TranscriptLine(
        text: 'Always visible',
        startMs: 0,
        durationMs: 2000,
      );
      await tester.pumpWidget(
        harness(
          TranscriptLineTile(
            line: line,
            mediaId: 'm1',
            secondaryText: null,
            isActive: false,
            inEcho: false,
            groupedInEcho: false,
            selectable: false,
            onTap: () {},
          ),
          blurActive: false,
        ),
      );
      await tester.pumpAndSettle();
      final w = tester.widget<TranscriptBlurText>(
        find.byType(TranscriptBlurText),
      );
      expect(w.revealed, isTrue);
    },
  );
}
