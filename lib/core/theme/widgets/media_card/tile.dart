/// Vertical [MediaCardTile] for grids (video / home).
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';
import 'package:enjoy_player/core/platform/mobile_platform.dart';

import '../../enjoy_tokens.dart';
import 'badges.dart';
import 'helpers.dart';

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
      onEnter: (_) => setValueNotifierOutsideMouseTracker(_hover, true),
      onExit: (_) => setValueNotifierOutsideMouseTracker(_hover, false),
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
              ? () => showMediaCardMobileDeleteMenu(
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
                        mediaCardHeroArtworkShell(
                          widget.heroArtworkMediaId,
                          MediaCardThumbnail(
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
                            child: MediaCardProviderBadgePill(
                              label: widget.providerBadge!,
                            ),
                          ),
                        if (widget.durationLabel != null &&
                            widget.durationLabel!.isNotEmpty)
                          Positioned(
                            right: t.space8,
                            bottom: t.space8,
                            child: MediaCardDurationBadge(
                              label: widget.durationLabel!,
                            ),
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
                            child: MediaCardThumbnailLanguageBadge(
                              label: widget.badge!,
                              onTap: widget.onBadgeTap!,
                            ),
                          ),
                        if (widget.onDelete != null &&
                            showMediaCardPointerDeleteButton())
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
