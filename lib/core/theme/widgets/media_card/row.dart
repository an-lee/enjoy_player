/// Horizontal [MediaCardRow] for list views (audio).
library;

import 'dart:io';

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';
import 'package:enjoy_player/core/platform/mobile_platform.dart';

import '../../enjoy_tokens.dart';
import 'badges.dart';
import 'helpers.dart';
import 'media_card_sync_badge.dart';

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
    this.cloudSyncBadge,
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

  /// Cloud-sync state pill rendered on the thumbnail top-right. When set,
  /// a small icon-only pill indicates whether the audio is synced, queued
  /// for sync, or local-only.
  final MediaCardSyncBadge? cloudSyncBadge;
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
    if (widget.onDelete != null && showMediaCardPointerDeleteButton()) {
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
      onEnter: (_) => setValueNotifierOutsideMouseTracker(_hover, true),
      onExit: (_) => setValueNotifierOutsideMouseTracker(_hover, false),
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
              ? () => showMediaCardMobileDeleteMenu(
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
                              top: 4,
                              left: 4,
                              child: MediaCardProviderBadgePill(
                                label: widget.providerBadge!,
                                compact: true,
                              ),
                            ),
                          if (widget.cloudSyncBadge != null)
                            Positioned(
                              top: 4,
                              right: 4,
                              child: MediaCardSyncBadgePill(
                                state: widget.cloudSyncBadge!,
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
                                MediaCardBadge(
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
