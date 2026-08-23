/// Typography tokens — Inter Tight for display, Inter for UI.
/// Source Serif 4 for transcript reading (toggled at runtime via TranscriptTypographyTokens).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// CJK fallbacks so Windows does not substitute low-quality system fonts.
List<String> _transcriptCjkSerifFallbacks() => [
  GoogleFonts.notoSerifKr().fontFamily,
  GoogleFonts.notoSerifSc().fontFamily,
  GoogleFonts.notoSerifJp().fontFamily,
].whereType<String>().toList();

List<String> _transcriptCjkSansFallbacks() => [
  GoogleFonts.notoSansKr().fontFamily,
  GoogleFonts.notoSansSc().fontFamily,
  GoogleFonts.notoSansJp().fontFamily,
  GoogleFonts.inter().fontFamily,
].whereType<String>().toList();

TextStyle _withCjkFallbacks(TextStyle style, {required bool serif}) {
  return style.copyWith(
    fontFamilyFallback: serif
        ? _transcriptCjkSerifFallbacks()
        : _transcriptCjkSansFallbacks(),
  );
}

/// Builds the base [TextTheme] using Inter family.
///
/// Display titles use Inter (approximating Inter Tight until the Google Fonts
/// package ships that variant — tracking is manually tightened to match).
TextTheme buildBaseTextTheme(TextTheme base, ColorScheme scheme) {
  // Apply Inter to the full theme, then hand-tune the scale.
  final inter = GoogleFonts.interTextTheme(
    base,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return inter.copyWith(
    // ── Display (hero titles) — tight tracking ─────────────────────────
    displayLarge: inter.displayLarge?.copyWith(
      fontSize: 48,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.5,
      height: 1.1,
    ),
    displayMedium: inter.displayMedium?.copyWith(
      fontSize: 36,
      fontWeight: FontWeight.w600,
      letterSpacing: -1.2,
      height: 1.12,
    ),
    displaySmall: inter.displaySmall?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.8,
      height: 1.15,
    ),

    // ── Headline ──────────────────────────────────────────────────────
    headlineLarge: inter.headlineLarge?.copyWith(
      fontSize: 28,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.6,
      height: 1.18,
    ),
    headlineMedium: inter.headlineMedium?.copyWith(
      fontSize: 22,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.4,
      height: 1.2,
    ),
    headlineSmall: inter.headlineSmall?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.25,
    ),

    // ── Title ─────────────────────────────────────────────────────────
    titleLarge: inter.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
    ),
    titleMedium: inter.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
    ),
    titleSmall: inter.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),

    // ── Body ──────────────────────────────────────────────────────────
    bodyLarge: inter.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.55,
    ),
    bodyMedium: inter.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
    ),
    bodySmall: inter.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.45,
    ),

    // ── Label ─────────────────────────────────────────────────────────
    labelLarge: inter.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: inter.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
    labelSmall: inter.labelSmall?.copyWith(
      fontSize: 12,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      fontFeatures: const [FontFeature.tabularFigures()],
    ),
  );
}

/// Theme extension carrying Source Serif 4 styles for transcript reading.
///
/// Widgets that render transcript lines read [TranscriptTypographyTokens.of]
/// and use [bodyStyle] / [secondaryStyle] when the user has enabled
/// serif reading mode.
@immutable
class TranscriptTypographyTokens
    extends ThemeExtension<TranscriptTypographyTokens> {
  const TranscriptTypographyTokens({
    required this.useSerif,
    required this.bodyStyle,
    required this.secondaryStyle,
    required this.timestampStyle,
    this.monoStyle = const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.15,
      fontFamily: 'monospace',
      fontFeatures: [FontFeature.tabularFigures()],
    ),
    this.displaySerifStyle = const TextStyle(
      fontSize: 30,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.5,
      fontFamily: 'serif',
    ),
  });

  final bool useSerif;
  final TextStyle bodyStyle;
  final TextStyle secondaryStyle;
  final TextStyle timestampStyle;

  /// Monospace / numeric style for timers, durations, scores, and badges.
  final TextStyle monoStyle;

  /// Editorial serif display style for hero & screen titles.
  final TextStyle displaySerifStyle;

  static TranscriptTypographyTokens of(BuildContext context) {
    return Theme.of(context).extension<TranscriptTypographyTokens>() ??
        _fallback(Theme.of(context).textTheme, Theme.of(context).colorScheme);
  }

  static TranscriptTypographyTokens build({
    required bool useSerif,
    required TextTheme base,
    required ColorScheme scheme,
  }) {
    if (useSerif) {
      final serif = GoogleFonts.sourceSerif4TextTheme(
        base,
      ).apply(bodyColor: scheme.onSurface);
      return TranscriptTypographyTokens(
        useSerif: true,
        bodyStyle: _withCjkFallbacks(
          (serif.bodyLarge ?? const TextStyle()).copyWith(
            fontSize: 17,
            fontWeight: FontWeight.w400,
            height: 1.65,
            letterSpacing: 0.01,
            color: scheme.onSurface,
          ),
          serif: true,
        ),
        secondaryStyle: _withCjkFallbacks(
          GoogleFonts.notoSansSc(
            fontSize: 14,
            fontWeight: FontWeight.w400,
            height: 1.55,
            letterSpacing: 0.02,
            color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
          ),
          serif: false,
        ),
        timestampStyle: (base.labelSmall ?? const TextStyle()).copyWith(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.1,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
        ),
        monoStyle: _withCjkFallbacks(
          GoogleFonts.jetBrainsMono(
            fontSize: 13,
            fontWeight: FontWeight.w500,
            letterSpacing: 0.15,
            color: scheme.onSurface,
          ),
          serif: false,
        ),
        displaySerifStyle: _withCjkFallbacks(
          GoogleFonts.newsreader(
            fontSize: 30,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.5,
            color: scheme.onSurface,
          ),
          serif: true,
        ),
      );
    }
    return _fallback(base, scheme);
  }

  static TranscriptTypographyTokens _fallback(
    TextTheme base,
    ColorScheme scheme,
  ) {
    return TranscriptTypographyTokens(
      useSerif: false,
      bodyStyle: _withCjkFallbacks(
        (base.bodyLarge ?? const TextStyle()).copyWith(
          fontSize: 16,
          height: 1.6,
          color: scheme.onSurface,
        ),
        serif: false,
      ),
      secondaryStyle: _withCjkFallbacks(
        GoogleFonts.notoSansSc(
          fontSize: 13.5,
          fontWeight: FontWeight.w400,
          height: 1.55,
          letterSpacing: 0.02,
          color: scheme.onSurfaceVariant.withValues(alpha: 0.88),
        ),
        serif: false,
      ),
      timestampStyle: (base.labelSmall ?? const TextStyle()).copyWith(
        fontFeatures: const [FontFeature.tabularFigures()],
        color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      ),
      monoStyle: _withCjkFallbacks(
        (base.labelSmall ?? const TextStyle()).copyWith(
          fontFamily: 'monospace',
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: scheme.onSurface,
        ),
        serif: false,
      ),
      displaySerifStyle: _withCjkFallbacks(
        (base.displaySmall ?? const TextStyle()).copyWith(
          fontFamily: 'serif',
          fontSize: 30,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.5,
          color: scheme.onSurface,
        ),
        serif: true,
      ),
    );
  }

  @override
  TranscriptTypographyTokens copyWith({
    bool? useSerif,
    TextStyle? bodyStyle,
    TextStyle? secondaryStyle,
    TextStyle? timestampStyle,
    TextStyle? monoStyle,
    TextStyle? displaySerifStyle,
  }) {
    return TranscriptTypographyTokens(
      useSerif: useSerif ?? this.useSerif,
      bodyStyle: bodyStyle ?? this.bodyStyle,
      secondaryStyle: secondaryStyle ?? this.secondaryStyle,
      timestampStyle: timestampStyle ?? this.timestampStyle,
      monoStyle: monoStyle ?? this.monoStyle,
      displaySerifStyle: displaySerifStyle ?? this.displaySerifStyle,
    );
  }

  @override
  TranscriptTypographyTokens lerp(
    covariant ThemeExtension<TranscriptTypographyTokens>? other,
    double t,
  ) {
    if (other is! TranscriptTypographyTokens) return this;
    return TranscriptTypographyTokens(
      useSerif: t < 0.5 ? useSerif : other.useSerif,
      bodyStyle: TextStyle.lerp(bodyStyle, other.bodyStyle, t)!,
      secondaryStyle: TextStyle.lerp(secondaryStyle, other.secondaryStyle, t)!,
      timestampStyle: TextStyle.lerp(timestampStyle, other.timestampStyle, t)!,
      monoStyle: TextStyle.lerp(monoStyle, other.monoStyle, t)!,
      displaySerifStyle: TextStyle.lerp(
        displaySerifStyle,
        other.displaySerifStyle,
        t,
      )!,
    );
  }
}
