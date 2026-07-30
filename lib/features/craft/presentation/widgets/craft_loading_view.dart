/// Shared loading-state view used by every Craft stage (audio, capture,
/// rewrite).
///
/// Renders a centered `CircularProgressIndicator` with the supplied
/// [message] underneath in the muted `onSurfaceVariant` body style.
/// Each stage passes its own localized string — e.g.
///
/// ```dart
/// CraftLoadingView(message: l10n.craftLoadingSynthesizing)
/// ```
///
/// Previously the same widget lived three times — once in each Craft stage —
/// see [issue #507](https://github.com/baizhiheizi/enjoy_player/issues/507).
library;

import 'package:flutter/material.dart';

class CraftLoadingView extends StatelessWidget {
  const CraftLoadingView({required this.message, super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const CircularProgressIndicator(),
          const SizedBox(height: 16),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}
