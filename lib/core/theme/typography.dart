/// Typography tokens — Newsreader for display, Instrument Sans for UI.
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
  GoogleFonts.instrumentSans().fontFamily,
].whereType<String>().toList();

TextStyle _withCjkFallbacks(TextStyle style, {required bool serif}) {
  return style.copyWith(
    fontFamilyFallback: serif
        ? _transcriptCjkSerifFallbacks()
        : _transcriptCjkSansFallbacks(),
  );
}

TextStyle _newsreader(
  TextStyle? base, {
  required double size,
  required FontWeight weight,
  required double height,
  required double letterSpacing,
}) {
  return GoogleFonts.newsreader(
    fontSize: size,
    fontWeight: weight,
    height: height,
    letterSpacing: letterSpacing,
    color: base?.color,
  );
}

/// Builds the base [TextTheme]: Newsreader display + Instrument Sans UI.
TextTheme buildBaseTextTheme(TextTheme base, ColorScheme scheme) {
  final ui = GoogleFonts.instrumentSansTextTheme(
    base,
  ).apply(bodyColor: scheme.onSurface, displayColor: scheme.onSurface);

  return ui.copyWith(
    displayLarge: _newsreader(
      ui.displayLarge,
      size: 48,
      weight: FontWeight.w600,
      height: 1.02,
      letterSpacing: -0.8,
    ),
    displayMedium: _newsreader(
      ui.displayMedium,
      size: 36,
      weight: FontWeight.w600,
      height: 1.08,
      letterSpacing: -0.6,
    ),
    displaySmall: _newsreader(
      ui.displaySmall,
      size: 28,
      weight: FontWeight.w600,
      height: 1.15,
      letterSpacing: -0.4,
    ),
    headlineLarge: _newsreader(
      ui.headlineLarge,
      size: 28,
      weight: FontWeight.w600,
      height: 1.18,
      letterSpacing: -0.4,
    ),
    headlineMedium: _newsreader(
      ui.headlineMedium,
      size: 22,
      weight: FontWeight.w600,
      height: 1.2,
      letterSpacing: -0.3,
    ),
    headlineSmall: ui.headlineSmall?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.2,
      height: 1.25,
    ),
    titleLarge: ui.titleLarge?.copyWith(
      fontSize: 18,
      fontWeight: FontWeight.w600,
      letterSpacing: -0.15,
    ),
    titleMedium: ui.titleMedium?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w500,
      letterSpacing: -0.1,
    ),
    titleSmall: ui.titleSmall?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0,
    ),
    bodyLarge: ui.bodyLarge?.copyWith(
      fontSize: 16,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.55,
    ),
    bodyMedium: ui.bodyMedium?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.5,
    ),
    bodySmall: ui.bodySmall?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w400,
      letterSpacing: 0,
      height: 1.45,
    ),
    labelLarge: ui.labelLarge?.copyWith(
      fontSize: 14,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.1,
    ),
    labelMedium: ui.labelMedium?.copyWith(
      fontSize: 13,
      fontWeight: FontWeight.w500,
      letterSpacing: 0.2,
    ),
    labelSmall: ui.labelSmall?.copyWith(
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
        timestampStyle: GoogleFonts.jetBrainsMono(
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
      timestampStyle: GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        fontFeatures: const [FontFeature.tabularFigures()],
        color: scheme.onSurfaceVariant.withValues(alpha: 0.72),
      ),
      monoStyle: _withCjkFallbacks(
        GoogleFonts.jetBrainsMono(
          fontSize: 13,
          fontWeight: FontWeight.w500,
          letterSpacing: 0.15,
          fontFeatures: const [FontFeature.tabularFigures()],
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
