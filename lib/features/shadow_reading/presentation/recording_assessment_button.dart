/// Toolbar control: run / view pronunciation assessment for a take.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/hotkeys/presentation/hotkey_tooltip_label.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_target.dart';
import 'package:enjoy_player/features/shadow_reading/application/recording_assessment_controller.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/recording_assessment_flow.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/score_level.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

int? pronunciationScoreFromRecording(RecordingRow row) {
  if (row.pronunciationScore != null) return row.pronunciationScore;
  return _parsePronScoreFromAssessmentJson(row.assessmentJson);
}

int? _parsePronScoreFromAssessmentJson(String? raw) {
  if (raw == null || raw.trim().isEmpty) return null;
  try {
    final m = jsonDecode(raw) as Map<String, dynamic>;
    final nb = m['NBest'] as List<dynamic>?;
    if (nb == null || nb.isEmpty) return null;
    final first = nb.first;
    if (first is! Map<String, dynamic>) return null;
    final pa = first['PronunciationAssessment'];
    if (pa is! Map<String, dynamic>) return null;
    final v = pa['PronScore'];
    if (v is num) return v.round();
    return null;
  } on Object {
    return null;
  }
}

class RecordingAssessmentButton extends ConsumerWidget {
  const RecordingAssessmentButton({
    required this.row,
    required this.echoActive,
    super.key,
  });

  final RecordingRow row;
  final bool echoActive;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = AppLocalizations.of(context)!;
    final scheme = Theme.of(context).colorScheme;
    final lp = row.localPath;
    final learningLanguage = ref
        .watch(appPreferencesCtrlProvider)
        .valueOrNull
        ?.effectiveLearningLanguage;
    // Unknown media language (`und`, common on YouTube) must not disable the
    // button — fall back to the learner's focus language (see catalog helper).
    final assessmentSupported =
        isAzurePronunciationAssessmentSupportedForPractice(
          row.language,
          learningLanguage: learningLanguage,
        );
    final canInteract =
        echoActive && lp != null && lp.isNotEmpty && assessmentSupported;

    final ui = ref.watch(recordingAssessmentControllerProvider(row.id));
    final isAssessing = ui.isRunning;

    final score = pronunciationScoreFromRecording(row);
    final hasStored =
        row.assessmentJson != null && row.assessmentJson!.trim().isNotEmpty;

    final tooltip = !assessmentSupported
        ? l10n.assessmentUnavailableLanguage
        : hotkeyTooltipLabel(
            ref,
            'player.toggleAssessment',
            hasStored ? l10n.assessmentView : l10n.assessmentRun,
          );

    final Color? bg = score != null
        ? assessmentScoreBackground(scheme, assessmentScoreLevel(score))
        : null;
    final Color fg = score != null
        ? assessmentScoreColor(scheme, assessmentScoreLevel(score))
        : scheme.onSurfaceVariant;

    void runAssess() {
      unawaited(
        triggerRecordingAssessment(
          context: context,
          ref: ref,
          l10n: l10n,
          row: row,
        ),
      );
    }

    // Use [MaterialType.transparency] when there is no score fill. A
    // transparent [MaterialType.canvas] (the default) can drop taps on
    // Android even though the same InkWell works on Windows / desktop.
    return OnboardingTarget(
      tipId: OnboardingTipId.playerAssess,
      onTargetAction: canInteract && !isAssessing ? runAssess : null,
      child: Tooltip(
        message: tooltip,
        child: Semantics(
          button: true,
          enabled: canInteract && !isAssessing,
          label: tooltip,
          child: SizedBox(
            width: 44,
            height: 44,
            child: Material(
              color: bg ?? Colors.transparent,
              type: bg == null
                  ? MaterialType.transparency
                  : MaterialType.canvas,
              shape: const CircleBorder(),
              clipBehavior: Clip.antiAlias,
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: !canInteract || isAssessing ? null : runAssess,
                child: Center(
                  child: isAssessing
                      ? LoadingIcon(size: 18, color: scheme.primary)
                      : score != null
                      ? Text(
                          '$score',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(
                                color: fg,
                                fontWeight: FontWeight.w700,
                              ),
                        )
                      : Icon(
                          Icons.auto_awesome_rounded,
                          size: 20,
                          color: canInteract
                              ? scheme.primary
                              : scheme.onSurfaceVariant,
                        ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
