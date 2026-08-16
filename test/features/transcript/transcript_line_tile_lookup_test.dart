import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_line_tile.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget transcriptTileHarness(Widget child) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
      karaokeHighlightSettingsProvider.overrideWith(_KaraokeHighlightOff.new),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

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
  testWidgets('selectable transcript line uses SelectableText', (tester) async {
    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: true,
          inEcho: false,
          groupedInEcho: false,
          selectable: true,
          onLookupRequested: (_) {},
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(SelectableText), findsOneWidget);
  });

  testWidgets('non-selectable transcript line uses plain Text.rich', (
    tester,
  ) async {
    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          groupedInEcho: false,
          selectable: false,
          onTap: () {},
        ),
      ),
    );

    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);
  });

  testWidgets('grouped echo line remains tappable when not selectable', (
    tester,
  ) async {
    var tapped = false;

    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: true,
          groupedInEcho: true,
          selectable: false,
          onTap: () => tapped = true,
        ),
      ),
    );

    expect(find.byType(SelectableText), findsNothing);
    expect(find.byType(InkWell), findsOneWidget);

    await tester.tap(find.text('Hello world'));

    expect(tapped, isTrue);
  });

  testWidgets('lookup runs from selection toolbar after explicit tap', (
    tester,
  ) async {
    String? lookedUp;
    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: true,
          inEcho: false,
          groupedInEcho: false,
          selectable: true,
          onLookupRequested: (t) => lookedUp = t,
          onTap: () {},
        ),
      ),
    );

    final textCenter = tester.getCenter(find.text('Hello world'));
    await tester.tapAt(textCenter);
    await tester.pump(const Duration(milliseconds: 50));
    await tester.tapAt(textCenter);
    await tester.pump(const Duration(milliseconds: 250));

    expect(lookedUp, isNull);

    final lookUp = find.text('Look up');
    expect(lookUp, findsOneWidget);
    await tester.tap(lookUp);
    await tester.pumpAndSettle();

    expect(lookedUp, equals('Hello'));
  });

  testWidgets('selection toolbar debounces during drag selection', (
    tester,
  ) async {
    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: true,
          inEcho: false,
          groupedInEcho: false,
          selectable: true,
          onLookupRequested: (_) {},
          onTap: () {},
        ),
      ),
    );

    final textFinder = find.text('Hello world');
    final from = tester.getTopLeft(textFinder) + const Offset(4, 8);
    final gesture = await tester.startGesture(from);
    await tester.pump(const Duration(milliseconds: 600));
    await gesture.moveBy(const Offset(60, 0));
    await tester.pump(const Duration(milliseconds: 50));
    await gesture.moveBy(const Offset(40, 0));
    await tester.pump(const Duration(milliseconds: 50));

    expect(find.text('Look up'), findsNothing);

    await gesture.up();
    await tester.pump(const Duration(milliseconds: 250));
    await tester.pump();

    expect(find.text('Look up'), findsOneWidget);
  });

  testWidgets('shows recording badge when recordingCount is positive', (
    tester,
  ) async {
    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          groupedInEcho: false,
          selectable: false,
          recordingCount: 2,
          onTap: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_rounded), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
  });

  testWidgets('hides recording badge when recordingCount is zero', (
    tester,
  ) async {
    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          groupedInEcho: false,
          selectable: false,
          recordingCount: 0,
          onTap: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });

  testWidgets('hides recording badge while recordingCount is loading', (
    tester,
  ) async {
    await tester.pumpWidget(
      transcriptTileHarness(
        TranscriptLineTile(
          line: const TranscriptLine(
            text: 'Hello world',
            startMs: 0,
            durationMs: 2000,
          ),
          mediaId: 'test',
          secondaryText: null,
          isActive: false,
          inEcho: false,
          groupedInEcho: false,
          selectable: false,
          onTap: () {},
        ),
      ),
    );

    expect(find.byIcon(Icons.mic_rounded), findsNothing);
  });
}
