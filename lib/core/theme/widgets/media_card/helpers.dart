/// Cross-cutting helpers and grid-layout math for [MediaCardTile] / [MediaCardRow].
library;

import 'dart:async';

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/platform/mobile_platform.dart';
import 'package:enjoy_player/core/routing/player_navigation.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';

/// Inline trash on the card is for pointer UIs; phones use long-press → sheet.
bool showMediaCardPointerDeleteButton() {
  return !isMobilePlatform;
}

/// Bottom sheet with a single destructive delete action (Android / iOS).
void showMediaCardMobileDeleteMenu(
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

/// Wraps artwork in a [Hero] keyed by [mediaArtworkHeroTag] when [mediaId] is set.
Widget mediaCardHeroArtworkShell(String? mediaId, Widget child) {
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
