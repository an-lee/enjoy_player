import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

import 'shadow_record_fab.dart';

/// Idle shadow-reading toolbar: optional **leading** slot (share) · pitch
/// toggle (left) · record FAB (center) · takes actions slot (right). The FAB
/// is overlaid on a Row whose middle reserves [ShadowRecordFab.ringOuterHitSize]
/// so the leading / pitch / takes slots hug the center without shifting the
/// mic off true horizontal center.
///
/// Extracted from `shadow_reading_panel.dart` — see issue #180.
class ShadowReadingToolbarRow extends StatelessWidget {
  const ShadowReadingToolbarRow({
    required this.tok,
    required this.scheme,
    required this.pitchExpanded,
    required this.pitchTooltip,
    required this.hasMediaPath,
    required this.onPitchTap,
    required this.takesActions,
    required this.recordFab,
    this.leadingShare,
    super.key,
  });

  final EnjoyThemeTokens tok;
  final ColorScheme scheme;
  final bool pitchExpanded;
  final String pitchTooltip;
  final bool hasMediaPath;
  final VoidCallback onPitchTap;
  final Widget? takesActions;
  final Widget recordFab;

  /// Optional widget rendered at the left edge of the toolbar, before the
  /// pitch toggle. Used by the player chrome to host
  /// [SharePracticePosterButton] when there are recordings.
  final Widget? leadingShare;

  @override
  Widget build(BuildContext context) {
    final pitchIcon = Icon(
      Icons.show_chart_rounded,
      size: 22,
      color: hasMediaPath
          ? null
          : scheme.onSurfaceVariant.withValues(alpha: 0.38),
    );

    final Widget pitchControl = Tooltip(
      message: pitchTooltip,
      child: hasMediaPath
          ? pitchExpanded
                ? IconButton.filledTonal(
                    onPressed: onPitchTap,
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: pitchIcon,
                  )
                : IconButton(
                    onPressed: onPitchTap,
                    style: IconButton.styleFrom(
                      visualDensity: VisualDensity.compact,
                      minimumSize: const Size(44, 44),
                    ),
                    icon: pitchIcon,
                  )
          : IconButton(
              onPressed: null,
              style: IconButton.styleFrom(
                visualDensity: VisualDensity.compact,
                minimumSize: const Size(44, 44),
              ),
              icon: pitchIcon,
            ),
    );

    // FAB stays at true horizontal center: overlay it on a Row whose middle
    // reserves ring width so pitch/takes hug the center without shifting the
    // mic.
    return Stack(
      alignment: Alignment.center,
      clipBehavior: Clip.none,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Align(
                alignment: Alignment.centerRight,
                child: Padding(
                  padding: EdgeInsets.only(right: tok.space12),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (leadingShare != null) leadingShare!,
                      if (leadingShare != null) SizedBox(width: tok.space4),
                      pitchControl,
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: ShadowRecordFab.ringOuterHitSize),
            Expanded(
              child: Align(
                alignment: Alignment.centerLeft,
                // Scale the takes cluster into the half-width budget so
                // play / assess / menu stay inside hit-test bounds. Without
                // this, Clip.none lets overflow paint while ancestors'
                // size.contains(position) drops taps (common on ~360dp
                // phones where three ≥44 controls exceed the right half).
                child: Padding(
                  padding: EdgeInsets.only(left: tok.space12),
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: takesActions ?? const SizedBox.shrink(),
                  ),
                ),
              ),
            ),
          ],
        ),
        recordFab,
      ],
    );
  }
}
