/// Custom floating bottom navigation — Enjoy editorial chrome (not stock [NavigationBar]).
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/foundation.dart'
    show TargetPlatform, defaultTargetPlatform;
import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

class EnjoyBottomNavDestination {
  const EnjoyBottomNavDestination({
    required this.icon,
    required this.selectedIcon,
    required this.label,
    this.semanticsLabel,
    this.showBadge = false,
  });

  final IconData icon;
  final IconData selectedIcon;
  final String label;

  /// Defaults to [label] when null.
  final String? semanticsLabel;

  /// Small notification dot on the icon (e.g. pending app update).
  final bool showBadge;
}

class EnjoyBottomNav extends StatelessWidget {
  const EnjoyBottomNav({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
    required this.destinations,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;
  final List<EnjoyBottomNavDestination> destinations;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    final blurRaw = t.miniBarBlurSigma;
    final blur = defaultTargetPlatform == TargetPlatform.android
        ? (blurRaw > 10 ? 10.0 : blurRaw)
        : blurRaw;

    return SafeArea(
      top: false,
      minimum: EdgeInsets.fromLTRB(t.space16, t.space4, t.space16, t.space12),
      child: Align(
        alignment: Alignment.bottomCenter,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(t.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.40),
                  blurRadius: 28,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(t.radiusXl),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: cs.surface.withValues(alpha: 0.82),
                    borderRadius: BorderRadius.circular(t.radiusXl),
                    border: Border.all(color: t.glassBorder, width: 1),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(6),
                    child: Row(
                      mainAxisSize: MainAxisSize.max,
                      children: [
                        for (var i = 0; i < destinations.length; i++)
                          Expanded(
                            child: _EnjoyBottomNavItem(
                              destination: destinations[i],
                              selected: i == selectedIndex,
                              onTap: () {
                                Haptics.selection(context);
                                onDestinationSelected(i);
                              },
                            ),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EnjoyBottomNavItem extends StatelessWidget {
  const _EnjoyBottomNavItem({
    required this.destination,
    required this.selected,
    required this.onTap,
  });

  final EnjoyBottomNavDestination destination;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final label = destination.semanticsLabel ?? destination.label;

    return Semantics(
      container: true,
      button: true,
      selected: selected,
      label: label,
      child: Focus(
        child: Builder(
          builder: (focusContext) {
            final focused = Focus.of(focusContext).hasFocus;
            return Padding(
              padding: EdgeInsets.symmetric(horizontal: t.space4),
              child: Material(
                color: Colors.transparent,
                clipBehavior: Clip.antiAlias,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(t.radiusLg),
                  side: focused && !selected
                      ? BorderSide(
                          color: cs.primary.withValues(alpha: 0.55),
                          width: t.focusRingWidth,
                        )
                      : BorderSide.none,
                ),
                child: InkWell(
                  onTap: onTap,
                  borderRadius: BorderRadius.circular(t.radiusLg),
                  hoverColor: cs.onSurface.withValues(alpha: 0.05),
                  splashColor: cs.primary.withValues(alpha: 0.10),
                  highlightColor: cs.primary.withValues(alpha: 0.06),
                  child: AnimatedContainer(
                    duration: t.motionFast,
                    curve: Curves.easeOutCubic,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: selected ? t.accentSoft : Colors.transparent,
                      borderRadius: BorderRadius.circular(t.radiusLg),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Stack(
                          clipBehavior: Clip.none,
                          children: [
                            Icon(
                              selected
                                  ? destination.selectedIcon
                                  : destination.icon,
                              size: 22,
                              color: selected
                                  ? cs.primary
                                  : cs.onSurfaceVariant.withValues(alpha: 0.75),
                            ),
                            if (destination.showBadge)
                              Positioned(
                                right: -2,
                                top: -2,
                                child: Container(
                                  width: 8,
                                  height: 8,
                                  decoration: BoxDecoration(
                                    color: cs.error,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: selected
                                          ? cs.surfaceContainerHigh
                                          : cs.surface,
                                      width: 1.5,
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                        SizedBox(height: t.space4),
                        Text(
                          destination.label,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          textAlign: TextAlign.center,
                          style: tt.labelSmall?.copyWith(
                            fontSize: 11,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? cs.primary
                                : cs.onSurfaceVariant.withValues(alpha: 0.75),
                            letterSpacing: 0.1,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
