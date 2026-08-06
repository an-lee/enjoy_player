/// Enjoy-aligned colors for showcase tooltips.
library;

import 'package:flutter/material.dart';

abstract final class OnboardingTooltipTheme {
  static TextStyle? titleStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme.of(context).textTheme.titleSmall?.copyWith(
      color: cs.onPrimaryContainer,
      fontWeight: FontWeight.w600,
    );
  }

  static TextStyle? descriptionStyle(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Theme.of(context).textTheme.bodyMedium?.copyWith(
      color: cs.onPrimaryContainer,
      height: 1.35,
    );
  }

  static Color tooltipBackground(BuildContext context) =>
      Theme.of(context).colorScheme.primaryContainer;

  static Color overlayColor(BuildContext context) =>
      Colors.black.withValues(alpha: 0.55);
}
