/// Design tokens: spacing, radii, motion, elevation, breakpoints (ThemeExtension).
library;

import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import 'colors.dart';

/// Premium cinematic-editorial tokens; use [EnjoyThemeTokens.of] from widgets.
@immutable
class EnjoyThemeTokens extends ThemeExtension<EnjoyThemeTokens> {
  /// Dark-only app tokens derived from the active [ColorScheme].
  factory EnjoyThemeTokens.build(ColorScheme scheme) {
    return EnjoyThemeTokens(
      space4: 4,
      space8: 8,
      space12: 12,
      space16: 16,
      space20: 20,
      space24: 24,
      space32: 32,
      space40: 40,
      radiusSm: 10,
      radiusMd: 14,
      radiusLg: 18,
      radiusXl: 24,
      radiusFull: 999,
      elevationNone: 0,
      elevationCard: 1,
      elevationSheet: 3,
      elevationModal: 8,
      elevationBar: 2,
      elevationSurface: 1,
      breakpointCompact: 600,
      breakpointRail: 900,
      breakpointTranscriptSideBySide: 720,
      motionFast: const Duration(milliseconds: 180),
      motionStandard: const Duration(milliseconds: 260),
      motionEnter: const Duration(milliseconds: 240),
      motionExit: const Duration(milliseconds: 160),
      motionMedium: const Duration(milliseconds: 220),
      echoActive: AppColors.echoActive,
      blurActive: AppColors.blurActive,
      scoreGood: AppColors.scoreGood,
      scoreWarn: AppColors.scoreWarn,
      scoreBad: AppColors.scoreBad,
      scoreGoodContainer: AppColors.scoreGoodContainer,
      scoreWarnContainer: AppColors.scoreWarnContainer,
      scoreBadContainer: AppColors.scoreBadContainer,
      accentSoft: AppColors.accentSoft,
      ccBadge: scheme.primary,
      // Vertical padding is applied per-line via [TranscriptDensity.lineVerticalPadding].
      transcriptLinePadding: const EdgeInsets.symmetric(horizontal: 16),
      contentMaxWidth: 720,
      formMaxWidth: 680,
      hubMaxWidth: 840,
      pageGutterCompact: 16,
      pageGutter: 24,
      miniBarBlurSigma: 20,
      sidebarWidth: 248,
      sidebarBrandHeight: 56,
      transportHeight: 88,
      heroTitleLetterSpacing: -1.2,
      glassTint: scheme.surface.withValues(alpha: 0.55),
      glassBorder: scheme.outlineVariant.withValues(alpha: 0.22),
      gradientStart: AppColors.gradientStartDark,
      gradientEnd: AppColors.gradientEndDark,
      useGlassOnSidebar: false,
      bottomNavHeight: 68,
      desktopGutter: 24,
      modalMaxWidth: 400,
      modalMaxWidthLarge: 560,
      focusRingWidth: 2,
    );
  }
  const EnjoyThemeTokens({
    required this.space4,
    required this.space8,
    required this.space12,
    required this.space16,
    required this.space20,
    required this.space24,
    required this.space32,
    required this.space40,
    required this.radiusSm,
    required this.radiusMd,
    required this.radiusLg,
    required this.radiusXl,
    required this.radiusFull,
    required this.elevationNone,
    required this.elevationCard,
    required this.elevationSheet,
    required this.elevationModal,
    // ── Keep aliases for legacy call-sites ──────────────────────────
    required this.elevationBar,
    required this.elevationSurface,
    // ── Breakpoints ────────────────────────────────────────────────
    required this.breakpointCompact,
    required this.breakpointRail,
    required this.breakpointTranscriptSideBySide,
    // ── Motion ─────────────────────────────────────────────────────
    required this.motionFast,
    required this.motionStandard,
    required this.motionEnter,
    required this.motionExit,

    /// Transport / layout morphs: 220ms (between [motionFast] and [motionStandard]).
    required this.motionMedium,
    // ── Feature colors ─────────────────────────────────────────────
    required this.echoActive,
    required this.blurActive,
    required this.scoreGood,
    required this.scoreWarn,
    required this.scoreBad,
    required this.scoreGoodContainer,
    required this.scoreWarnContainer,
    required this.scoreBadContainer,
    required this.accentSoft,
    required this.ccBadge,
    // ── Layout ─────────────────────────────────────────────────────
    required this.transcriptLinePadding,
    required this.contentMaxWidth,
    required this.formMaxWidth,
    required this.hubMaxWidth,
    required this.pageGutterCompact,
    required this.pageGutter,
    required this.miniBarBlurSigma,
    required this.sidebarWidth,
    required this.sidebarBrandHeight,
    required this.transportHeight,
    required this.heroTitleLetterSpacing,
    // ── Glass & gradient ───────────────────────────────────────────
    required this.glassTint,
    required this.glassBorder,
    required this.gradientStart,
    required this.gradientEnd,
    // ── Glass scope flag ───────────────────────────────────────────
    required this.useGlassOnSidebar,
    // ── Shell / modal layout ───────────────────────────────────────
    required this.bottomNavHeight,
    required this.desktopGutter,
    required this.modalMaxWidth,
    required this.modalMaxWidthLarge,
    required this.focusRingWidth,
  });

  // ── Spacing (4pt grid) ─────────────────────────────────────────────────
  final double space4;
  final double space8;
  final double space12;
  final double space16;
  final double space20;
  final double space24;
  final double space32;
  final double space40;

  // ── Radii ──────────────────────────────────────────────────────────────
  final double radiusSm;
  final double radiusMd;
  final double radiusLg;
  final double radiusXl;
  final double radiusFull;

  // ── Elevation scale (0 / 1 / 3 / 8) ───────────────────────────────────
  final double elevationNone;
  final double elevationCard;
  final double elevationSheet;
  final double elevationModal;

  /// Legacy aliases kept for widgets that still call elevationBar/elevationSurface.
  final double elevationBar;
  final double elevationSurface;

  // ── Breakpoints ────────────────────────────────────────────────────────
  /// Pane width below which [pageGutterCompact] applies.
  final double breakpointCompact;

  /// Width at which shell switches from bottom nav to extended sidebar.
  final double breakpointRail;

  /// Width at which player shows transcript side-by-side vs stacked.
  final double breakpointTranscriptSideBySide;

  // ── Motion ─────────────────────────────────────────────────────────────
  /// Micro-interactions: 180ms.
  final Duration motionFast;

  /// Standard transitions: 260ms.
  final Duration motionStandard;

  /// Screen enter: 240ms.
  final Duration motionEnter;

  /// Screen exit: 160ms (faster than enter for responsiveness).
  final Duration motionExit;

  /// Transport compact/expanded and similar layout transitions.
  final Duration motionMedium;

  // ── Feature colors ─────────────────────────────────────────────────────
  final Color echoActive;

  /// Accent used for the listening-focus (blur practice) toggle when active.
  final Color blurActive;

  /// Evaluation & assessment good color (emerald green).
  final Color scoreGood;

  /// Evaluation & assessment warn color (amber gold).
  final Color scoreWarn;

  /// Evaluation & assessment bad color (coral red).
  final Color scoreBad;

  /// Evaluation & assessment good container background.
  final Color scoreGoodContainer;

  /// Evaluation & assessment warn container background.
  final Color scoreWarnContainer;

  /// Evaluation & assessment bad container background.
  final Color scoreBadContainer;

  /// Soft translucent brand accent background.
  final Color accentSoft;

  final Color ccBadge;

  // ── Layout ─────────────────────────────────────────────────────────────
  final EdgeInsets transcriptLinePadding;

  /// Reading column / empty-state cap (legacy content column).
  final double contentMaxWidth;

  /// Centered max width for form pages (Preferences, Edit Profile, …).
  final double formMaxWidth;

  /// Centered max width for hub pages (Profile, Settings, Subscription, …).
  final double hubMaxWidth;

  /// Horizontal gutter when pane width is below [breakpointCompact].
  final double pageGutterCompact;

  /// Default horizontal gutter for page content (browse + capped columns).
  final double pageGutter;

  /// Backdrop-filter blur for the transport glass bar.
  final double miniBarBlurSigma;

  final double sidebarWidth;
  final double sidebarBrandHeight;
  final double transportHeight;

  /// Letter-spacing for hero display titles (negative = tight).
  final double heroTitleLetterSpacing;

  // ── Glass & gradient ───────────────────────────────────────────────────
  final Color glassTint;
  final Color glassBorder;
  final Color gradientStart;
  final Color gradientEnd;

  /// When false, sidebar uses flat tonal panel instead of frosted glass.
  /// Transport bar always uses glass regardless of this flag.
  final bool useGlassOnSidebar;

  /// Mobile bottom nav content height (excluding system home-indicator inset).
  final double bottomNavHeight;

  /// Horizontal inset for wide layouts (sidebar + content rhythm).
  final double desktopGutter;

  /// Typical alert / form dialog max width.
  final double modalMaxWidth;

  /// Wide modals (e.g. assessment summary).
  final double modalMaxWidthLarge;

  /// Keyboard focus ring stroke width for custom controls.
  final double focusRingWidth;

  // ── Static accessor ────────────────────────────────────────────────────
  static EnjoyThemeTokens of(BuildContext context) {
    return Theme.of(context).extension<EnjoyThemeTokens>() ??
        EnjoyThemeTokens.build(Theme.of(context).colorScheme);
  }

  // ── copyWith ───────────────────────────────────────────────────────────
  @override
  EnjoyThemeTokens copyWith({
    double? space4,
    double? space8,
    double? space12,
    double? space16,
    double? space20,
    double? space24,
    double? space32,
    double? space40,
    double? radiusSm,
    double? radiusMd,
    double? radiusLg,
    double? radiusXl,
    double? radiusFull,
    double? elevationNone,
    double? elevationCard,
    double? elevationSheet,
    double? elevationModal,
    double? elevationBar,
    double? elevationSurface,
    double? breakpointCompact,
    double? breakpointRail,
    double? breakpointTranscriptSideBySide,
    Duration? motionFast,
    Duration? motionStandard,
    Duration? motionEnter,
    Duration? motionExit,
    Duration? motionMedium,
    Color? echoActive,
    Color? blurActive,
    Color? scoreGood,
    Color? scoreWarn,
    Color? scoreBad,
    Color? scoreGoodContainer,
    Color? scoreWarnContainer,
    Color? scoreBadContainer,
    Color? accentSoft,
    Color? ccBadge,
    EdgeInsets? transcriptLinePadding,
    double? contentMaxWidth,
    double? formMaxWidth,
    double? hubMaxWidth,
    double? pageGutterCompact,
    double? pageGutter,
    double? miniBarBlurSigma,
    double? sidebarWidth,
    double? sidebarBrandHeight,
    double? transportHeight,
    double? heroTitleLetterSpacing,
    Color? glassTint,
    Color? glassBorder,
    Color? gradientStart,
    Color? gradientEnd,
    bool? useGlassOnSidebar,
    double? bottomNavHeight,
    double? desktopGutter,
    double? modalMaxWidth,
    double? modalMaxWidthLarge,
    double? focusRingWidth,
  }) {
    return EnjoyThemeTokens(
      space4: space4 ?? this.space4,
      space8: space8 ?? this.space8,
      space12: space12 ?? this.space12,
      space16: space16 ?? this.space16,
      space20: space20 ?? this.space20,
      space24: space24 ?? this.space24,
      space32: space32 ?? this.space32,
      space40: space40 ?? this.space40,
      radiusSm: radiusSm ?? this.radiusSm,
      radiusMd: radiusMd ?? this.radiusMd,
      radiusLg: radiusLg ?? this.radiusLg,
      radiusXl: radiusXl ?? this.radiusXl,
      radiusFull: radiusFull ?? this.radiusFull,
      elevationNone: elevationNone ?? this.elevationNone,
      elevationCard: elevationCard ?? this.elevationCard,
      elevationSheet: elevationSheet ?? this.elevationSheet,
      elevationModal: elevationModal ?? this.elevationModal,
      elevationBar: elevationBar ?? this.elevationBar,
      elevationSurface: elevationSurface ?? this.elevationSurface,
      breakpointCompact: breakpointCompact ?? this.breakpointCompact,
      breakpointRail: breakpointRail ?? this.breakpointRail,
      breakpointTranscriptSideBySide:
          breakpointTranscriptSideBySide ?? this.breakpointTranscriptSideBySide,
      motionFast: motionFast ?? this.motionFast,
      motionStandard: motionStandard ?? this.motionStandard,
      motionEnter: motionEnter ?? this.motionEnter,
      motionExit: motionExit ?? this.motionExit,
      motionMedium: motionMedium ?? this.motionMedium,
      echoActive: echoActive ?? this.echoActive,
      blurActive: blurActive ?? this.blurActive,
      scoreGood: scoreGood ?? this.scoreGood,
      scoreWarn: scoreWarn ?? this.scoreWarn,
      scoreBad: scoreBad ?? this.scoreBad,
      scoreGoodContainer: scoreGoodContainer ?? this.scoreGoodContainer,
      scoreWarnContainer: scoreWarnContainer ?? this.scoreWarnContainer,
      scoreBadContainer: scoreBadContainer ?? this.scoreBadContainer,
      accentSoft: accentSoft ?? this.accentSoft,
      ccBadge: ccBadge ?? this.ccBadge,
      transcriptLinePadding:
          transcriptLinePadding ?? this.transcriptLinePadding,
      contentMaxWidth: contentMaxWidth ?? this.contentMaxWidth,
      formMaxWidth: formMaxWidth ?? this.formMaxWidth,
      hubMaxWidth: hubMaxWidth ?? this.hubMaxWidth,
      pageGutterCompact: pageGutterCompact ?? this.pageGutterCompact,
      pageGutter: pageGutter ?? this.pageGutter,
      miniBarBlurSigma: miniBarBlurSigma ?? this.miniBarBlurSigma,
      sidebarWidth: sidebarWidth ?? this.sidebarWidth,
      sidebarBrandHeight: sidebarBrandHeight ?? this.sidebarBrandHeight,
      transportHeight: transportHeight ?? this.transportHeight,
      heroTitleLetterSpacing:
          heroTitleLetterSpacing ?? this.heroTitleLetterSpacing,
      glassTint: glassTint ?? this.glassTint,
      glassBorder: glassBorder ?? this.glassBorder,
      gradientStart: gradientStart ?? this.gradientStart,
      gradientEnd: gradientEnd ?? this.gradientEnd,
      useGlassOnSidebar: useGlassOnSidebar ?? this.useGlassOnSidebar,
      bottomNavHeight: bottomNavHeight ?? this.bottomNavHeight,
      desktopGutter: desktopGutter ?? this.desktopGutter,
      modalMaxWidth: modalMaxWidth ?? this.modalMaxWidth,
      modalMaxWidthLarge: modalMaxWidthLarge ?? this.modalMaxWidthLarge,
      focusRingWidth: focusRingWidth ?? this.focusRingWidth,
    );
  }

  // ── lerp ──────────────────────────────────────────────────────────────
  @override
  ThemeExtension<EnjoyThemeTokens> lerp(
    covariant ThemeExtension<EnjoyThemeTokens>? other,
    double t,
  ) {
    if (other is! EnjoyThemeTokens) return this;
    if (t == 0) return this;
    if (t == 1) return other;

    double ms(Duration a, Duration b) => lerpDouble(
      a.inMilliseconds.toDouble(),
      b.inMilliseconds.toDouble(),
      t,
    )!.roundToDouble();

    return EnjoyThemeTokens(
      space4: lerpDouble(space4, other.space4, t)!,
      space8: lerpDouble(space8, other.space8, t)!,
      space12: lerpDouble(space12, other.space12, t)!,
      space16: lerpDouble(space16, other.space16, t)!,
      space20: lerpDouble(space20, other.space20, t)!,
      space24: lerpDouble(space24, other.space24, t)!,
      space32: lerpDouble(space32, other.space32, t)!,
      space40: lerpDouble(space40, other.space40, t)!,
      radiusSm: lerpDouble(radiusSm, other.radiusSm, t)!,
      radiusMd: lerpDouble(radiusMd, other.radiusMd, t)!,
      radiusLg: lerpDouble(radiusLg, other.radiusLg, t)!,
      radiusXl: lerpDouble(radiusXl, other.radiusXl, t)!,
      radiusFull: lerpDouble(radiusFull, other.radiusFull, t)!,
      elevationNone: lerpDouble(elevationNone, other.elevationNone, t)!,
      elevationCard: lerpDouble(elevationCard, other.elevationCard, t)!,
      elevationSheet: lerpDouble(elevationSheet, other.elevationSheet, t)!,
      elevationModal: lerpDouble(elevationModal, other.elevationModal, t)!,
      elevationBar: lerpDouble(elevationBar, other.elevationBar, t)!,
      elevationSurface: lerpDouble(
        elevationSurface,
        other.elevationSurface,
        t,
      )!,
      breakpointCompact: lerpDouble(
        breakpointCompact,
        other.breakpointCompact,
        t,
      )!,
      breakpointRail: lerpDouble(breakpointRail, other.breakpointRail, t)!,
      breakpointTranscriptSideBySide: lerpDouble(
        breakpointTranscriptSideBySide,
        other.breakpointTranscriptSideBySide,
        t,
      )!,
      motionFast: Duration(
        milliseconds: ms(motionFast, other.motionFast).round(),
      ),
      motionStandard: Duration(
        milliseconds: ms(motionStandard, other.motionStandard).round(),
      ),
      motionEnter: Duration(
        milliseconds: ms(motionEnter, other.motionEnter).round(),
      ),
      motionExit: Duration(
        milliseconds: ms(motionExit, other.motionExit).round(),
      ),
      motionMedium: Duration(
        milliseconds: ms(motionMedium, other.motionMedium).round(),
      ),
      echoActive: Color.lerp(echoActive, other.echoActive, t)!,
      blurActive: Color.lerp(blurActive, other.blurActive, t)!,
      scoreGood: Color.lerp(scoreGood, other.scoreGood, t)!,
      scoreWarn: Color.lerp(scoreWarn, other.scoreWarn, t)!,
      scoreBad: Color.lerp(scoreBad, other.scoreBad, t)!,
      scoreGoodContainer: Color.lerp(
        scoreGoodContainer,
        other.scoreGoodContainer,
        t,
      )!,
      scoreWarnContainer: Color.lerp(
        scoreWarnContainer,
        other.scoreWarnContainer,
        t,
      )!,
      scoreBadContainer: Color.lerp(
        scoreBadContainer,
        other.scoreBadContainer,
        t,
      )!,
      accentSoft: Color.lerp(accentSoft, other.accentSoft, t)!,
      ccBadge: Color.lerp(ccBadge, other.ccBadge, t)!,
      transcriptLinePadding: EdgeInsets.lerp(
        transcriptLinePadding,
        other.transcriptLinePadding,
        t,
      )!,
      contentMaxWidth: lerpDouble(contentMaxWidth, other.contentMaxWidth, t)!,
      formMaxWidth: lerpDouble(formMaxWidth, other.formMaxWidth, t)!,
      hubMaxWidth: lerpDouble(hubMaxWidth, other.hubMaxWidth, t)!,
      pageGutterCompact: lerpDouble(
        pageGutterCompact,
        other.pageGutterCompact,
        t,
      )!,
      pageGutter: lerpDouble(pageGutter, other.pageGutter, t)!,
      miniBarBlurSigma: lerpDouble(
        miniBarBlurSigma,
        other.miniBarBlurSigma,
        t,
      )!,
      sidebarWidth: lerpDouble(sidebarWidth, other.sidebarWidth, t)!,
      sidebarBrandHeight: lerpDouble(
        sidebarBrandHeight,
        other.sidebarBrandHeight,
        t,
      )!,
      transportHeight: lerpDouble(transportHeight, other.transportHeight, t)!,
      heroTitleLetterSpacing: lerpDouble(
        heroTitleLetterSpacing,
        other.heroTitleLetterSpacing,
        t,
      )!,
      glassTint: Color.lerp(glassTint, other.glassTint, t)!,
      glassBorder: Color.lerp(glassBorder, other.glassBorder, t)!,
      gradientStart: Color.lerp(gradientStart, other.gradientStart, t)!,
      gradientEnd: Color.lerp(gradientEnd, other.gradientEnd, t)!,
      useGlassOnSidebar: t < 0.5 ? useGlassOnSidebar : other.useGlassOnSidebar,
      bottomNavHeight: lerpDouble(bottomNavHeight, other.bottomNavHeight, t)!,
      desktopGutter: lerpDouble(desktopGutter, other.desktopGutter, t)!,
      modalMaxWidth: lerpDouble(modalMaxWidth, other.modalMaxWidth, t)!,
      modalMaxWidthLarge: lerpDouble(
        modalMaxWidthLarge,
        other.modalMaxWidthLarge,
        t,
      )!,
      focusRingWidth: lerpDouble(focusRingWidth, other.focusRingWidth, t)!,
    );
  }
}
