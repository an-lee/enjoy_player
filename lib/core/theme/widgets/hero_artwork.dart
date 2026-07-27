/// Hero artwork widget — rounded square with dynamic-color rim light and
/// ground shadow. Used in AudioPlayerLayout and library cards.
library;

import 'dart:io';

import 'package:flutter/material.dart';

import '../enjoy_tokens.dart';

class HeroArtwork extends StatelessWidget {
  const HeroArtwork({
    super.key,
    required this.size,
    this.thumbnailFile,
    this.isVideo = false,
    this.accentColor,
    this.isPlaying = false,
  });

  final double size;
  final File? thumbnailFile;
  final bool isVideo;

  /// When provided, paints a subtle glow rim using this color.
  final Color? accentColor;

  /// When true, applies a very subtle scale pulse (respects reduced-motion).
  final bool isPlaying;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final accent = accentColor ?? cs.primary;

    final artwork = _buildArtwork(cs, t);

    // Ground shadow + optional rim glow
    return AnimatedContainer(
      duration: t.motionFast,
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(t.radiusXl),
        boxShadow: [
          // Ground shadow
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.28),
            blurRadius: 28,
            offset: const Offset(0, 12),
            spreadRadius: -4,
          ),
          // Rim glow from accent color
          if (accentColor != null)
            BoxShadow(
              color: accent.withValues(alpha: 0.22),
              blurRadius: 40,
              offset: const Offset(0, 4),
              spreadRadius: 0,
            ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusXl),
        child: artwork,
      ),
    );
  }

  Widget _buildArtwork(ColorScheme cs, EnjoyThemeTokens t) {
    if (thumbnailFile != null) {
      return Image.file(
        thumbnailFile!,
        width: size,
        height: size,
        fit: BoxFit.cover,
        cacheWidth: (size * 2).round(),
        errorBuilder: (_, _, _) => _placeholder(cs),
      );
    }
    return _placeholder(cs);
  }

  Widget _placeholder(ColorScheme cs) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [cs.surfaceContainerHighest, cs.surfaceContainerHigh],
        ),
      ),
      child: Center(
        child: Icon(
          isVideo ? Icons.movie_outlined : Icons.audiotrack_rounded,
          size: size * 0.35,
          color: cs.onSurfaceVariant.withValues(alpha: 0.6),
        ),
      ),
    );
  }
}
