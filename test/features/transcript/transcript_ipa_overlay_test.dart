import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_markup.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_word_ipa_layer.dart';
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
          phone: 'hɛˈloʊ',
          text: 'hɛˈloʊ',
          startTime: 0,
          endTime: 0.4,
        ),
      ],
    ),
    TranscriptWord(text: 'world', startMs: 800, durationMs: 800),
  ],
);

const _mixedEmptyPhones = TranscriptLine(
  text: 'Hello world',
  startMs: 0,
  durationMs: 2000,
  timeline: [
    TranscriptWord(
      text: 'Hello',
      startMs: 0,
      durationMs: 800,
      phones: [
        TranscriptPhone(phone: '   ', text: '', startTime: 0, endTime: 0.4),
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

const _lineOnly = TranscriptLine(
  text: 'Hello world',
  startMs: 0,
  durationMs: 2000,
);

Widget _harness({
  required Widget child,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
      karaokeHighlightSettingsProvider.overrideWith(_KaraokeOff.new),
      ...extraOverrides,
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  testWidgets(
    'overlay on paints stored IPA; lookup and taps stay orthography/line-level',
    (tester) async {
      var taps = 0;
      String? lookedUp;
      await tester.pumpWidget(
        _harness(
          extraOverrides: transcriptIpaOverlayOnOverrides(),
          child: Column(
            children: [
              TranscriptLineTile(
                line: _nested,
                mediaId: 'test',
                secondaryText: '你好世界',
                isActive: false,
                inEcho: false,
                selectable: false,
                onTap: () => taps++,
              ),
              TranscriptLineTile(
                line: _nested,
                mediaId: 'test',
                secondaryText: null,
                isActive: true,
                inEcho: false,
                selectable: true,
                onLookupRequested: (t) => lookedUp = t,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TranscriptWordIpaLayer), findsWidgets);
      expect(
        transcriptIpaOverlayLabels(
          plain: 'Hello world',
          words: _nested.timeline,
          wordStyle: const TextStyle(fontSize: 16),
          maxWidth: 400,
        ).map((e) => e.text),
        contains('hɛˈloʊ'),
      );
      expect(find.text('Hello world'), findsNWidgets(2));
      expect(find.byType(Chip), findsNothing);

      await tester.tap(find.byType(InkWell).first);
      expect(taps, 1);

      expect(lookedUp, isNull);
      expect(transcriptPlainForSelection(_nested.text), 'Hello world');
    },
  );

  testWidgets('line-only cue has no IPA widgets when overlay is on', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        extraOverrides: transcriptIpaOverlayOnOverrides(),
        child: TranscriptLineTile(
          line: _lineOnly,
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          selectable: false,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello world'), findsOneWidget);
    expect(find.byType(TranscriptWordIpaLayer), findsNothing);
    expect(find.text('hɛˈloʊ'), findsNothing);
  });

  testWidgets('unreadable phones skip that word and do not blank the line', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        extraOverrides: transcriptIpaOverlayOnOverrides(),
        child: TranscriptLineTile(
          line: _mixedEmptyPhones,
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          selectable: false,
          onTap: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Hello world'), findsOneWidget);
    expect(
      transcriptIpaOverlayLabels(
        plain: 'Hello world',
        words: _mixedEmptyPhones.timeline,
        wordStyle: const TextStyle(fontSize: 16),
        maxWidth: 400,
      ).map((e) => e.text),
      ['wɝld'],
    );
    expect(find.byType(Chip), findsNothing);
  });
}
