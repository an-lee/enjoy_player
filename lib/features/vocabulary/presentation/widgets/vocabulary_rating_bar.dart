/// Session-level Don't know / Know / Know well chips.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Three equal-width rating chips using prototype score colors.
class VocabularyRatingBar extends StatelessWidget {
  const VocabularyRatingBar({
    super.key,
    required this.ratingInFlight,
    required this.onRate,
  });

  final bool ratingInFlight;
  final ValueChanged<VocabularyRating> onRate;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final t = EnjoyThemeTokens.of(context);
    final gap = MediaQuery.sizeOf(context).width < 360 ? t.space4 : t.space8;

    return Align(
      alignment: Alignment.center,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: t.contentMaxWidth),
        child: Row(
          children: [
            Expanded(
              child: _RatingChip(
                label: l10n.vocabularyDontKnow,
                icon: Icons.close_rounded,
                background: t.scoreBadContainer,
                foreground: t.scoreBad,
                onPressed: ratingInFlight
                    ? null
                    : () => onRate(VocabularyRating.dontKnow),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _RatingChip(
                label: l10n.vocabularyKnow,
                icon: Icons.check_rounded,
                background: t.scoreWarnContainer,
                foreground: t.scoreWarn,
                onPressed: ratingInFlight
                    ? null
                    : () => onRate(VocabularyRating.know),
              ),
            ),
            SizedBox(width: gap),
            Expanded(
              child: _RatingChip(
                label: l10n.vocabularyKnowWell,
                icon: Icons.check_circle_rounded,
                background: t.scoreGoodContainer,
                foreground: t.scoreGood,
                onPressed: ratingInFlight
                    ? null
                    : () => onRate(VocabularyRating.knowWell),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _RatingChip extends StatelessWidget {
  const _RatingChip({
    required this.label,
    required this.icon,
    required this.background,
    required this.foreground,
    required this.onPressed,
  });

  final String label;
  final IconData icon;
  final Color background;
  final Color foreground;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final enabled = onPressed != null;
    final radius = BorderRadius.circular(t.radiusMd);

    return Semantics(
      button: true,
      enabled: enabled,
      label: label,
      child: Material(
        color: enabled ? background : background.withValues(alpha: 0.35),
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: InkWell(
          onTap: enabled
              ? () {
                  Haptics.selection(context);
                  onPressed!();
                }
              : null,
          borderRadius: radius,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 44),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: t.space8,
                vertical: t.space12,
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 16, color: foreground),
                  SizedBox(width: t.space4),
                  Flexible(
                    child: Text(
                      label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.center,
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: foreground,
                        fontWeight: FontWeight.w600,
                        height: 1.15,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
