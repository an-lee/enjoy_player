/// Shared tile shell for craft language pickers (translate + synthesize).
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

/// Inkable tile surface: tonal container, medium radius, standard padding.
/// The content ([child]) decides the layout axis (column vs row).
class CraftLangTile extends StatelessWidget {
  const CraftLangTile({
    super.key,
    required this.child,
    required this.onTap,
    this.verticalPadding,
  });

  final Widget child;
  final VoidCallback onTap;

  /// Defaults to the compact translate-tool rhythm; the synthesize tool
  /// passes a taller padding.
  final double? verticalPadding;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHighest.withValues(alpha: 0.55),
      borderRadius: BorderRadius.circular(t.radiusMd),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(t.radiusMd),
        child: Padding(
          padding: EdgeInsets.symmetric(
            horizontal: t.space12,
            vertical: verticalPadding ?? t.space8,
          ),
          child: child,
        ),
      ),
    );
  }
}
