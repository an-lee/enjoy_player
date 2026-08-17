/// Shared visual primitives for the subtitle track picker.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'subtitle_track_picker_helpers.dart';

/// Rounded card chrome shared by track lists, display toggles, and actions.
class SubtitlePickerCard extends StatelessWidget {
  const SubtitlePickerCard({
    required this.child,
    this.title,
    this.emphasized = false,
    this.withShadow = false,
    super.key,
  });

  final Widget child;
  final String? title;
  final bool emphasized;
  final bool withShadow;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);

    return DecoratedBox(
      decoration: subtitlePickerCardDecoration(
        context,
        emphasized: emphasized,
        withShadow: withShadow,
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(t.radiusLg),
        child: Material(
          type: MaterialType.transparency,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (title != null)
                Padding(
                  padding: EdgeInsets.fromLTRB(
                    t.space16,
                    t.space12,
                    t.space16,
                    t.space4,
                  ),
                  child: Text(
                    title!,
                    style: subtitlePickerSectionTitleStyle(context),
                  ),
                ),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact switch row matching [TranscriptBusyListTile] density in the picker.
class SubtitleToggleTile extends StatelessWidget {
  const SubtitleToggleTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    super.key,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final enabled = onChanged != null;

    return ListTile(
      contentPadding: EdgeInsets.symmetric(
        horizontal: t.space12,
        vertical: t.space4,
      ),
      leading: Icon(
        icon,
        size: 24,
        color: enabled
            ? cs.onSurfaceVariant
            : cs.onSurface.withValues(alpha: 0.38),
      ),
      title: Text(title),
      subtitle: Text(
        subtitle,
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: enabled
              ? cs.onSurfaceVariant
              : cs.onSurface.withValues(alpha: 0.38),
        ),
      ),
      trailing: Switch.adaptive(value: value, onChanged: onChanged),
      enabled: enabled,
      onTap: enabled ? () => onChanged!(!value) : null,
    );
  }
}

/// Small rounded pill used to show a provider source or language code.
///
/// Sized for dense single-line picker rows; do not reuse as a standalone badge.
class MetaChip extends StatelessWidget {
  const MetaChip({
    super.key,
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
      decoration: BoxDecoration(
        color: background.withValues(alpha: 0.92),
        borderRadius: BorderRadius.circular(t.radiusFull),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: foreground,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.25,
          height: 1.1,
          fontSize: 10.5,
        ),
      ),
    );
  }
}
