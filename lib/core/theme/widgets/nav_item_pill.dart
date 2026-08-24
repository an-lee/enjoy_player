/// Pill-shaped nav item: icon + label inside a focus-ringable, hover-able,
/// selected-tinted container.
///
/// Shared by [AppSidebar]'s desktop nav row and the Settings two-pane rail —
/// both features render the same "selected nav item" treatment (pill
/// highlight + focus ring), so they share this primitive instead of
/// re-implementing the [Material] / [InkWell] / [AnimatedContainer] stack.
///
/// Per [ADR-0018] "Shared interactive primitives" — prefer this over ad-hoc
/// `InkWell` + `GestureDetector` islands for new rail-style surfaces.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

class NavItemPill extends StatelessWidget {
  const NavItemPill({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.selectedIcon,
    this.iconWidget,
    this.selectedIconWidget,
    this.iconSize = 20,
    this.maxLines,
    this.overflow,
  });

  final IconData icon;

  /// When [selected] is true, the icon shown for the active item. Falls back
  /// to [icon] when null. The sidebar uses a heavier outline/filled pair;
  /// the Settings rail reuses a single icon.
  final IconData? selectedIcon;

  /// Optional chrome widget; when set, replaces the [Icon] for this state.
  final Widget? iconWidget;
  final Widget? selectedIconWidget;

  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Side-effect pixel size for the leading [Icon]. The sidebar uses 22 to
  /// match the primary nav; the Settings rail uses 20.
  final double iconSize;

  /// Forwarded to the label [Text]. The Settings rail clips long section
  /// titles with ellipsis; the sidebar lets the title wrap.
  final int? maxLines;
  final TextOverflow? overflow;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: t.space8, vertical: 2),
      child: Focus(
        child: Builder(
          builder: (focusContext) {
            final focused = Focus.of(focusContext).hasFocus;
            return Material(
              color: Colors.transparent,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(t.radiusFull),
                side: focused && !selected
                    ? BorderSide(
                        color: cs.primary.withValues(alpha: 0.55),
                        width: t.focusRingWidth,
                      )
                    : BorderSide.none,
              ),
              child: InkWell(
                onTap: () {
                  Haptics.selection(context);
                  onTap();
                },
                borderRadius: BorderRadius.circular(t.radiusFull),
                hoverColor: cs.onSurface.withValues(alpha: 0.06),
                splashColor: cs.primary.withValues(alpha: 0.10),
                highlightColor: cs.primary.withValues(alpha: 0.05),
                child: AnimatedContainer(
                  duration: t.motionFast,
                  curve: Curves.easeOutCubic,
                  padding: EdgeInsets.symmetric(
                    horizontal: t.space16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: selected ? cs.surfaceContainer : Colors.transparent,
                    borderRadius: BorderRadius.circular(t.radiusMd),
                    border: selected
                        ? Border(left: BorderSide(color: t.accentInk, width: 3))
                        : null,
                  ),
                  child: Row(
                    children: [
                      IconTheme(
                        data: IconThemeData(
                          size: iconSize,
                          color: selected ? t.accentInk : cs.onSurfaceVariant,
                        ),
                        child: selected
                            ? (selectedIconWidget ??
                                  iconWidget ??
                                  Icon(selectedIcon ?? icon, size: iconSize))
                            : (iconWidget ?? Icon(icon, size: iconSize)),
                      ),
                      SizedBox(width: t.space12),
                      Expanded(
                        child: Text(
                          label,
                          maxLines: maxLines,
                          overflow: overflow,
                          style: tt.labelLarge?.copyWith(
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.w500,
                            color: selected
                                ? cs.onSurface
                                : cs.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
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
