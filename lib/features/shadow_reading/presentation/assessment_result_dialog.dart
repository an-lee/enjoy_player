/// Detailed pronunciation assessment (ported from web `AssessmentResultDialog`).
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_playback_controller.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';
import 'package:enjoy_player/features/pronounce/presentation/pronounce_icon_button.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'score_level.dart';

/// Shows pronunciation assessment: [Dialog] when wide, modal bottom sheet when narrow.
Future<void> showAssessmentResultDialog({
  required BuildContext context,
  required AzurePronunciationAssessmentResult assessment,
  String? localeTag,
}) {
  final l10n = AppLocalizations.of(context)!;
  final nBest = assessment.nBest.isEmpty ? null : assessment.nBest.first;
  if (nBest == null) {
    return showEnjoyAlertDialog<void>(
      context: context,
      title: Text(l10n.assessmentTitle),
      content: Text(l10n.assessmentNoResultSummary),
      actionsBuilder: (ctx) => [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: Text(MaterialLocalizations.of(ctx).okButtonLabel),
        ),
      ],
    );
  }

  final resolvedLocale = localeTag ?? kDefaultLearningLanguageTag;
  final tokens = EnjoyThemeTokens.of(context);
  final wide = MediaQuery.sizeOf(context).width >= tokens.breakpointRail;
  if (wide) {
    return showEnjoyDialog<void>(
      context: context,
      builder: (ctx) => AssessmentResultDialog(
        assessment: assessment,
        localeTag: resolvedLocale,
      ),
    );
  }
  return showEnjoySheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (ctx) => AssessmentResultSheet(
      assessment: assessment,
      localeTag: resolvedLocale,
    ),
  );
}

class AssessmentResultDialog extends ConsumerStatefulWidget {
  const AssessmentResultDialog({
    required this.assessment,
    required this.localeTag,
    super.key,
  });

  final AzurePronunciationAssessmentResult assessment;
  final String localeTag;

  @override
  ConsumerState<AssessmentResultDialog> createState() =>
      _AssessmentResultDialogState();
}

class _AssessmentResultDialogState
    extends ConsumerState<AssessmentResultDialog> {
  AzureWordAssessment? _selected;
  PronouncePlaybackController? _pronounce;

  @override
  void dispose() {
    unawaited(_pronounce?.stop() ?? Future<void>.value());
    super.dispose();
  }

  void _stopPronounce() {
    final ctrl = ref.read(pronouncePlaybackControllerProvider.notifier);
    _pronounce = ctrl;
    unawaited(ctrl.stop());
  }

  @override
  Widget build(BuildContext context) {
    _pronounce ??= ref.read(pronouncePlaybackControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final nBest = widget.assessment.nBest.isEmpty
        ? null
        : widget.assessment.nBest.first;
    if (nBest == null) {
      return AlertDialog(
        title: Text(l10n.assessmentTitle),
        content: Text(l10n.assessmentNoResultSummary),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: Text(MaterialLocalizations.of(context).okButtonLabel),
          ),
        ],
      );
    }

    return Dialog(
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxWidth: 560,
          maxHeight: math.min(640, MediaQuery.sizeOf(context).height * 0.88),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 20, 8, 0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.assessmentTitle, style: tt.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          l10n.assessmentDescription,
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
            ),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 16, 24, 24),
                child: _AssessmentResultInner(
                  nBest: nBest,
                  localeTag: widget.localeTag,
                  layoutCompact: false,
                  selected: _selected,
                  onToggleWord: (w) {
                    _stopPronounce();
                    setState(() {
                      _selected = identical(_selected, w) ? null : w;
                    });
                  },
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class AssessmentResultSheet extends ConsumerStatefulWidget {
  const AssessmentResultSheet({
    required this.assessment,
    required this.localeTag,
    super.key,
  });

  final AzurePronunciationAssessmentResult assessment;
  final String localeTag;

  @override
  ConsumerState<AssessmentResultSheet> createState() =>
      _AssessmentResultSheetState();
}

class _AssessmentResultSheetState extends ConsumerState<AssessmentResultSheet> {
  AzureWordAssessment? _selected;
  PronouncePlaybackController? _pronounce;

  @override
  void dispose() {
    unawaited(_pronounce?.stop() ?? Future<void>.value());
    super.dispose();
  }

  void _stopPronounce() {
    final ctrl = ref.read(pronouncePlaybackControllerProvider.notifier);
    _pronounce = ctrl;
    unawaited(ctrl.stop());
  }

  @override
  Widget build(BuildContext context) {
    _pronounce ??= ref.read(pronouncePlaybackControllerProvider.notifier);
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;
    final t = EnjoyThemeTokens.of(context);
    final nBest = widget.assessment.nBest.first;
    final padH = t.space16 + t.space4;
    final bottomInset = MediaQuery.paddingOf(context).bottom + t.space24;

    // Match dictionary / subtitle pickers: [showEnjoySheet] already passes
    // useSafeArea: true. Wrapping [DraggableScrollableSheet] in another
    // [SafeArea] fights the sheet's height fraction math on notched Android
    // devices and can make the sheet appear to "do nothing".
    return DraggableScrollableSheet(
      initialChildSize: 0.58,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      expand: false,
      builder: (ctx, scrollCtrl) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const PaddedSheetDragHandle(),
            Padding(
              padding: EdgeInsets.fromLTRB(padH, t.space8, 8, 0),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(l10n.assessmentTitle, style: tt.titleLarge),
                        SizedBox(height: t.space4),
                        Text(
                          l10n.assessmentDescription,
                          style: tt.bodySmall?.copyWith(
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    style: IconButton.styleFrom(
                      minimumSize: const Size(48, 48),
                      fixedSize: const Size(48, 48),
                    ),
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close_rounded),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: ListView(
                controller: scrollCtrl,
                physics: const AlwaysScrollableScrollPhysics(),
                padding: EdgeInsets.fromLTRB(
                  padH,
                  t.space16,
                  padH,
                  bottomInset,
                ),
                children: [
                  _AssessmentResultInner(
                    nBest: nBest,
                    localeTag: widget.localeTag,
                    layoutCompact: true,
                    selected: _selected,
                    onToggleWord: (w) {
                      _stopPronounce();
                      setState(() {
                        _selected = identical(_selected, w) ? null : w;
                      });
                    },
                  ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

class _AssessmentResultInner extends StatelessWidget {
  const _AssessmentResultInner({
    required this.nBest,
    required this.localeTag,
    required this.layoutCompact,
    required this.selected,
    required this.onToggleWord,
  });

  final AzureNBestResult nBest;
  final String localeTag;
  final bool layoutCompact;
  final AzureWordAssessment? selected;
  final ValueChanged<AzureWordAssessment> onToggleWord;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final tt = Theme.of(context).textTheme;

    final scores = nBest.pronunciationAssessment;
    final words = nBest.words;

    final overall = scores.pronScore.round();
    final accuracy = scores.accuracyScore.round();
    final completeness = scores.completenessScore.round();
    final fluency = scores.fluencyScore.round();
    final prosody = scores.prosodyScore?.round();

    final scoreBars = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _ScoreBar(
          label: l10n.assessmentAccuracy,
          value: accuracy,
          scheme: scheme,
        ),
        const SizedBox(height: 12),
        _ScoreBar(
          label: l10n.assessmentCompleteness,
          value: completeness,
          scheme: scheme,
        ),
        const SizedBox(height: 12),
        _ScoreBar(
          label: l10n.assessmentFluency,
          value: fluency,
          scheme: scheme,
        ),
        if (prosody != null) ...[
          const SizedBox(height: 12),
          _ScoreBar(
            label: l10n.assessmentProsody,
            value: prosody,
            scheme: scheme,
          ),
        ],
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (layoutCompact) ...[
          Center(
            child: _OverallScoreRing(
              score: overall,
              label: l10n.assessmentOverallScore,
              scheme: scheme,
              tt: tt,
            ),
          ),
          const SizedBox(height: 24),
          scoreBars,
        ] else
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _OverallScoreRing(
                score: overall,
                label: l10n.assessmentOverallScore,
                scheme: scheme,
                tt: tt,
              ),
              const SizedBox(width: 24),
              Expanded(child: scoreBars),
            ],
          ),
        const SizedBox(height: 24),
        Text(l10n.assessmentPronunciationAnalysis, style: tt.titleSmall),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final w in words)
              _WordChip(
                word: w,
                selected: identical(selected, w),
                scheme: scheme,
                onTap: () => onToggleWord(w),
              ),
          ],
        ),
        if (selected != null) ...[
          const SizedBox(height: 16),
          _SelectedWordPanel(
            word: selected!,
            localeTag: localeTag,
            l10n: l10n,
            scheme: scheme,
            tt: tt,
          ),
        ],
      ],
    );
  }
}

class _OverallScoreRing extends StatelessWidget {
  const _OverallScoreRing({
    required this.score,
    required this.label,
    required this.scheme,
    required this.tt,
  });

  final int score;
  final String label;
  final ColorScheme scheme;
  final TextTheme tt;

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
      ],
    );
  }
}

class _ScoreBar extends StatelessWidget {
  const _ScoreBar({
    required this.label,
    required this.value,
    required this.scheme,
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

class _WordChip extends StatelessWidget {
  const _WordChip({
    required this.word,
    required this.selected,
    required this.scheme,
    required this.onTap,
  });

  final AzureWordAssessment word;
  final bool selected;
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

    return Material(
      color: bg ?? scheme.surfaceContainerHighest,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: selected ? (border ?? scheme.primary) : Colors.transparent,
              width: selected ? 2 : 0,
            ),
          ),
          child: Text(
            word.word,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              color: fg,
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

class _SelectedWordPanel extends StatelessWidget {
  const _SelectedWordPanel({
    required this.word,
    required this.localeTag,
    required this.l10n,
    required this.scheme,
    required this.tt,
  });

  final AzureWordAssessment word;
  final String localeTag;
  final AppLocalizations l10n;
  final ColorScheme scheme;
  final TextTheme tt;

  @override
  Widget build(BuildContext context) {
    final pa = word.pronunciationAssessment;
    final err = pa.errorType;
    final acc = pa.accuracyScore;

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
                ),
                if (err != 'None')
                  Text(
                    _errorTypeLabel(l10n, err),
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
                    _errorExplanation(l10n, err),
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

String _errorTypeLabel(AppLocalizations l10n, String errorType) {
  return switch (errorType) {
    'Omission' => l10n.assessmentErrorTypeOmission,
    'Insertion' => l10n.assessmentErrorTypeInsertion,
    'Mispronunciation' => l10n.assessmentErrorTypeMispronunciation,
    'UnexpectedBreak' => l10n.assessmentErrorTypeUnexpectedBreak,
    'MissingBreak' => l10n.assessmentErrorTypeMissingBreak,
    'Monotone' => l10n.assessmentErrorTypeMonotone,
    'None' => l10n.assessmentErrorTypeCorrect,
    _ => errorType,
  };
}

String _errorExplanation(AppLocalizations l10n, String errorType) {
  return switch (errorType) {
    'Omission' => l10n.assessmentErrorExplOmission,
    'Insertion' => l10n.assessmentErrorExplInsertion,
    'Mispronunciation' => l10n.assessmentErrorExplMispronunciation,
    'UnexpectedBreak' => l10n.assessmentErrorExplUnexpectedBreak,
    'MissingBreak' => l10n.assessmentErrorExplMissingBreak,
    'Monotone' => l10n.assessmentErrorExplMonotone,
    'None' => l10n.assessmentErrorExplCorrect,
    _ => l10n.assessmentErrorExplCorrect,
  };
}
