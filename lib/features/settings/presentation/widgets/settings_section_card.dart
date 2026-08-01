/// A Settings section card wrapping child rows in an [EnjoyCard].
///
/// Formerly included a section header (icon/title/hint) above the card;
/// the header has been removed to keep the UI clean.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';

class SettingsSectionCard extends StatelessWidget {
  const SettingsSectionCard({
    super.key,
    required this.title,
    required this.hint,
    required this.icon,
    required this.child,
    this.padding,
    this.headerTrailing,
  });

  final String title;
  final String hint;
  final IconData icon;
  final Widget child;
  final EdgeInsetsGeometry? padding;

  /// Optional control shown at the trailing edge of the header row.
  final Widget? headerTrailing;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);

    // Horizontal inset comes from the Settings hub page metrics
    // ([EnjoyPageKind.hub]) — matching Profile. Do not add a second gutter
    // here or mobile cards sit farther inward than Profile.
    return EnjoyCard(
      padding: padding ?? EdgeInsets.all(t.space16),
      child: child,
    );
  }
}
