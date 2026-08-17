import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/ipa_mapping.dart';
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
    TranscriptWord(
      text: 'Hello',
      startMs: 0,
      durationMs: 800,
      phones: [
        TranscriptPhone(
          phone: 'həˈloʊ',
          text: 'həˈloʊ',
          startTime: 0,
          endTime: 0.4,
        ),
      ],
    ),
    TranscriptWord(
      text: 'world',
      startMs: 800,
      durationMs: 800,
      phones: [
        TranscriptPhone(
          phone: 'wɝld',
          text: 'wɝld',
          startTime: 0.8,
          endTime: 1.2,
        ),
      ],
    ),
  ],
);

Widget _harness({
  required Widget child,
  bool overlay = true,
  bool blur = false,
}) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(blur)),
      karaokeHighlightSettingsProvider.overrideWith(_KaraokeOff.new),
      if (overlay)
        ...transcriptIpaOverlayOnOverrides()
      else
        ...transcriptIpaOverlayOffOverrides(),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  final helloIpa = formatPhonesAsFamiliarIpa(['həˈloʊ']);

  testWidgets('overlay on: timestamp tap still line-seeks', (tester) async {
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

  testWidgets('overlay on: tap IPA does not fire line onTap', (tester) async {
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

    await tester.tap(find.text(helloIpa).first);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('overlay off: orthography tap fires line onTap', (tester) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(
        overlay: false,
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

    await tester.tap(find.text('Hello world'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('selectable row has no line InkWell', (tester) async {
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
    'overlay on + unrevealed blur: IPA is not hittable; line tap seeks',
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

      expect(find.text(helloIpa), findsNothing);
      await tester.tap(find.byType(InkWell));
      await tester.pump();
      expect(taps, 1);
    },
  );
}
