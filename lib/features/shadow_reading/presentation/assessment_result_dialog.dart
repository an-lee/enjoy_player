/// Entry point for the assessment result presentation.
///
/// Picks between a wide [AssessmentResultDialog] and a narrow modal
/// [AssessmentResultSheet] based on the current [MediaQuery] width, then
/// forwards to the matching layout. The shared body widget
/// (`AssessmentResultBody`), the stateless subwidgets, and the error-message
/// helpers live in sibling files in this directory.
///
/// Ported from the web `AssessmentResultDialog`.
library;

import 'dart:math' as math;

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_modal.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import 'assessment_result_body.dart';
import 'assessment_result_sheet.dart';

/// Shows pronunciation assessment: [Dialog] when wide, modal bottom sheet when narrow.
///
/// Uses Enjoy modals (root navigator by default) so the result clears the
/// permanent player surface host on YouTube (ADR-0065).
///
/// Pass [recordingPath] (typically [RecordingRow.localPath]) to enable take
/// replay, karaoke highlight, and per-word clips.
Future<void> showAssessmentResultDialog({
  required BuildContext context,
  required AzurePronunciationAssessmentResult assessment,
  String? localeTag,
  String? recordingPath,
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
        recordingPath: recordingPath,
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
      recordingPath: recordingPath,
    ),
  );
}

class AssessmentResultDialog extends ConsumerStatefulWidget {
  const AssessmentResultDialog({
    required this.assessment,
    required this.localeTag,
    this.recordingPath,
    super.key,
  });

  final AzurePronunciationAssessmentResult assessment;
  final String localeTag;
  final String? recordingPath;

  @override
  ConsumerState<AssessmentResultDialog> createState() =>
      _AssessmentResultDialogState();
}

class _AssessmentResultDialogState
    extends ConsumerState<AssessmentResultDialog> {
  @override
  Widget build(BuildContext context) {
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
                child: AssessmentResultBody(
                  nBest: nBest,
                  localeTag: widget.localeTag,
                  recordingPath: widget.recordingPath,
                  layoutCompact: false,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
