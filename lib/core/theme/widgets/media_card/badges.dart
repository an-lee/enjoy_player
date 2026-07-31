/// Shared visual sub-widgets for [MediaCardTile] and [MediaCardRow].
library;

import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';

import '../../enjoy_tokens.dart';
import '../../generative_media_cover.dart';

/// Thumbnail with file / network / cover-seed fallback chain.
class MediaCardThumbnail extends StatelessWidget {
  const MediaCardThumbnail({
    super.key,
    required this.file,
    this.networkUrl,
    required this.coverSeed,
    required this.isVideo,
    required this.cs,
  });

  final File? file;
  final String? networkUrl;
  final String? coverSeed;
  final bool isVideo;
  final ColorScheme cs;

  static const _coverFit = BoxFit.cover;

  Widget _networkImage(String url) {
    return CachedNetworkImage(
      imageUrl: url,
      fit: _coverFit,
      width: double.infinity,
      height: double.infinity,
      memCacheWidth: 600,
      placeholder: (context, _) => _loading(),
      errorWidget: (context, attemptedUrl, _) {
        final mqFallback = youtubeMqFallbackForCardUrl(attemptedUrl);
        if (mqFallback != null && mqFallback != attemptedUrl) {
          return _networkImage(mqFallback);
        }
        return _fallback();
      },
    );
  }

  Widget _loading() {
    if (coverSeed != null && coverSeed!.isNotEmpty) {
      return GenerativeMediaCover(seed: coverSeed!, isVideo: isVideo);
    }
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: cs.onSurfaceVariant.withValues(alpha: 0.45),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (file != null) {
      return Image.file(
        file!,
        fit: _coverFit,
        width: double.infinity,
        height: double.infinity,
        cacheWidth: 600,
        gaplessPlayback: true,
        frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
          if (wasSynchronouslyLoaded || frame != null) return child;
          return _loading();
        },
        errorBuilder: (_, _, _) => _fallback(),
      );
    }
    final url = networkUrl;
    if (url != null && url.isNotEmpty) {
      return _networkImage(url);
    }
    return _fallback();
  }

  Widget _fallback() {
    if (coverSeed != null && coverSeed!.isNotEmpty) {
      return GenerativeMediaCover(seed: coverSeed!, isVideo: isVideo);
    }
    return _placeholder();
  }

  Widget _placeholder() {
    return ColoredBox(
      color: cs.surfaceContainerHighest,
      child: Center(
        child: Icon(
          isVideo ? Icons.movie_outlined : Icons.audiotrack_rounded,
          size: 28,
          color: cs.onSurfaceVariant.withValues(alpha: 0.7),
        ),
      ),
    );
  }
}

/// Discover-style duration overlay on artwork.
class MediaCardDurationBadge extends StatelessWidget {
  const MediaCardDurationBadge({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.78),
        borderRadius: BorderRadius.circular(t.radiusSm),
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: t.space8, vertical: t.space4),
        child: Text(
          label,
          style: Theme.of(context).textTheme.labelSmall?.copyWith(
            color: Colors.white,
            fontWeight: FontWeight.w600,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
      ),
    );
  }
}

/// Pill used in [MediaCardRow] meta (language / metadata).
class MediaCardBadge extends StatelessWidget {
  const MediaCardBadge({
    super.key,
    required this.label,
    required this.cs,
    this.onTap,
    this.showLanguageIcon = false,
  });

  final String label;
  final ColorScheme cs;
  final VoidCallback? onTap;
  final bool showLanguageIcon;

  @override
  Widget build(BuildContext context) {
    final child = Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: onTap != null
            ? cs.primaryContainer.withValues(alpha: 0.55)
            : cs.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: onTap != null
              ? cs.primary.withValues(alpha: 0.45)
              : cs.outlineVariant.withValues(alpha: 0.4),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showLanguageIcon) ...[
            Icon(Icons.translate_rounded, size: 14, color: cs.primary),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: onTap != null
                  ? cs.onPrimaryContainer
                  : cs.onSurfaceVariant,
              fontWeight: onTap != null ? FontWeight.w600 : FontWeight.w400,
            ),
          ),
        ],
      ),
    );
    Widget badge = child;
    if (onTap != null) {
      badge = Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            Haptics.selection(context);
            onTap!();
          },
          borderRadius: BorderRadius.circular(999),
          child: child,
        ),
      );
    }
    return badge;
  }
}

/// Language chip overlaid on grid tile artwork (bottom-left).
class MediaCardThumbnailLanguageBadge extends StatelessWidget {
  const MediaCardThumbnailLanguageBadge({
    super.key,
    required this.label,
    required this.onTap,
  });

  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: () {
          Haptics.selection(context);
          onTap();
        },
        borderRadius: BorderRadius.circular(999),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.black.withValues(alpha: 0.78),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: Colors.white.withValues(alpha: 0.35)),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.translate_rounded,
                  size: 13,
                  color: Colors.white.withValues(alpha: 0.95),
                ),
                const SizedBox(width: 4),
                Text(
                  label,
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Provider label overlay (e.g. YouTube) on artwork.
class MediaCardProviderBadgePill extends StatelessWidget {
  const MediaCardProviderBadgePill({
    super.key,
    required this.label,
    this.compact = false,
  });

  final String label;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.symmetric(
        horizontal: compact ? 5 : 8,
        vertical: compact ? 2 : 3,
      ),
      decoration: BoxDecoration(
        color: const Color(0xFFE62117).withValues(alpha: 0.94),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
          fontSize: compact ? 9 : 11,
        ),
      ),
    );
  }
}
