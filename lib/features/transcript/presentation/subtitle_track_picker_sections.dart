/// Collapsible card section and its selected-track summary used by both the
/// primary and translation track lists in the subtitle picker.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_track.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'subtitle_track_picker_helpers.dart';
import 'subtitle_track_picker_primitives.dart';

class CollapsibleTrackSection extends StatelessWidget {
  const CollapsibleTrackSection({
    super.key,
    required this.title,
    required this.isExpanded,
    required this.onToggle,
    required this.selectionLabel,
    this.selectedTrack,
    required this.child,
    this.inlineExpandedList = false,
  });

  final String title;
  final bool isExpanded;
  final VoidCallback onToggle;
  final String selectionLabel;
  final TranscriptTrack? selectedTrack;
  final Widget child;
  final bool inlineExpandedList;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final horizontal = sheetHorizontalPadding(t);

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: horizontal),
      child: DecoratedBox(
        decoration: subtitlePickerCardDecoration(
          context,
          emphasized: isExpanded,
          withShadow: true,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(t.radiusLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Material(
                color: isExpanded
                    ? cs.primaryContainer.withValues(alpha: 0.12)
                    : Colors.transparent,
                child: InkWell(
                  onTap: onToggle,
                  child: Padding(
                    padding: EdgeInsets.fromLTRB(
                      t.space16,
                      t.space12,
                      t.space12,
                      isExpanded ? t.space12 : t.space16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                title,
                                style: subtitlePickerSectionTitleStyle(context),
                              ),
                              if (!isExpanded) ...[
                                SizedBox(height: t.space8),
                                SelectionSummary(
                                  label: selectionLabel,
                                  track: selectedTrack,
                                  compact: true,
                                ),
                              ] else ...[
                                SizedBox(height: t.space4),
                                Text(
                                  selectionLabel,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: tt.bodySmall?.copyWith(
                                    color: cs.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        SizedBox(width: t.space8),
                        AnimatedContainer(
                          duration: t.motionFast,
                          curve: Curves.easeOut,
                          width: 32,
                          height: 32,
                          decoration: BoxDecoration(
                            color: cs.surfaceContainerHighest.withValues(
                              alpha: 0.75,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: cs.outlineVariant.withValues(alpha: 0.2),
                            ),
                          ),
                          child: AnimatedRotation(
                            turns: isExpanded ? 0.5 : 0,
                            duration: t.motionFast,
                            curve: Curves.easeOut,
                            child: Icon(
                              Icons.expand_more_rounded,
                              size: 20,
                              color: cs.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              AnimatedSize(
                duration: t.motionStandard,
                curve: Curves.easeOutCubic,
                alignment: Alignment.topCenter,
                clipBehavior: Clip.hardEdge,
                child: isExpanded
                    ? DecoratedBox(
                        decoration: BoxDecoration(
                          color: cs.surfaceContainerLowest.withValues(
                            alpha: 0.55,
                          ),
                          border: Border(
                            top: BorderSide(
                              color: cs.outlineVariant.withValues(alpha: 0.14),
                            ),
                          ),
                        ),
                        child: Padding(
                          padding: EdgeInsets.only(
                            top: t.space4,
                            bottom: t.space8,
                          ),
                          child: inlineExpandedList
                              ? child
                              : ConstrainedBox(
                                  constraints: const BoxConstraints(
                                    maxHeight: kExpandedTrackListMaxHeight,
                                  ),
                                  child: SingleChildScrollView(child: child),
                                ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class SelectionSummary extends StatelessWidget {
  const SelectionSummary({
    super.key,
    required this.label,
    this.track,
    this.compact = false,
  });

  final String label;
  final TranscriptTrack? track;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final muted = track == null;
    final selected = track;
    final badgeColors = selected == null
        ? null
        : providerBadgeColors(cs, selected.source);

    if (compact && selected != null && badgeColors != null) {
      return Row(
        children: [
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: tt.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
              ),
            ),
          ),
          SizedBox(width: t.space8),
          MetaChip(
            label: providerLabel(l10n, selected.source),
            background: badgeColors.bg,
            foreground: badgeColors.fg,
          ),
          if (selected.language.isNotEmpty && selected.language != 'und') ...[
            SizedBox(width: t.space8),
            MetaChip(
              label: selected.language.toUpperCase(),
              background: cs.surfaceContainerHighest,
              foreground: cs.onSurfaceVariant,
            ),
          ],
        ],
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: (compact ? tt.titleSmall : tt.bodyMedium)?.copyWith(
            color: muted ? cs.onSurfaceVariant : cs.onSurface,
            fontWeight: muted ? FontWeight.w400 : FontWeight.w600,
          ),
        ),
        if (selected != null && badgeColors != null) ...[
          SizedBox(height: t.space8),
          Wrap(
            spacing: t.space8,
            runSpacing: t.space4,
            children: [
              MetaChip(
                label: providerLabel(l10n, selected.source),
                background: badgeColors.bg,
                foreground: badgeColors.fg,
              ),
              if (selected.language.isNotEmpty && selected.language != 'und')
                MetaChip(
                  label: selected.language.toUpperCase(),
                  background: cs.surfaceContainerHighest,
                  foreground: cs.onSurfaceVariant,
                ),
            ],
          ),
        ],
      ],
    );
  }
}
