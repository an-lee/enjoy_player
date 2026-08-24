/// Semantic color tokens — paper (light) / graphite (dark) from the Enjoy
/// Player prototype. Source OKLCH in comments; values are baked sRGB.
///
/// Logo gradient (`logoBlue` → `logoViolet`) is mark-only. UI uses fill vs
/// ink accents derived from those endpoints.
library;

import 'package:flutter/material.dart';

abstract final class AppColors {
  // ── Logo seeds (mark only) ──────────────────────────────────────────────
  static const logoBlue = Color(0xFF4797F5);
  static const logoViolet = Color(0xFFA855F7);

  /// Deep violet fill — white labels pass WCAG AA in both themes.
  static const brand = Color(0xFF7334A9);

  /// Intelligence / lookup blue fill.
  static const brandSecondary = Color(0xFF1F68BC);

  /// High-legibility violet ink on dark graphite.
  static const brandOnDark = Color(0xFFBE8DF3);

  /// Violet ink on warm paper.
  static const brandOnLight = Color(0xFF7334A9);

  static const onAccent = Color(0xFFFDFCF8);

  /// Soft violet wash (~13% ink).
  static const accentSoft = Color(0x217334A9);

  // ── Echo (warm speaking) ────────────────────────────────────────────────
  /// Echo fill — deep enough for white labels.
  static const echoActive = Color(0xFFA24019);

  static const echoInkLight = Color(0xFF9C3A11);
  static const echoInkDark = Color(0xFFF1944F);

  /// Listening-focus / blur practice (cool teal, distinct from echo + violet).
  static const blurActive = Color(0xFF00897B);

  // ── Score inks (theme-tuned) ────────────────────────────────────────────
  static const scoreGoodLight = Color(0xFF006B39);
  static const scoreWarnLight = Color(0xFF9D5400);
  static const scoreBadLight = Color(0xFFA50D1C);
  static const scoreGoodDark = Color(0xFF59C886);
  static const scoreWarnDark = Color(0xFFEDB345);
  static const scoreBadDark = Color(0xFFFD736D);

  /// Default (dark) score inks — prefer [EnjoyThemeTokens] at runtime.
  static const scoreGood = scoreGoodDark;
  static const scoreWarn = scoreWarnDark;
  static const scoreBad = scoreBadDark;

  static const scoreGoodContainer = Color(0x2459C886);
  static const scoreWarnContainer = Color(0x24EDB345);
  static const scoreBadContainer = Color(0x29FD736D);

  // ── Intelligence blue inks ──────────────────────────────────────────────
  static const intelligenceInkLight = Color(0xFF0E5CAF);
  static const intelligenceInkDark = Color(0xFF70ADFB);
  static const intelligenceFill = Color(0xFF1F68BC);

  // ── Light — warm paper (oklch L≈0.97 C≈0.006 h=88) ─────────────────────
  static const surfaceLight = Color(0xFFFDFCF9);
  static const surfaceContainerLowestLight = Color(0xFFF7F6F1);
  static const surfaceContainerLowLight = Color(0xFFFDFCF9);
  static const surfaceContainerLight = Color(0xFFF3F0E9);
  static const surfaceContainerHighLight = Color(0xFFEDE9E1);
  static const surfaceContainerHighestLight = Color(0xFFDFDCD5);
  static const onSurfaceLight = Color(0xFF232630);
  static const mutedLight = Color(0xFF555762);
  static const faintLight = Color(0xFF6F717A);
  static const borderLight = Color(0xFFDFDCD5);
  static const borderStrongLight = Color(0xFFC5C1B7);

  static const gradientStartLight = Color(0xFFF3F0E9);
  static const gradientEndLight = Color(0xFFF7F6F1);

  // ── Dark — graphite ink (oklch L≈0.165 C≈0.012 h=275) ───────────────────
  static const surfaceDark = Color(0xFF15171E);
  static const surfaceContainerLowestDark = Color(0xFF0D0E14);
  static const surfaceContainerLowDark = Color(0xFF15171E);
  static const surfaceContainerDark = Color(0xFF1E2028);
  static const surfaceContainerHighDark = Color(0xFF292B34);
  static const surfaceContainerHighestDark = Color(0xFF2E3038);
  static const onSurfaceDark = Color(0xFFEDEBE7);
  static const mutedDark = Color(0xFF9FA1AA);
  static const faintDark = Color(0xFF7E8088);
  static const borderDark = Color(0xFF2E3038);
  static const borderStrongDark = Color(0xFF484A53);

  static const gradientStartDark = Color(0xFF1E2028);
  static const gradientEndDark = Color(0xFF0D0E14);

  /// Video stage / letterbox — theme-independent.
  static const stageBackground = Color(0xFF0C0C0E);

  static const seedBrand = brand;

  static ColorScheme colorScheme(Brightness brightness) {
    final light = brightness == Brightness.light;
    return ColorScheme(
      brightness: brightness,
      primary: brand,
      onPrimary: onAccent,
      primaryContainer: light
          ? const Color(0xFFEDE4F7)
          : const Color(0xFF3A2158),
      onPrimaryContainer: light ? brandOnLight : brandOnDark,
      secondary: intelligenceFill,
      onSecondary: onAccent,
      secondaryContainer: light
          ? const Color(0xFFD6E6F8)
          : const Color(0xFF16345C),
      onSecondaryContainer: light ? intelligenceInkLight : intelligenceInkDark,
      tertiary: echoActive,
      onTertiary: onAccent,
      tertiaryContainer: light
          ? const Color(0xFFF6E0D4)
          : const Color(0xFF4A2414),
      onTertiaryContainer: light ? echoInkLight : echoInkDark,
      error: scoreBadLight,
      onError: onAccent,
      errorContainer: light ? const Color(0xFFF8D4D6) : const Color(0xFF4A1618),
      onErrorContainer: light ? scoreBadLight : scoreBadDark,
      surface: light ? surfaceLight : surfaceDark,
      onSurface: light ? onSurfaceLight : onSurfaceDark,
      onSurfaceVariant: light ? mutedLight : mutedDark,
      surfaceDim: light
          ? surfaceContainerHighLight
          : surfaceContainerLowestDark,
      surfaceBright: light
          ? surfaceContainerLowestLight
          : surfaceContainerHighDark,
      surfaceContainerLowest: light
          ? surfaceContainerLowestLight
          : surfaceContainerLowestDark,
      surfaceContainerLow: light
          ? surfaceContainerLowLight
          : surfaceContainerLowDark,
      surfaceContainer: light ? surfaceContainerLight : surfaceContainerDark,
      surfaceContainerHigh: light
          ? surfaceContainerHighLight
          : surfaceContainerHighDark,
      surfaceContainerHighest: light
          ? surfaceContainerHighestLight
          : surfaceContainerHighestDark,
      outline: light ? borderStrongLight : borderStrongDark,
      outlineVariant: light ? borderLight : borderDark,
      inverseSurface: light ? onSurfaceLight : surfaceContainerHighestDark,
      onInverseSurface: light ? surfaceLight : onSurfaceDark,
      inversePrimary: light ? brandOnDark : brand,
      scrim: const Color(0xFF0D0E14),
      shadow: const Color(0xFF0D0E14),
    );
  }
}
