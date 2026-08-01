/// Shared tappable surfaces: ripple, hover scale, cursor, focus, haptics.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/interaction/mouse_tracker_safe.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

/// Card / tile tap target with Material ripple and optional hover scale.
class EnjoyTappableSurface extends StatefulWidget {
  const EnjoyTappableSurface({
    super.key,
    required this.borderRadius,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.enableHoverScale = true,
    this.hoverScale = 1.01,
    this.semanticsLabel,
    this.excludeSemantics = false,
  });

  final BorderRadius borderRadius;
  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final bool enableHoverScale;
  final double hoverScale;
  final String? semanticsLabel;
  final bool excludeSemantics;

  @override
  State<EnjoyTappableSurface> createState() => _EnjoyTappableSurfaceState();
}

class _EnjoyTappableSurfaceState extends State<EnjoyTappableSurface> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final instant = MediaQuery.disableAnimationsOf(context);
    final scale =
        (!instant && widget.enableHoverScale && widget.onTap != null && _hover)
        ? widget.hoverScale
        : 1.0;

    Widget core = Material(
      color: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: widget.borderRadius),
      child: InkWell(
        borderRadius: widget.borderRadius,
        onTap: widget.onTap == null
            ? null
            : () {
                Haptics.selection(context);
                widget.onTap!();
              },
        onLongPress: widget.onLongPress == null
            ? null
            : () {
                Haptics.impactMedium(context);
                widget.onLongPress!();
              },
        hoverColor: cs.onSurface.withValues(alpha: 0.06),
        splashColor: cs.primary.withValues(alpha: 0.10),
        highlightColor: cs.primary.withValues(alpha: 0.06),
        child: widget.child,
      ),
    );

    core = AnimatedScale(
      scale: scale,
      duration: t.motionFast,
      curve: Curves.easeOutCubic,
      child: core,
    );

    core = Focus(canRequestFocus: widget.onTap != null, child: core);

    core = MouseRegion(
      cursor: widget.onTap != null
          ? SystemMouseCursors.click
          : MouseCursor.defer,
      onEnter: (_) => runOutsideMouseTrackerIfMounted(() => mounted, () {
        if (_hover) return;
        setState(() => _hover = true);
      }),
      onExit: (_) => runOutsideMouseTrackerIfMounted(() => mounted, () {
        if (!_hover) return;
        setState(() => _hover = false);
      }),
      child: core,
    );

    if (widget.semanticsLabel != null) {
      core = Semantics(
        button: widget.onTap != null,
        label: widget.semanticsLabel,
        excludeSemantics: widget.excludeSemantics,
        child: core,
      );
    }

    return core;
  }
}

/// Icon control with haptic on press (use for custom icon rows; prefer [IconButton] + haptic for a11y).
class EnjoyTappableIcon extends StatelessWidget {
  const EnjoyTappableIcon({
    super.key,
    required this.icon,
    required this.onPressed,
    this.tooltip,
    this.semanticLabel,
    this.iconSize = 24,
    this.visualDensity = VisualDensity.standard,
    this.style,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final String? semanticLabel;
  final double iconSize;
  final VisualDensity visualDensity;
  final ButtonStyle? style;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final button = IconButton(
      tooltip: tooltip,
      icon: Icon(icon, size: iconSize, color: color),
      visualDensity: visualDensity,
      style: style,
      onPressed: onPressed == null
          ? null
          : () {
              Haptics.selection(context);
              onPressed!();
            },
    );
    if (semanticLabel == null) return button;
    return Semantics(label: semanticLabel, button: true, child: button);
  }
}
