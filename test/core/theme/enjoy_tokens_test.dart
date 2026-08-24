import 'package:enjoy_player/core/theme/colors.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EnjoyThemeTokens.build', () {
    test('produces expected defaults from a dark ColorScheme', () {
      const scheme = ColorScheme.dark();
      final tokens = EnjoyThemeTokens.build(scheme);

      expect(tokens.space4, 4);
      expect(tokens.space8, 8);
      expect(tokens.space12, 12);
      expect(tokens.space16, 16);
      expect(tokens.space20, 20);
      expect(tokens.space24, 24);
      expect(tokens.space32, 32);
      expect(tokens.space40, 40);
      expect(tokens.space48, 48);

      expect(tokens.radiusSm, 8);
      expect(tokens.radiusMd, 12);
      expect(tokens.radiusLg, 16);
      expect(tokens.radiusXl, 20);
      expect(tokens.radiusFull, 999);

      expect(tokens.elevationNone, 0);
      expect(tokens.elevationCard, 1);
      expect(tokens.elevationSheet, 3);
      expect(tokens.elevationModal, 8);
      expect(tokens.elevationBar, 2);
      expect(tokens.elevationSurface, 1);

      expect(tokens.breakpointCompact, 600);
      expect(tokens.breakpointRail, 900);
      expect(tokens.breakpointTranscriptSideBySide, 720);

      expect(tokens.motionFast, const Duration(milliseconds: 180));
      expect(tokens.motionStandard, const Duration(milliseconds: 260));
      expect(tokens.motionEnter, const Duration(milliseconds: 240));
      expect(tokens.motionExit, const Duration(milliseconds: 160));
      expect(tokens.motionMedium, const Duration(milliseconds: 220));

      expect(tokens.echoActive, AppColors.echoActive);
      expect(tokens.blurActive, AppColors.blurActive);
      expect(tokens.scoreGood, AppColors.scoreGood);
      expect(tokens.scoreWarn, AppColors.scoreWarn);
      expect(tokens.scoreBad, AppColors.scoreBad);
      expect(tokens.scoreGoodContainer, AppColors.scoreGoodContainer);
      expect(tokens.scoreWarnContainer, AppColors.scoreWarnContainer);
      expect(tokens.scoreBadContainer, AppColors.scoreBadContainer);
      expect(tokens.accentSoft, AppColors.accentSoft);
      expect(tokens.accentInk, AppColors.brandOnDark);
      expect(tokens.intelligenceInk, AppColors.intelligenceInkDark);
      expect(tokens.echoInk, AppColors.echoInkDark);
      expect(tokens.ccBadge, scheme.primary);
      expect(tokens.contentMaxWidth, 720);
      expect(tokens.formMaxWidth, 680);
      expect(tokens.hubMaxWidth, 840);
      expect(tokens.pageGutterCompact, 16);
      expect(tokens.pageGutter, 24);
      expect(tokens.miniBarBlurSigma, 20);
      expect(tokens.sidebarWidth, 248);
      expect(tokens.sidebarBrandHeight, 56);
      expect(tokens.transportHeight, 88);
      expect(tokens.heroTitleLetterSpacing, -1.2);
      expect(tokens.useGlassOnSidebar, isFalse);
      expect(tokens.bottomNavHeight, 68);
      expect(tokens.desktopGutter, 24);
      expect(tokens.modalMaxWidth, 400);
      expect(tokens.modalMaxWidthLarge, 560);
      expect(tokens.focusRingWidth, 2);

      expect(
        tokens.transcriptLinePadding,
        const EdgeInsets.symmetric(horizontal: 16),
      );
    });

    test('glassTint and glassBorder derive from scheme', () {
      const scheme = ColorScheme.dark();
      final tokens = EnjoyThemeTokens.build(scheme);

      expect(tokens.glassTint, scheme.surface.withValues(alpha: 0.55));
      expect(tokens.glassBorder, scheme.outlineVariant.withValues(alpha: 0.22));
    });

    test('light palette uses paper inks and denser glass', () {
      const scheme = ColorScheme.light();
      final tokens = EnjoyThemeTokens.build(scheme);

      expect(tokens.accentInk, AppColors.brandOnLight);
      expect(tokens.intelligenceInk, AppColors.intelligenceInkLight);
      expect(tokens.echoInk, AppColors.echoInkLight);
      expect(tokens.scoreGood, AppColors.scoreGoodLight);
      expect(tokens.glassTint, scheme.surface.withValues(alpha: 0.82));
      expect(tokens.glassBorder, scheme.outlineVariant.withValues(alpha: 0.55));
      expect(tokens.radiusSm, 8);
      expect(tokens.space48, 48);
    });
  });

  group('EnjoyThemeTokens.of', () {
    testWidgets('returns extension when registered in theme', (tester) async {
      const scheme = ColorScheme.dark();
      final tokens = EnjoyThemeTokens.build(scheme);
      late EnjoyThemeTokens resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme, extensions: [tokens]),
          home: Builder(
            builder: (context) {
              resolved = EnjoyThemeTokens.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      expect(resolved.space4, tokens.space4);
      expect(resolved.radiusMd, tokens.radiusMd);
    });

    testWidgets('falls back to build when no extension registered', (
      tester,
    ) async {
      const scheme = ColorScheme.dark();
      late EnjoyThemeTokens resolved;

      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(colorScheme: scheme),
          home: Builder(
            builder: (context) {
              resolved = EnjoyThemeTokens.of(context);
              return const SizedBox();
            },
          ),
        ),
      );

      // Should still produce valid tokens via the fallback build path.
      expect(resolved.space4, 4);
      expect(resolved.ccBadge, scheme.primary);
    });
  });

  group('EnjoyThemeTokens.copyWith', () {
    test('returns identical values when no overrides given', () {
      final tokens = EnjoyThemeTokens.build(const ColorScheme.dark());
      final copy = tokens.copyWith();

      expect(copy.space4, tokens.space4);
      expect(copy.radiusSm, tokens.radiusSm);
      expect(copy.motionFast, tokens.motionFast);
      expect(copy.echoActive, tokens.echoActive);
      expect(copy.useGlassOnSidebar, tokens.useGlassOnSidebar);
      expect(copy.focusRingWidth, tokens.focusRingWidth);
    });

    test('overrides selected fields and preserves the rest', () {
      final tokens = EnjoyThemeTokens.build(const ColorScheme.dark());
      final copy = tokens.copyWith(
        space4: 100,
        radiusSm: 42,
        motionFast: const Duration(milliseconds: 999),
        echoActive: const Color(0xFF112233),
        useGlassOnSidebar: true,
        bottomNavHeight: 200,
        desktopGutter: 99,
        modalMaxWidth: 500,
        modalMaxWidthLarge: 700,
        focusRingWidth: 5,
        contentMaxWidth: 800,
        formMaxWidth: 750,
        hubMaxWidth: 900,
        pageGutterCompact: 32,
        pageGutter: 48,
        miniBarBlurSigma: 40,
        sidebarWidth: 300,
        sidebarBrandHeight: 80,
        transportHeight: 120,
        heroTitleLetterSpacing: -2.0,
        glassTint: const Color(0xAA000000),
        glassBorder: const Color(0xBB111111),
        gradientStart: const Color(0xFF222222),
        gradientEnd: const Color(0xFF333333),
        blurActive: const Color(0xFF445566),
        scoreGood: const Color(0xFF119955),
        scoreWarn: const Color(0xFF996611),
        scoreBad: const Color(0xFF991122),
        scoreGoodContainer: const Color(0x33119955),
        scoreWarnContainer: const Color(0x33996611),
        scoreBadContainer: const Color(0x33991122),
        accentSoft: const Color(0x337B61FF),
        ccBadge: const Color(0xFF778899),
        transcriptLinePadding: const EdgeInsets.all(20),
        space8: 18,
        space12: 22,
        space16: 26,
        space20: 30,
        space24: 34,
        space32: 42,
        space40: 50,
        radiusMd: 14,
        radiusLg: 18,
        radiusXl: 22,
        radiusFull: 1000,
        elevationNone: 1,
        elevationCard: 2,
        elevationSheet: 4,
        elevationModal: 10,
        elevationBar: 3,
        elevationSurface: 2,
        breakpointCompact: 700,
        breakpointRail: 1000,
        breakpointTranscriptSideBySide: 800,
        motionStandard: const Duration(milliseconds: 300),
        motionEnter: const Duration(milliseconds: 280),
        motionExit: const Duration(milliseconds: 200),
        motionMedium: const Duration(milliseconds: 250),
      );

      expect(copy.space4, 100);
      expect(copy.radiusSm, 42);
      expect(copy.motionFast, const Duration(milliseconds: 999));
      expect(copy.echoActive, const Color(0xFF112233));
      expect(copy.useGlassOnSidebar, isTrue);
      expect(copy.bottomNavHeight, 200);
      expect(copy.desktopGutter, 99);
      expect(copy.modalMaxWidth, 500);
      expect(copy.modalMaxWidthLarge, 700);
      expect(copy.focusRingWidth, 5);
      expect(copy.contentMaxWidth, 800);
      expect(copy.formMaxWidth, 750);
      expect(copy.hubMaxWidth, 900);
      expect(copy.pageGutterCompact, 32);
      expect(copy.pageGutter, 48);
      expect(copy.miniBarBlurSigma, 40);
      expect(copy.sidebarWidth, 300);
      expect(copy.sidebarBrandHeight, 80);
      expect(copy.transportHeight, 120);
      expect(copy.heroTitleLetterSpacing, -2.0);
      expect(copy.glassTint, const Color(0xAA000000));
      expect(copy.glassBorder, const Color(0xBB111111));
      expect(copy.gradientStart, const Color(0xFF222222));
      expect(copy.gradientEnd, const Color(0xFF333333));
      expect(copy.blurActive, const Color(0xFF445566));
      expect(copy.scoreGood, const Color(0xFF119955));
      expect(copy.scoreWarn, const Color(0xFF996611));
      expect(copy.scoreBad, const Color(0xFF991122));
      expect(copy.scoreGoodContainer, const Color(0x33119955));
      expect(copy.scoreWarnContainer, const Color(0x33996611));
      expect(copy.scoreBadContainer, const Color(0x33991122));
      expect(copy.accentSoft, const Color(0x337B61FF));
      expect(copy.ccBadge, const Color(0xFF778899));
      expect(copy.transcriptLinePadding, const EdgeInsets.all(20));
      expect(copy.space8, 18);
      expect(copy.space12, 22);
      expect(copy.space16, 26);
      expect(copy.space20, 30);
      expect(copy.space24, 34);
      expect(copy.space32, 42);
      expect(copy.space40, 50);
      expect(copy.radiusMd, 14);
      expect(copy.radiusLg, 18);
      expect(copy.radiusXl, 22);
      expect(copy.radiusFull, 1000);
      expect(copy.elevationNone, 1);
      expect(copy.elevationCard, 2);
      expect(copy.elevationSheet, 4);
      expect(copy.elevationModal, 10);
      expect(copy.elevationBar, 3);
      expect(copy.elevationSurface, 2);
      expect(copy.breakpointCompact, 700);
      expect(copy.breakpointRail, 1000);
      expect(copy.breakpointTranscriptSideBySide, 800);
      expect(copy.motionStandard, const Duration(milliseconds: 300));
      expect(copy.motionEnter, const Duration(milliseconds: 280));
      expect(copy.motionExit, const Duration(milliseconds: 200));
      expect(copy.motionMedium, const Duration(milliseconds: 250));
    });
  });

  group('EnjoyThemeTokens.lerp', () {
    late EnjoyThemeTokens a;
    late EnjoyThemeTokens b;

    setUp(() {
      a = EnjoyThemeTokens.build(const ColorScheme.dark());
      b = a.copyWith(
        space4: 8,
        space8: 16,
        space12: 24,
        space16: 32,
        space20: 40,
        space24: 48,
        space32: 64,
        space40: 80,
        radiusSm: 16,
        radiusMd: 24,
        radiusLg: 32,
        radiusXl: 40,
        radiusFull: 1998,
        elevationNone: 0,
        elevationCard: 3,
        elevationSheet: 7,
        elevationModal: 16,
        elevationBar: 4,
        elevationSurface: 3,
        breakpointCompact: 1200,
        breakpointRail: 1800,
        breakpointTranscriptSideBySide: 1440,
        motionFast: const Duration(milliseconds: 360),
        motionStandard: const Duration(milliseconds: 520),
        motionEnter: const Duration(milliseconds: 480),
        motionExit: const Duration(milliseconds: 320),
        motionMedium: const Duration(milliseconds: 440),
        echoActive: const Color(0xFF0000FF),
        blurActive: const Color(0xFF00FF00),
        scoreGood: const Color(0xFF00EE88),
        scoreWarn: const Color(0xFFEEAA00),
        scoreBad: const Color(0xFFEE2233),
        scoreGoodContainer: const Color(0x4000EE88),
        scoreWarnContainer: const Color(0x40EEAA00),
        scoreBadContainer: const Color(0x40EE2233),
        accentSoft: const Color(0x407B61FF),
        ccBadge: const Color(0xFFFF0000),
        transcriptLinePadding: const EdgeInsets.symmetric(
          horizontal: 32,
          vertical: 20,
        ),
        contentMaxWidth: 1440,
        formMaxWidth: 1360,
        hubMaxWidth: 1680,
        pageGutterCompact: 32,
        pageGutter: 48,
        miniBarBlurSigma: 40,
        sidebarWidth: 496,
        sidebarBrandHeight: 112,
        transportHeight: 176,
        heroTitleLetterSpacing: -2.4,
        glassTint: const Color(0xFF000000),
        glassBorder: const Color(0xFFFFFFFF),
        gradientStart: const Color(0xFF303030),
        gradientEnd: const Color(0xFF121212),
        useGlassOnSidebar: true,
        bottomNavHeight: 136,
        desktopGutter: 48,
        modalMaxWidth: 800,
        modalMaxWidthLarge: 1120,
        focusRingWidth: 4,
      );
    });

    test('t=0 returns this', () {
      final result = a.lerp(b, 0);
      expect(identical(result, a), isTrue);
    });

    test('t=1 returns other', () {
      final result = a.lerp(b, 1);
      expect(identical(result, b), isTrue);
    });

    test('returns this when other is not EnjoyThemeTokens', () {
      final result = a.lerp(null, 0.5);
      expect(identical(result, a), isTrue);
    });

    test('t=0.5 produces correct midpoint for doubles', () {
      final result = a.lerp(b, 0.5) as EnjoyThemeTokens;

      expect(result.space4, 6); // lerp(4, 8, 0.5)
      expect(result.space8, 12); // lerp(8, 16, 0.5)
      expect(result.space12, 18); // lerp(12, 24, 0.5)
      expect(result.space16, 24); // lerp(16, 32, 0.5)
      expect(result.space20, 30); // lerp(20, 40, 0.5)
      expect(result.space24, 36); // lerp(24, 48, 0.5)
      expect(result.space32, 48); // lerp(32, 64, 0.5)
      expect(result.space40, 60); // lerp(40, 80, 0.5)

      expect(result.radiusSm, 12); // lerp(8, 16, 0.5)
      expect(result.radiusMd, 18); // lerp(12, 24, 0.5)
      expect(result.radiusLg, 24); // lerp(16, 32, 0.5)
      expect(result.radiusXl, 30); // lerp(20, 40, 0.5)
      expect(result.radiusFull, 1498.5); // lerp(999, 1998, 0.5)

      expect(result.elevationNone, 0); // lerp(0, 0, 0.5)
      expect(result.elevationCard, 2); // lerp(1, 3, 0.5)
      expect(result.elevationSheet, 5); // lerp(3, 7, 0.5)
      expect(result.elevationModal, 12); // lerp(8, 16, 0.5)
      expect(result.elevationBar, 3); // lerp(2, 4, 0.5)
      expect(result.elevationSurface, 2); // lerp(1, 3, 0.5)

      expect(result.breakpointCompact, 900); // lerp(600, 1200, 0.5)
      expect(result.breakpointRail, 1350); // lerp(900, 1800, 0.5)
      expect(
        result.breakpointTranscriptSideBySide,
        1080,
      ); // lerp(720, 1440, 0.5)

      expect(result.contentMaxWidth, 1080); // lerp(720, 1440, 0.5)
      expect(result.formMaxWidth, 1020); // lerp(680, 1360, 0.5)
      expect(result.hubMaxWidth, 1260); // lerp(840, 1680, 0.5)
      expect(result.pageGutterCompact, 24); // lerp(16, 32, 0.5)
      expect(result.pageGutter, 36); // lerp(24, 48, 0.5)
      expect(result.miniBarBlurSigma, 30); // lerp(20, 40, 0.5)
      expect(result.sidebarWidth, 372); // lerp(248, 496, 0.5)
      expect(result.sidebarBrandHeight, 84); // lerp(56, 112, 0.5)
      expect(result.transportHeight, 132); // lerp(88, 176, 0.5)
      expect(
        result.heroTitleLetterSpacing,
        closeTo(-1.8, 1e-10),
      ); // lerp(-1.2, -2.4, 0.5)
      expect(result.bottomNavHeight, 102); // lerp(68, 136, 0.5)
      expect(result.desktopGutter, 36); // lerp(24, 48, 0.5)
      expect(result.modalMaxWidth, 600); // lerp(400, 800, 0.5)
      expect(result.modalMaxWidthLarge, 840); // lerp(560, 1120, 0.5)
      expect(result.focusRingWidth, 3); // lerp(2, 4, 0.5)
    });

    test('t=0.5 produces correct midpoint for durations', () {
      final result = a.lerp(b, 0.5) as EnjoyThemeTokens;

      // lerp(180, 360, 0.5) = 270
      expect(result.motionFast, const Duration(milliseconds: 270));
      // lerp(260, 520, 0.5) = 390
      expect(result.motionStandard, const Duration(milliseconds: 390));
      // lerp(240, 480, 0.5) = 360
      expect(result.motionEnter, const Duration(milliseconds: 360));
      // lerp(160, 320, 0.5) = 240
      expect(result.motionExit, const Duration(milliseconds: 240));
      // lerp(220, 440, 0.5) = 330
      expect(result.motionMedium, const Duration(milliseconds: 330));
    });

    test('t=0.5 lerps colors', () {
      final result = a.lerp(b, 0.5) as EnjoyThemeTokens;

      expect(result.echoActive, Color.lerp(a.echoActive, b.echoActive, 0.5));
      expect(result.blurActive, Color.lerp(a.blurActive, b.blurActive, 0.5));
      expect(result.scoreGood, Color.lerp(a.scoreGood, b.scoreGood, 0.5));
      expect(result.scoreWarn, Color.lerp(a.scoreWarn, b.scoreWarn, 0.5));
      expect(result.scoreBad, Color.lerp(a.scoreBad, b.scoreBad, 0.5));
      expect(
        result.scoreGoodContainer,
        Color.lerp(a.scoreGoodContainer, b.scoreGoodContainer, 0.5),
      );
      expect(
        result.scoreWarnContainer,
        Color.lerp(a.scoreWarnContainer, b.scoreWarnContainer, 0.5),
      );
      expect(
        result.scoreBadContainer,
        Color.lerp(a.scoreBadContainer, b.scoreBadContainer, 0.5),
      );
      expect(result.accentSoft, Color.lerp(a.accentSoft, b.accentSoft, 0.5));
      expect(result.ccBadge, Color.lerp(a.ccBadge, b.ccBadge, 0.5));
      expect(result.glassTint, Color.lerp(a.glassTint, b.glassTint, 0.5));
      expect(result.glassBorder, Color.lerp(a.glassBorder, b.glassBorder, 0.5));
      expect(
        result.gradientStart,
        Color.lerp(a.gradientStart, b.gradientStart, 0.5),
      );
      expect(result.gradientEnd, Color.lerp(a.gradientEnd, b.gradientEnd, 0.5));
    });

    test('t=0.5 lerps EdgeInsets', () {
      final result = a.lerp(b, 0.5) as EnjoyThemeTokens;

      expect(
        result.transcriptLinePadding,
        EdgeInsets.lerp(a.transcriptLinePadding, b.transcriptLinePadding, 0.5),
      );
    });

    test('useGlassOnSidebar uses threshold at t<0.5 vs t>=0.5', () {
      final below = a.lerp(b, 0.49) as EnjoyThemeTokens;
      expect(below.useGlassOnSidebar, a.useGlassOnSidebar); // false

      final atHalf = a.lerp(b, 0.5) as EnjoyThemeTokens;
      expect(atHalf.useGlassOnSidebar, b.useGlassOnSidebar); // true

      final above = a.lerp(b, 0.75) as EnjoyThemeTokens;
      expect(above.useGlassOnSidebar, b.useGlassOnSidebar); // true
    });

    test('t=0.25 produces correct quarter-point values', () {
      final result = a.lerp(b, 0.25) as EnjoyThemeTokens;

      expect(result.space4, 5); // lerp(4, 8, 0.25) = 5
      expect(result.space40, 50); // lerp(40, 80, 0.25) = 50
      expect(result.radiusSm, 10); // lerp(8, 16, 0.25) = 10
      expect(result.focusRingWidth, 2.5); // lerp(2, 4, 0.25) = 2.5
    });
  });
}
