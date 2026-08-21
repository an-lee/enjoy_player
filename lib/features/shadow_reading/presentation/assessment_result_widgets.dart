/// Stateless presentation widgets used by both the assessment result layouts
/// (the wide [AssessmentResultDialog] and the narrow [AssessmentResultSheet]):
/// [OverallScoreRing], [ScoreBar], [WordChip], [SelectedWordPanel].
/// The shared [_wordColors] helper stays file-private.
library;

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/enjoy_tappable.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/features/shadow_reading/domain/assessment_word_timing.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'assessment_error_messages.dart';
import 'score_level.dart';

class OverallScoreRing extends StatelessWidget {
  const OverallScoreRing({
    required this.score,
    required this.label,
    required this.scheme,
    required this.tt,
    this.trailing,
    super.key,
  });

  final int score;
  final String label;
  final ColorScheme scheme;
  final TextTheme tt;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final level = assessmentScoreLevel(score);
    final tint = assessmentScoreColor(scheme, level);
    return Column(
      children: [
        Text(
          label,
          style: tt.labelMedium?.copyWith(color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: 120,
          height: 120,
          child: Stack(
            alignment: Alignment.center,
            children: [
              SizedBox.expand(
                child: CircularProgressIndicator(
                  value: (score / 100).clamp(0.0, 1.0),
                  strokeWidth: 10,
                  backgroundColor: scheme.surfaceContainerHighest,
                  color: tint,
                ),
              ),
              Text(
                '$score',
                style: tt.headlineLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: tint,
                ),
              ),
            ],
          ),
        ),
        if (trailing != null) ...[const SizedBox(height: 4), trailing!],
      ],
    );
  }
}

class ScoreBar extends StatelessWidget {
  const ScoreBar({
    required this.label,
    required this.value,
    required this.scheme,
    super.key,
  });

  final String label;
  final int value;
  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    final tt = Theme.of(context).textTheme;
    final level = assessmentScoreLevel(value);
    final tint = assessmentScoreColor(scheme, level);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(label, style: tt.labelLarge),
            Text(
              '$value',
              style: tt.labelLarge?.copyWith(
                fontWeight: FontWeight.w600,
                color: tint,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(999),
          child: LinearProgressIndicator(
            value: (value / 100).clamp(0.0, 1.0),
            minHeight: 8,
            backgroundColor: scheme.surfaceContainerHighest,
            color: tint,
          ),
        ),
      ],
    );
  }
}

class WordChip extends StatelessWidget {
  const WordChip({
    required this.word,
    required this.selected,
    required this.karaokeCurrent,
    required this.scheme,
    required this.onTap,
    super.key,
  });

  final AzureWordAssessment word;
  final bool selected;
  final bool karaokeCurrent;
  final ColorScheme scheme;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final pa = word.pronunciationAssessment;
    final score = pa.accuracyScore;
    final err = pa.errorType;
    final (Color fg, Color? bg, Color? border) = _wordColors(
      scheme,
      err,
      score,
    );

    final highlightBorder = karaokeCurrent
        ? scheme.tertiary
        : selected
        ? (border ?? scheme.primary)
        : Colors.transparent;
    final highlightWidth = karaokeCurrent || selected ? 2.0 : 0.0;

    return Material(
      color: karaokeCurrent
          ? scheme.tertiaryContainer.withValues(alpha: 0.55)
          : (bg ?? scheme.surfaceContainerHighest),
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: highlightBorder, width: highlightWidth),
          ),
          child: Text(
            word.word,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: karaokeCurrent ? scheme.onTertiaryContainer : fg,
              decoration: err == 'Insertion'
                  ? TextDecoration.lineThrough
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}

(Color fg, Color? bg, Color? border) _wordColors(
  ColorScheme scheme,
  String errorType,
  double score,
) {
  switch (errorType) {
    case 'Insertion':
      return (scheme.error, scheme.error.withValues(alpha: 0.12), scheme.error);
    case 'Omission':
      return (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest.withValues(alpha: 0.7),
        scheme.outline,
      );
    case 'Mispronunciation':
      return (scheme.error, scheme.error.withValues(alpha: 0.12), scheme.error);
    case 'UnexpectedBreak':
      return (
        scheme.secondary,
        scheme.secondary.withValues(alpha: 0.12),
        scheme.secondary,
      );
    case 'MissingBreak':
      return (
        scheme.onSurfaceVariant,
        scheme.surfaceContainerHighest,
        scheme.outline,
      );
    case 'Monotone':
      return (
        scheme.tertiary,
        scheme.tertiary.withValues(alpha: 0.08),
        scheme.tertiary,
      );
    case 'None':
    default:
      final level = assessmentScoreLevel(score);
      final c = assessmentScoreColor(scheme, level);
      final bg = assessmentScoreBackground(scheme, level);
      return (c, bg, c);
  }
}

class SelectedWordPanel extends StatelessWidget {
  const SelectedWordPanel({
    required this.word,
    required this.localeTag,
    required this.l10n,
    required this.scheme,
    required this.tt,
    required this.recordingPlayable,
    required this.clipPlaying,
    required this.onToggleClip,
    required this.beforeModelPronounce,
    super.key,
  });

  final AzureWordAssessment word;
  final String localeTag;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final TextTheme tt;
  final bool recordingPlayable;
  final bool clipPlaying;
  final VoidCallback onToggleClip;
  final Future<void> Function() beforeModelPronounce;

  @override
  Widget build(BuildContext context) {
    final pa = word.pronunciationAssessment;
    final err = pa.errorType;
    final acc = pa.accuracyScore;
    final clipUsable = recordingPlayable && isWordClipUsable(word);
    final clipTooltip = !recordingPlayable
        ? l10n.assessmentRecordingUnavailable
        : !isWordClipUsable(word)
        ? l10n.assessmentClipUnavailable
        : clipPlaying
        ? l10n.assessmentStopMyClip
        : l10n.assessmentPlayMyClip;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.35),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    word.word,
                    style: tt.titleMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                PronounceIconButton(
                  text: word.word,
                  localeTag: localeTag,
                  surfaceId: PronounceSurfaceId.assessment,
                  compact: true,
                  beforePlay: beforeModelPronounce,
                ),
                EnjoyTappableIcon(
                  tooltip: clipTooltip,
                  semanticLabel: clipTooltip,
                  iconSize: 20,
                  icon: clipPlaying
                      ? Icons.stop_rounded
                      : Icons.record_voice_over_rounded,
                  color: clipUsable
                      ? scheme.onSurfaceVariant
                      : scheme.onSurface.withValues(alpha: 0.38),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(40, 40),
                    fixedSize: const Size(40, 40),
                  ),
                  onPressed: clipUsable ? onToggleClip : null,
                ),
                if (err != 'None')
                  Text(
                    assessmentErrorTypeLabel(l10n, err),
                    style: tt.labelMedium?.copyWith(color: scheme.error),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Text(l10n.assessmentAccuracyScore, style: tt.labelLarge),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const SizedBox.shrink(),
                Text(
                  '${acc.round()}%',
                  style: tt.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: assessmentScoreColor(
                      scheme,
                      assessmentScoreLevel(acc),
                    ),
                  ),
                ),
              ],
            ),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (acc / 100).clamp(0.0, 1.0),
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
                color: assessmentScoreColor(scheme, assessmentScoreLevel(acc)),
              ),
            ),
            if (word.syllables != null && word.syllables!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.assessmentSyllables, style: tt.labelLarge),
              const SizedBox(height: 4),
              Text(
                word.syllables!.map((s) => s.syllable).join(' · '),
                style: tt.bodyMedium?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
            if (word.phonemes != null && word.phonemes!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Text(l10n.assessmentPhonemes, style: tt.labelLarge),
              const SizedBox(height: 4),
              Text(
                '/${word.phonemes!.map((p) => p.phoneme).join('')}/',
                style: tt.bodyMedium?.copyWith(
                  color: scheme.onSurfaceVariant,
                  fontFamily: 'monospace',
                ),
              ),
            ],
            if (err != 'None') ...[
              const SizedBox(height: 12),
              DecoratedBox(
                decoration: BoxDecoration(
                  color: scheme.errorContainer.withValues(alpha: 0.35),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: scheme.error.withValues(alpha: 0.4),
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    assessmentErrorExplanation(l10n, err),
                    style: tt.bodySmall?.copyWith(
                      color: scheme.onErrorContainer,
                    ),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
