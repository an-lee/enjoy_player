/// Editorial pill [SegmentedButton] styling shared across Library chrome.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

/// Shared Material 3 segment styling for Library source and kind controls.
ButtonStyle enjoySegmentedButtonStyle(BuildContext context) {
  final t = EnjoyThemeTokens.of(context);
  final cs = Theme.of(context).colorScheme;
  final tt = Theme.of(context).textTheme;

  return SegmentedButton.styleFrom(
    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
    visualDensity: VisualDensity.compact,
    backgroundColor: cs.surfaceContainer,
    foregroundColor: cs.onSurfaceVariant,
    selectedForegroundColor: cs.onSurface,
    selectedBackgroundColor: cs.surface,
    side: BorderSide(color: cs.outlineVariant),
    splashFactory: NoSplash.splashFactory,
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(t.radiusFull),
    ),
    textStyle: tt.labelMedium?.copyWith(fontWeight: FontWeight.w600),
  );
}
