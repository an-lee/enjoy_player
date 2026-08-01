/// A Settings section that renders its child with optional card wrapping.
///
/// Formerly supported expand/collapse via a section header toggle; the
/// header has been removed and the child is always visible.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';

class SettingsCollapsibleSection extends StatelessWidget {
  const SettingsCollapsibleSection({
    super.key,
    required this.title,
    required this.hint,
    required this.icon,
    required this.collapsed,
    required this.onToggle,
    required this.child,
    this.needsAttention = false,
    this.wrapInCard = true,
  });

  final String title;
  final String hint;
  final IconData icon;
  final bool collapsed;
  final VoidCallback onToggle;
  final Widget child;

  /// Shows a small badge in the header when [collapsed] is true so an
  /// error/warning inside isn't silently hidden (spec edge case).
  final bool needsAttention;

  /// Set to `false` when [child] already renders its own bordered surface
  /// (e.g. [AboutSectionCard]) to avoid a card-inside-a-card look.
  final bool wrapInCard;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);

    // Horizontal inset comes from the Settings hub page metrics — same as
    // [SettingsSectionCard] / Profile. Avoid a second mobile gutter.
    return wrapInCard
        ? EnjoyCard(padding: EdgeInsets.all(t.space16), child: child)
        : child;
  }
}
