import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/transcript/transcript_density.dart';
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

Widget transcriptTileHarness({required Widget child}) {
  return ProviderScope(
    overrides: [
      transcriptBlurModeProvider.overrideWith(() => _BlurMode(false)),
      ...transcriptWordPracticeOffOverrides(),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: SingleChildScrollView(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 400),
            child: child,
          ),
        ),
      ),
    ),
  );
}

TranscriptLineTile _buildTile() => TranscriptLineTile(
  line: const TranscriptLine(text: 'Hello world', startMs: 0, durationMs: 2000),
  mediaId: 'test',
  secondaryText: '你好世界',
  isActive: false,
  inEcho: false,
  groupedInEcho: false,
  selectable: false,
  onTap: () {},
);

Future<double> _measureTileHeight(
  WidgetTester tester,
  TargetPlatform platform,
) async {
  debugDefaultTargetPlatformOverride = platform;
  try {
    await tester.pumpWidget(transcriptTileHarness(child: _buildTile()));
  } finally {
    debugDefaultTargetPlatformOverride = null;
  }
  return tester.getSize(find.byType(TranscriptLineTile)).height;
}

void main() {
  testWidgets('mobile platform tile is shorter than desktop tile', (
    tester,
  ) async {
    final mobile = await _measureTileHeight(tester, TargetPlatform.android);
    final desktop = await _measureTileHeight(tester, TargetPlatform.macOS);
    expect(mobile, lessThan(desktop));
  });

  testWidgets('iOS platform tile matches android compact', (tester) async {
    final ios = await _measureTileHeight(tester, TargetPlatform.iOS);
    final android = await _measureTileHeight(tester, TargetPlatform.android);
    expect(ios, equals(android));
  });

  testWidgets('line horizontal padding is 16 not summed EdgeInsets.horizontal', (
    tester,
  ) async {
    await tester.pumpWidget(transcriptTileHarness(child: _buildTile()));

    final paddings = tester.widgetList<Padding>(
      find.descendant(
        of: find.byType(TranscriptLineTile),
        matching: find.byType(Padding),
      ),
    );
    final linePads = paddings.where((p) {
      final r = p.padding.resolve(TextDirection.ltr);
      return r.left == 16 && r.right == 16;
    });
    expect(
      linePads,
      isNotEmpty,
      reason: 'TranscriptLineTile must apply 16px side padding (not 32)',
    );
    // Guard against the old bug: EdgeInsets.horizontal (== 32) used as each side.
    final doubled = paddings.where((p) {
      final r = p.padding.resolve(TextDirection.ltr);
      return r.left == 32 && r.right == 32;
    });
    expect(doubled, isEmpty);
  });

  testWidgets('TranscriptDensity values differ between mobile and desktop', (
    tester,
  ) async {
    late TranscriptDensity mobile;
    late TranscriptDensity desktop;

    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      await tester.pumpWidget(
        transcriptTileHarness(
          child: Builder(
            builder: (context) {
              mobile = TranscriptDensity.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
    try {
      await tester.pumpWidget(
        transcriptTileHarness(
          child: Builder(
            builder: (context) {
              desktop = TranscriptDensity.of(context);
              return const SizedBox.shrink();
            },
          ),
        ),
      );
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    expect(mobile, isNot(equals(desktop)));
    expect(mobile.lineVerticalPadding, lessThan(desktop.lineVerticalPadding));
    expect(mobile.bodyHeight, lessThan(desktop.bodyHeight));
    expect(mobile.lineInterGap, lessThan(desktop.lineInterGap));
  });
}
