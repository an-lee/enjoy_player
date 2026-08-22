import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_playback_highlight_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../../helpers/transcript_settings_overrides.dart';

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
          phone: 'æ̃ˈxyz',
          text: 'æ̃ˈxyz',
          startTime: 0,
          endTime: 0.1,
        ),
      ],
    ),
    TranscriptWord(text: 'world', startMs: 800, durationMs: 800),
  ],
);

const _lineOnly = TranscriptLine(
  text: 'Hello world',
  startMs: 0,
  durationMs: 2000,
);

bool _spanHasBackground(InlineSpan span) {
  if (span is TextSpan) {
    if (span.style?.backgroundColor != null) return true;
    return span.children?.any(_spanHasBackground) ?? false;
  }
  return false;
}

String? _highlightedPlain(InlineSpan span) {
  final buf = StringBuffer();
  void walk(InlineSpan node) {
    if (node is TextSpan) {
      if (node.style?.backgroundColor != null && node.text != null) {
        buf.write(node.text);
      }
      node.children?.forEach(walk);
    }
  }

  walk(span);
  return buf.isEmpty ? null : buf.toString();
}

bool _tileHasKaraokeHighlight(WidgetTester tester, Finder tile) {
  final richTexts = tester.widgetList<RichText>(
    find.descendant(of: tile, matching: find.byType(RichText)),
  );
  return richTexts.any((rt) => _spanHasBackground(rt.text));
}

String? _tileHighlightedPlain(WidgetTester tester, Finder tile) {
  final richTexts = tester.widgetList<RichText>(
    find.descendant(of: tile, matching: find.byType(RichText)),
  );
  for (final rt in richTexts) {
    final hit = _highlightedPlain(rt.text);
    if (hit != null) return hit;
  }
  return null;
}

Widget _harness({
  required Widget child,
  List<Override> extraOverrides = const [],
}) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
      ...transcriptWordPracticeOffOverrides(),
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
    'karaoke on highlights the current word in place without chips or IPA',
    (tester) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          extraOverrides: [
            transcriptPlaybackHighlightProvider(
              'test',
            ).overrideWithValue((cueIndex: 0, wordIndex: 0)),
          ],
          child: Column(
            children: [
              TranscriptLineTile(
                key: const ValueKey('active'),
                line: _nested,
                mediaId: 'test',
                secondaryText: '你好世界',
                isActive: true,
                inEcho: false,
                groupedInEcho: false,
                selectable: false,
                onTap: () => taps++,
              ),
              TranscriptLineTile(
                key: const ValueKey('inactive'),
                line: _nested,
                mediaId: 'test',
                secondaryText: null,
                isActive: false,
                inEcho: false,
                groupedInEcho: false,
                selectable: false,
                onTap: () => taps++,
              ),
            ],
          ),
        ),
      );

      final active = find.byKey(const ValueKey('active'));
      expect(_tileHighlightedPlain(tester, active), 'Hello');
      expect(find.text('Hello world'), findsNWidgets(2));
      expect(find.text('æ̃ˈxyz'), findsNothing);
      expect(find.text('həˈloʊ'), findsNothing);
      expect(find.byType(Chip), findsNothing);
      expect(find.byType(ActionChip), findsNothing);

      final secondaryRich = tester.widget<RichText>(
        find.descendant(of: active, matching: find.byType(RichText)).last,
      );
      expect(_highlightedPlain(secondaryRich.text), isNull);

      await tester.tap(
        find.descendant(
          of: find.byKey(const ValueKey('inactive')),
          matching: find.byType(InkWell),
        ),
      );
      expect(taps, 1);
    },
  );

  testWidgets('karaoke on with a line-only active cue looks like karaoke off', (
    tester,
  ) async {
    await tester.pumpWidget(
      _harness(
        extraOverrides: [
          transcriptPlaybackHighlightProvider(
            'test',
          ).overrideWithValue((cueIndex: 0, wordIndex: 0)),
        ],
        child: Column(
          children: [
            TranscriptLineTile(
              key: const ValueKey('timed'),
              line: _nested,
              mediaId: 'test',
              secondaryText: null,
              isActive: true,
              inEcho: false,
              selectable: false,
              onTap: () {},
            ),
            TranscriptLineTile(
              key: const ValueKey('line-only'),
              line: _lineOnly,
              mediaId: 'test',
              secondaryText: null,
              isActive: true,
              inEcho: false,
              selectable: false,
              onTap: () {},
            ),
          ],
        ),
      ),
    );

    expect(
      _tileHasKaraokeHighlight(tester, find.byKey(const ValueKey('timed'))),
      isTrue,
    );
    expect(
      _tileHasKaraokeHighlight(tester, find.byKey(const ValueKey('line-only'))),
      isFalse,
    );
    expect(find.text('Hello world'), findsNWidgets(2));
    expect(tester.takeException(), isNull);
  });
}
