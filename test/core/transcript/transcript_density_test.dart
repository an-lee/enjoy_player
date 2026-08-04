import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/transcript/transcript_density.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TranscriptDensity', () {
    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF1144AA));
    final tok = EnjoyThemeTokens.build(scheme);

    Widget host(Widget child) {
      return MaterialApp(
        theme: ThemeData(colorScheme: scheme, extensions: [tok]),
        home: child,
      );
    }

    Future<TranscriptDensity> readDensityFor(
      WidgetTester tester,
      TargetPlatform platform,
    ) async {
      debugDefaultTargetPlatformOverride = platform;
      late TranscriptDensity density;
      try {
        await tester.pumpWidget(
          host(
            Builder(
              builder: (context) {
                density = TranscriptDensity.of(context);
                return const SizedBox.shrink();
              },
            ),
          ),
        );
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
      return density;
    }

    testWidgets('mobile platform returns compact values', (tester) async {
      final density = await readDensityFor(tester, TargetPlatform.android);
      expect(density.lineVerticalPadding, 4);
      expect(density.lineInterGap, 2);
      expect(density.headerBodyGap, 2);
      expect(density.primarySecondaryGap, 2);
      expect(density.secondaryLeftPadding, 8);
      expect(density.bodyHeight, 1.35);
      expect(density.secondaryHeight, 1.3);
      expect(density.listHorizontalPadding, 8);
      expect(density.listVerticalPadding, 4);
      expect(density.echoControlsPadding, 2);
      expect(density.echoCardGap, 4);
      expect(density.echoBottomPanelGap, 4);
      expect(density.echoDividerThickness, 0.5);
      expect(density.echoControlIconSize, 16);
    });

    testWidgets('iOS platform returns compact values', (tester) async {
      final density = await readDensityFor(tester, TargetPlatform.iOS);
      expect(density.lineVerticalPadding, 4);
      expect(density.bodyHeight, 1.35);
    });

    testWidgets('desktop platform returns full values', (tester) async {
      final density = await readDensityFor(tester, TargetPlatform.macOS);
      expect(density.lineVerticalPadding, 6);
      expect(density.lineInterGap, 4);
      expect(density.headerBodyGap, 2);
      expect(density.primarySecondaryGap, 4);
      expect(density.secondaryLeftPadding, 12);
      expect(density.bodyHeight, 1.45);
      expect(density.secondaryHeight, 1.4);
      expect(density.listHorizontalPadding, 12);
      expect(density.listVerticalPadding, 8);
      expect(density.echoControlsPadding, 4);
      expect(density.echoCardGap, 8);
      expect(density.echoBottomPanelGap, 8);
      expect(density.echoDividerThickness, 1.0);
      expect(density.echoControlIconSize, 20);
    });

    test('equality is value-based', () {
      const a = TranscriptDensity(
        listHorizontalPadding: 8,
        listVerticalPadding: 4,
        lineVerticalPadding: 4,
        lineInterGap: 2,
        headerBodyGap: 2,
        primarySecondaryGap: 2,
        secondaryLeftPadding: 8,
        bodyHeight: 1.35,
        secondaryHeight: 1.3,
        echoControlsPadding: 2,
        echoCardGap: 4,
        echoBottomPanelGap: 4,
        echoDividerThickness: 0.5,
        echoControlIconSize: 16,
      );
      const b = TranscriptDensity(
        listHorizontalPadding: 8,
        listVerticalPadding: 4,
        lineVerticalPadding: 4,
        lineInterGap: 2,
        headerBodyGap: 2,
        primarySecondaryGap: 2,
        secondaryLeftPadding: 8,
        bodyHeight: 1.35,
        secondaryHeight: 1.3,
        echoControlsPadding: 2,
        echoCardGap: 4,
        echoBottomPanelGap: 4,
        echoDividerThickness: 0.5,
        echoControlIconSize: 16,
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
