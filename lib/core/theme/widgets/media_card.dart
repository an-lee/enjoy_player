/// Shared MediaCard primitive — replaces the ad-hoc tiles in Home and Library.
///
/// Supports two layouts:
///   [MediaCard.tile] — vertical card for grids (video/home).
///   [MediaCard.row]  — horizontal row card for list views (audio).
library;

import 'dart:async';
import 'dart:io';

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/platform/mobile_platform.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';

import '../enjoy_tokens.dart';
import '../generative_media_cover.dart';

/// Inline trash on the card is for pointer UIs; phones use long-press → sheet.
bool _showPointerDeleteButton() {
  return !isMobilePlatform;
}

/// Bottom sheet with a single destructive delete action (Android / iOS).
void _showMobileDeleteMenu(
  BuildContext context, {
  required VoidCallback onDelete,
  String? label,
}) {
  Haptics.impactMedium(context);
  final ml = MaterialLocalizations.of(context);
  final title = (label != null && label.isNotEmpty)
      ? label
      : ml.deleteButtonTooltip;
  unawaited(
    showEnjoySheet<void>(
      context: context,
      builder: (sheetContext) {
        final cs = Theme.of(sheetContext).colorScheme;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const PaddedSheetDragHandle(),
              ListTile(
                leading: Icon(Icons.delete_outline_rounded, color: cs.error),
                title: Text(
                  title,
                  style: Theme.of(sheetContext).textTheme.titleMedium?.copyWith(
                    color: cs.error,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                onTap: () {
                  Navigator.pop(sheetContext);
                  onDelete();
                },
              ),
            ],
          ),
        );
      },
    ),
  );
}

Widget _heroArtworkShell(String? mediaId, Widget child) {
  if (mediaId == null || mediaId.isEmpty) return child;
  return Hero(
    tag: mediaArtworkHeroTag(mediaId),
    child: Material(type: MaterialType.transparency, child: child),
  );
}

/// Meta block under 16:9 artwork: padding 8+12, title 14×1.25, optional subtitle row.
const double mediaCardTileMetaHeight = 58;

/// [BoxDecoration.border] inset at rest / on hover (up to 1.5 logical px per edge).
const double mediaCardTileBorderInset = 3;

/// Grid width÷height for a [MediaCardTile] column of [tileWidth].
double mediaCardTileGridAspectRatioForWidth(double tileWidth) {
  return tileWidth /
      (tileWidth * 9 / 16 + mediaCardTileMetaHeight + mediaCardTileBorderInset);
}

/// Default max column width for library / cloud video grids.
const double mediaCardTileDefaultMaxWidth = 280;

/// Minimum column width for home recents.
const double mediaCardTileHomeMinWidth = 200;

int _mediaCardTileCrossAxisCountForMaxWidth({
  required double crossAxisExtent,
  required double maxTileWidth,
  required double crossAxisSpacing,
  required int maxCrossAxisCount,
}) {
  return ((crossAxisExtent + crossAxisSpacing) /
          (maxTileWidth + crossAxisSpacing))
      .ceil()
      .clamp(1, maxCrossAxisCount);
}

double _mediaCardTileWidth({
  required double crossAxisExtent,
  required int crossAxisCount,
  required double crossAxisSpacing,
}) {
  return (crossAxisExtent - crossAxisSpacing * (crossAxisCount - 1)) /
      crossAxisCount;
}

/// Grid delegate with column count derived from [maxTileWidth] (library / cloud).
SliverGridDelegate mediaCardTileGridDelegateForMaxTileWidth({
  required double crossAxisExtent,
  double maxTileWidth = mediaCardTileDefaultMaxWidth,
  double mainAxisSpacing = 12,
  double crossAxisSpacing = 12,
  int maxCrossAxisCount = 99,
}) {
  final crossAxisCount = _mediaCardTileCrossAxisCountForMaxWidth(
    crossAxisExtent: crossAxisExtent,
    maxTileWidth: maxTileWidth,
    crossAxisSpacing: crossAxisSpacing,
    maxCrossAxisCount: maxCrossAxisCount,
  );
  final tileWidth = _mediaCardTileWidth(
    crossAxisExtent: crossAxisExtent,
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: crossAxisSpacing,
  );
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    mainAxisSpacing: mainAxisSpacing,
    crossAxisSpacing: crossAxisSpacing,
    childAspectRatio: mediaCardTileGridAspectRatioForWidth(tileWidth),
  );
}

/// Grid delegate with column count derived from [minTileWidth] (home recents).
SliverGridDelegate mediaCardTileGridDelegateForMinTileWidth({
  required double crossAxisExtent,
  double minTileWidth = mediaCardTileHomeMinWidth,
  double mainAxisSpacing = 12,
  double crossAxisSpacing = 12,
  int maxCrossAxisCount = 6,
}) {
  final crossAxisCount = (crossAxisExtent / minTileWidth).floor().clamp(
    1,
    maxCrossAxisCount,
  );
  final tileWidth = _mediaCardTileWidth(
    crossAxisExtent: crossAxisExtent,
    crossAxisCount: crossAxisCount,
    crossAxisSpacing: crossAxisSpacing,
  );
  return SliverGridDelegateWithFixedCrossAxisCount(
    crossAxisCount: crossAxisCount,
    mainAxisSpacing: mainAxisSpacing,
    crossAxisSpacing: crossAxisSpacing,
    childAspectRatio: mediaCardTileGridAspectRatioForWidth(tileWidth),
  );
}

// ── Tile (vertical, for grids) ──────────────────────────────────────────────

class MediaCardTile extends StatefulWidget {
  const MediaCardTile({
    super.key,
    required this.title,
    required this.onTap,
    this.thumbnailFile,
    this.thumbnailNetworkUrl,
    this.coverSeed,
    this.subtitle,
    this.isVideo = false,
    this.accentColor,
    this.onDelete,
    this.deleteTooltip,
    this.providerBadge,
    this.durationLabel,
    this.badge,
    this.onBadgeTap,
    this.heroArtworkMediaId,
  });

  final String title;
  final VoidCallback onTap;
  final File? thumbnailFile;

  /// When [thumbnailFile] is null, optional `http(s)` artwork (e.g. cloud index).
  final String? thumbnailNetworkUrl;

  /// When [thumbnailFile] is null or fails to load, used for [GenerativeMediaCover].
  final String? coverSeed;
  final String? subtitle;
  final bool isVideo;
  final Color? accentColor;

  /// When non-null: on desktop / web, a corner delete control on the thumbnail; on
  /// Android / iOS, long-press opens a bottom sheet with delete (then the caller’s flow).
  final VoidCallback? onDelete;

  /// Label for hover tooltip and mobile delete sheet when [onDelete] is non-null.
  final String? deleteTooltip;

  /// When set, artwork participates in a [Hero] into the player transport tile.
  final String? heroArtworkMediaId;

  /// e.g. "YouTube" — top-left on artwork.
  final String? providerBadge;

  /// When set, shown on the thumbnail (Discover-style) instead of the video icon.
  final String? durationLabel;

  /// Optional language or metadata chip below the title.
  final String? badge;
  final VoidCallback? onBadgeTap;

  @override
  State<MediaCardTile> createState() => _MediaCardTileState();
}

class _MediaCardTileState extends State<MediaCardTile> {
  final _hover = ValueNotifier<bool>(false);
  bool _deleteFocused = false;

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = widget.accentColor ?? cs.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hover.value = true,
      onExit: (_) => _hover.value = false,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusXl),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusXl),
          onTap: () {
            Haptics.selection(context);
            widget.onTap();
          },
          onLongPress: widget.onDelete != null && isMobilePlatform
              ? () => _showMobileDeleteMenu(
                  context,
                  onDelete: widget.onDelete!,
                  label: widget.deleteTooltip,
                )
              : null,
          hoverColor: cs.onSurface.withValues(alpha: 0.04),
          splashColor: accent.withValues(alpha: 0.12),
          highlightColor: accent.withValues(alpha: 0.06),
          child: ValueListenableBuilder<bool>(
            valueListenable: _hover,
            builder: (context, hover, child) {
              return AnimatedContainer(
                duration: t.motionFast,
                curve: Curves.easeOutCubic,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t.radiusXl),
                  color: hover
                      ? accent.withValues(alpha: 0.08)
                      : cs.surfaceContainerLow,
                  border: Border.all(
                    color: hover
                        ? accent.withValues(alpha: 0.6)
                        : cs.outlineVariant.withValues(alpha: 0.25),
                    width: hover ? 1.5 : 1,
                  ),
                  boxShadow: hover
                      ? [
                          BoxShadow(
                            color: accent.withValues(alpha: 0.12),
                            blurRadius: 16,
                            offset: const Offset(0, 4),
                          ),
                        ]
                      : null,
                ),
                child: child,
              );
            },
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                AspectRatio(
                  aspectRatio: 16 / 9,
                  child: ClipRRect(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(t.radiusXl - 1),
                    ),
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        _heroArtworkShell(
                          widget.heroArtworkMediaId,
                          _Thumbnail(
                            file: widget.thumbnailFile,
                            networkUrl: widget.thumbnailNetworkUrl,
                            coverSeed: widget.coverSeed,
                            isVideo: widget.isVideo,
                            cs: cs,
                          ),
                        ),
                        if (widget.providerBadge != null &&
                            widget.providerBadge!.isNotEmpty)
                          Positioned(
                            top: t.space8,
                            left: t.space8,
                            child: _ProviderBadgePill(
                              label: widget.providerBadge!,
                            ),
                          ),
                        if (widget.durationLabel != null &&
                            widget.durationLabel!.isNotEmpty)
                          Positioned(
                            right: t.space8,
                            bottom: t.space8,
                            child: _DurationBadge(label: widget.durationLabel!),
                          )
                        else if (widget.badge == null ||
                            widget.onBadgeTap == null)
                          Positioned(
                            right: t.space8,
                            bottom: t.space8,
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: Colors.black.withValues(alpha: 0.42),
                                boxShadow: const [
                                  BoxShadow(
                                    blurRadius: 10,
                                    offset: Offset(0, 2),
                                    color: Colors.black38,
                                  ),
                                ],
                              ),
                              child: Padding(
                                padding: const EdgeInsets.all(9),
                                child: Icon(
                                  widget.isVideo
                                      ? Icons.videocam_rounded
                                      : Icons.audiotrack_rounded,
                                  size: 22,
                                  color: Colors.white.withValues(alpha: 0.95),
                                ),
                              ),
                            ),
                          ),
                        if (widget.badge != null && widget.onBadgeTap != null)
                          Positioned(
                            left: t.space8,
                            bottom: t.space8,
                            child: _ThumbnailLanguageBadge(
                              label: widget.badge!,
                              onTap: widget.onBadgeTap!,
                            ),
                          ),
                        if (widget.onDelete != null &&
                            _showPointerDeleteButton())
                          Positioned(
                            top: t.space8,
                            right: t.space8,
                            child: Focus(
                              onFocusChange: (f) =>
                                  setState(() => _deleteFocused = f),
                              child: ValueListenableBuilder<bool>(
                                valueListenable: _hover,
                                builder: (context, hover, child) {
                                  final strong = hover || _deleteFocused;
                                  return AnimatedOpacity(
                                    opacity: strong ? 1 : 0.45,
                                    duration: t.motionFast,
                                    curve: Curves.easeOut,
                                    child: child,
                                  );
                                },
                                child: IconButton(
                                  visualDensity: VisualDensity.compact,
                                  iconSize: 20,
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(
                                    minWidth: 40,
                                    minHeight: 40,
                                  ),
                                  tooltip:
                                      (widget.deleteTooltip != null &&
                                          widget.deleteTooltip!.isNotEmpty)
                                      ? widget.deleteTooltip!
                                      : MaterialLocalizations.of(
                                          context,
                                        ).deleteButtonTooltip,
                                  style: IconButton.styleFrom(
                                    backgroundColor: cs.surfaceContainerHighest
                                        .withValues(alpha: 0.92),
                                    foregroundColor: cs.onSurfaceVariant,
                                    shape: const CircleBorder(),
                                  ),
                                  icon: const Icon(
                                    Icons.delete_outline_rounded,
                                  ),
                                  onPressed: widget.onDelete,
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
                // Meta — fixed vertical budget (ellipsis); never steals flex from overflow.
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space12,
                    t.space8,
                    t.space12,
                    t.space12,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        widget.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: tt.titleSmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          height: 1.25,
                        ),
                      ),
                      if (widget.subtitle != null) ...[
                        SizedBox(height: t.space4),
                        Text(
                          widget.subtitle!,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: tt.bodySmall?.copyWith(
                            color: cs.onSurfaceVariant,
                            height: 1.2,
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                        ),
                      ],
                    ],
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

// ── Row (horizontal, for lists) ─────────────────────────────────────────────

class MediaCardRow extends StatefulWidget {
  const MediaCardRow({
    super.key,
    required this.title,
    required this.onTap,
    this.thumbnailFile,
    this.thumbnailNetworkUrl,
    this.coverSeed,
    this.subtitle,
    this.badge,
    this.providerBadge,
    this.isVideo = false,
    this.accentColor,
    this.trailing,
    this.onDelete,
    this.deleteTooltip,
    this.onBadgeTap,
    this.heroArtworkMediaId,
  });

  final String title;
  final VoidCallback onTap;
  final File? thumbnailFile;
  final String? thumbnailNetworkUrl;
  final String? coverSeed;
  final String? subtitle;
  final String? badge;
  final VoidCallback? onBadgeTap;

  /// Source label on thumbnail (e.g. YouTube).
  final String? providerBadge;
  final bool isVideo;
  final Color? accentColor;
  final Widget? trailing;

  /// When non-null (and [trailing] is null): delete beside the chevron on pointer platforms;
  /// on Android / iOS, long-press opens a bottom sheet with delete.
  final VoidCallback? onDelete;

  /// Label for hover tooltip and mobile delete sheet when [onDelete] is non-null.
  final String? deleteTooltip;

  /// When set, artwork participates in a [Hero] into the player transport tile.
  final String? heroArtworkMediaId;

  @override
  State<MediaCardRow> createState() => _MediaCardRowState();
}

class _MediaCardRowState extends State<MediaCardRow> {
  final _hover = ValueNotifier<bool>(false);
  bool _deleteFocused = false;

  @override
  void dispose() {
    _hover.dispose();
    super.dispose();
  }

  Widget _buildTrailing(ColorScheme cs, EnjoyThemeTokens t) {
    if (widget.trailing != null) return widget.trailing!;
    if (widget.onDelete != null && _showPointerDeleteButton()) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Focus(
            onFocusChange: (f) => setState(() => _deleteFocused = f),
            child: ValueListenableBuilder<bool>(
              valueListenable: _hover,
              builder: (context, hover, child) {
                final strong = hover || _deleteFocused;
                return AnimatedOpacity(
                  opacity: strong ? 1 : 0.45,
                  duration: t.motionFast,
                  curve: Curves.easeOut,
                  child: child,
                );
              },
              child: IconButton(
                visualDensity: VisualDensity.compact,
                iconSize: 22,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 40),
                tooltip:
                    (widget.deleteTooltip != null &&
                        widget.deleteTooltip!.isNotEmpty)
                    ? widget.deleteTooltip!
                    : MaterialLocalizations.of(context).deleteButtonTooltip,
                onPressed: widget.onDelete,
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: cs.onSurfaceVariant,
                ),
              ),
            ),
          ),
          Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant),
        ],
      );
    }
    return Icon(Icons.chevron_right_rounded, color: cs.onSurfaceVariant);
  }

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final accent = widget.accentColor ?? cs.primary;

    return MouseRegion(
      cursor: SystemMouseCursors.click,
      onEnter: (_) => _hover.value = true,
      onExit: (_) => _hover.value = false,
      child: Material(
        color: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(t.radiusLg),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(t.radiusLg),
          onTap: () {
            Haptics.selection(context);
            widget.onTap();
          },
          onLongPress:
              widget.trailing == null &&
                  widget.onDelete != null &&
                  isMobilePlatform
              ? () => _showMobileDeleteMenu(
                  context,
                  onDelete: widget.onDelete!,
                  label: widget.deleteTooltip,
                )
              : null,
          hoverColor: cs.onSurface.withValues(alpha: 0.04),
          splashColor: accent.withValues(alpha: 0.10),
          highlightColor: accent.withValues(alpha: 0.05),
          child: ValueListenableBuilder<bool>(
            valueListenable: _hover,
            builder: (context, hover, child) {
              return AnimatedContainer(
                duration: t.motionFast,
                curve: Curves.easeOutCubic,
                clipBehavior: Clip.antiAlias,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(t.radiusLg),
                  color: hover
                      ? accent.withValues(alpha: 0.06)
                      : cs.surfaceContainerLow,
                  border: Border.all(
                    color: hover
                        ? accent.withValues(alpha: 0.45)
                        : cs.outlineVariant.withValues(alpha: 0.2),
                    width: hover ? 1.5 : 1,
                  ),
                ),
                child: child,
              );
            },
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space16,
                vertical: t.space12,
              ),
              child: Row(
                children: [
                  // Thumbnail square
                  ClipRRect(
                    borderRadius: BorderRadius.circular(t.radiusMd),
                    child: SizedBox(
                      width: 56,
                      height: 56,
                      child: Stack(
                        fit: StackFit.expand,
                        children: [
                          _heroArtworkShell(
                            widget.heroArtworkMediaId,
                            _Thumbnail(
                              file: widget.thumbnailFile,
                              networkUrl: widget.thumbnailNetworkUrl,
                              coverSeed: widget.coverSeed,
                              isVideo: widget.isVideo,
                              cs: cs,
                            ),
                          ),
                          if (widget.providerBadge != null &&
                              widget.providerBadge!.isNotEmpty)
                            Positioned(
                              top: 4,
                              left: 4,
                              child: _ProviderBadgePill(
                                label: widget.providerBadge!,
                                compact: true,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  SizedBox(width: t.space16),
                  // Title + meta
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: tt.titleMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (widget.subtitle != null ||
                            widget.badge != null) ...[
                          SizedBox(height: t.space4),
                          Row(
                            children: [
                              if (widget.badge != null) ...[
                                _Badge(
                                  label: widget.badge!,
                                  cs: cs,
                                  onTap: widget.onBadgeTap,
                                  showLanguageIcon: widget.onBadgeTap != null,
                                ),
                                SizedBox(width: t.space8),
                              ],
                              if (widget.subtitle != null)
                                Text(
                                  widget.subtitle!,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ],
                    ),
                  ),
                  // Trailing
                  _buildTrailing(cs, t),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Shared helpers ───────────────────────────────────────────────────────────

class _Thumbnail extends StatelessWidget {
  const _Thumbnail({
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

class _DurationBadge extends StatelessWidget {
  const _DurationBadge({required this.label});

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

class _Badge extends StatelessWidget {
  const _Badge({
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
class _ThumbnailLanguageBadge extends StatelessWidget {
  const _ThumbnailLanguageBadge({required this.label, required this.onTap});

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

class _ProviderBadgePill extends StatelessWidget {
  const _ProviderBadgePill({required this.label, this.compact = false});

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
