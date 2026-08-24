/// A single settings row — icon, title, subtitle, value badge, chevron.
///
/// Generalized from the pre-redesign `_SettingsTile` in `settings_screen.dart`
/// so every extracted section (`sections/*.dart`) and the two-pane detail
/// pane share one row implementation. Behavior-preserving: same layout,
/// same compact/wide breakpoint (320px), same disabled-row styling when
/// [onTap] is null (used for capability-gated rows — FR-007).
///
/// Set [responsive] to `false` when this row is placed inside an
/// [IntrinsicHeight] ancestor — the [LayoutBuilder] would cause layout
/// exceptions with intrinsic sizing. The row will render in its wide
/// (side-by-side) layout unconditionally.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';

class SettingsRow extends StatelessWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.leadingIconTint,
    this.valueBadge,
    this.trailing,
    this.showChevron = true,
    this.onTap,
    this.responsive = true,
  });

  final String title;
  final String? subtitle;
  final Widget? leading;
  final IconData? leadingIcon;
  final Color? leadingIconTint;
  final Widget? valueBadge;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;

  /// When `true` (default), wraps the row in a [LayoutBuilder] that switches
  /// to a stacked layout below 320 px.  Set to `false` when the row is
  /// placed inside an [IntrinsicHeight] ancestor — the [LayoutBuilder] would
  /// cause layout exceptions with intrinsic sizing.
  final bool responsive;

  @override
  Widget build(BuildContext context) {
    if (responsive) {
      return LayoutBuilder(
        builder: (ctx, constraints) =>
            _buildRow(ctx, compact: constraints.maxWidth < 320),
      );
    }
    return _buildRow(context, compact: false);
  }

  Widget _buildRow(BuildContext context, {required bool compact}) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final interactive = onTap != null;
    final iconTint = leadingIconTint ?? cs.primary;

    final Widget? leadWidget;
    if (leading != null) {
      leadWidget = SizedBox(
        width: 44,
        height: 44,
        child: Center(child: leading!),
      );
    } else if (leadingIcon != null) {
      leadWidget = SizedBox(
        width: 44,
        height: 44,
        child: Center(
          child: Icon(
            leadingIcon,
            color: iconTint.withValues(alpha: interactive ? 0.92 : 0.6),
            size: 22,
          ),
        ),
      );
    } else {
      leadWidget = null;
    }

    Widget disclosure() {
      return EnjoyChromeIcon(
        EnjoyChromeGlyph.chevronRight,
        size: 20,
        color: cs.onSurfaceVariant.withValues(alpha: 0.55),
      );
    }

    List<Widget> trailingWidgets() {
      final widgets = <Widget>[];
      if (valueBadge != null) {
        widgets.add(valueBadge!);
      }
      if (trailing != null) {
        widgets.add(trailing!);
      }
      if (showChevron && onTap != null) {
        widgets.add(disclosure());
      }
      return widgets;
    }

    Widget textColumn({required bool compact}) {
      final trailingChildren = trailingWidgets();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          if (!compact)
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: interactive
                          ? null
                          : cs.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
                if (trailingChildren.isNotEmpty)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (var i = 0; i < trailingChildren.length; i++) ...[
                        if (i > 0) SizedBox(width: t.space12),
                        trailingChildren[i],
                      ],
                    ],
                  ),
              ],
            )
          else
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: tt.titleSmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      letterSpacing: -0.2,
                      color: interactive
                          ? null
                          : cs.onSurface.withValues(alpha: 0.78),
                    ),
                  ),
                ),
              ],
            ),
          if (subtitle != null && subtitle!.isNotEmpty) ...[
            SizedBox(height: t.space4),
            Text(
              subtitle!,
              style: tt.bodySmall?.copyWith(
                color: cs.onSurfaceVariant.withValues(alpha: 0.86),
                height: 1.35,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
          ],
          if (compact && trailingChildren.isNotEmpty) ...[
            SizedBox(height: t.space8),
            Wrap(
              spacing: t.space8,
              runSpacing: t.space8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: trailingChildren,
            ),
          ],
        ],
      );
    }

    return Focus(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap == null ? null : Haptics.wrapTap(context, onTap!),
          borderRadius: BorderRadius.circular(t.radiusXl),
          overlayColor: WidgetStateProperty.resolveWith((states) {
            if (states.contains(WidgetState.pressed)) {
              return cs.primary.withValues(alpha: 0.08);
            }
            if (states.contains(WidgetState.hovered) ||
                states.contains(WidgetState.focused)) {
              return cs.onSurface.withValues(alpha: 0.045);
            }
            return null;
          }),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space20,
                vertical: t.space12,
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  if (leadWidget != null) ...[
                    leadWidget,
                    SizedBox(width: t.space16),
                  ],
                  Expanded(child: textColumn(compact: compact)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Thin horizontal divider between two [SettingsRow]s inside the same card.
class SettingsRowDivider extends StatelessWidget {
  const SettingsRowDivider({super.key, this.insetForLeading = true});

  final bool insetForLeading;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    return Divider(
      height: 1,
      indent: insetForLeading ? t.space20 + 44 + t.space16 : t.space20,
      endIndent: t.space20,
      color: cs.outlineVariant.withValues(alpha: 0.18),
    );
  }
}

/// Compact value/state chip shown at the trailing edge of a [SettingsRow]
/// (e.g. the current language, a sync status, an error indicator).
class SettingsValuePill extends StatelessWidget {
  const SettingsValuePill({
    super.key,
    this.icon,
    required this.label,
    this.foregroundColor,
  });

  final IconData? icon;
  final String label;
  final Color? foregroundColor;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final fg = foregroundColor ?? cs.onSurfaceVariant;

    Widget? leading;
    if (icon != null) {
      leading = Icon(icon, size: 16, color: fg);
    } else if (foregroundColor != null) {
      leading = Container(
        width: 6,
        height: 6,
        decoration: BoxDecoration(
          color: foregroundColor,
          shape: BoxShape.circle,
        ),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 148, minHeight: 30),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (leading != null) ...[leading, SizedBox(width: t.space4)],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: leading != null ? TextAlign.start : TextAlign.end,
              style: tt.labelMedium?.copyWith(
                fontWeight: FontWeight.w600,
                color: fg,
                letterSpacing: 0.04,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
