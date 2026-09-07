/// Inline metric widget for the community activity summary row.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

/// Internal building block for `CommunityActivityCard`; not public API.
class InlineMetric extends StatelessWidget {
  const InlineMetric({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    required this.cs,
    required this.tabular,
  });

  final IconData icon;
  final String value;
  final String label;
  final ColorScheme cs;
  final List<FontFeature> tabular;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: cs.primary),
        SizedBox(width: EnjoyThemeTokens.of(context).space4),
        Text(
          value,
          style: Theme.of(context).textTheme.labelLarge?.copyWith(
            fontWeight: FontWeight.w600,
            fontFeatures: tabular,
          ),
        ),
        SizedBox(width: EnjoyThemeTokens.of(context).space4),
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: cs.onSurfaceVariant),
        ),
      ],
    );
  }
}
