/// Shared assessment trigger (toolbar button, hotkey, take menu).
library;

import 'dart:convert';

import 'package:azure_speech/azure_speech.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/notices/app_notice.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/core/utils/text_normalization.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/shadow_reading/application/recording_assessment_controller.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/assessment_result_dialog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

final _log = logNamed('RecordingAssessment');

String recordingAssessmentFailureMessage(
  AppLocalizations l10n,
  RecordingAssessmentFailureKind kind, {
  String? debugMessage,
}) {
  return switch (kind) {
    RecordingAssessmentFailureKind.noRecording => l10n.assessmentNoRecording,
    RecordingAssessmentFailureKind.emptyReference =>
      l10n.assessmentEmptyReference,
    RecordingAssessmentFailureKind.fileTooSmall => l10n.assessmentNoRecording,
    RecordingAssessmentFailureKind.unsupportedLanguage =>
      l10n.assessmentUnavailableLanguage,
    RecordingAssessmentFailureKind.serviceError => l10n.assessmentRunFailed(() {
      final raw = debugMessage == null
          ? null
          : collapseWhitespace(debugMessage);
      if (raw == null || raw.isEmpty) return '—';
      if (raw.length > 120) return '${raw.substring(0, 117)}…';
      return raw;
    }()),
  };
}

/// Locale used for model pronounce on assessment results — same resolution as
/// the Azure assessment run (`und`/empty → learning language fallback).
String? _pronounceLocaleForAssessment(WidgetRef ref, RecordingRow row) {
  final learningLanguage = ref
      .read(appPreferencesCtrlProvider)
      .valueOrNull
      ?.effectiveLearningLanguage;
  return resolveAzureAssessmentLocaleForPractice(
    row.language,
    learningLanguage: learningLanguage,
  );
}

/// Opens stored results, or runs assessment when [forceRun] is true or there is
/// no stored JSON yet.
Future<void> triggerRecordingAssessment({
  required BuildContext context,
  required WidgetRef ref,
  required AppLocalizations l10n,
  required RecordingRow row,
  bool forceRun = false,
}) async {
  _log.info(
    'trigger assessment recording=${row.id} forceRun=$forceRun '
    'hasStored=${row.assessmentJson?.trim().isNotEmpty == true} '
    'lang=${row.language} path=${row.localPath}',
  );
  final pronounceLocale = _pronounceLocaleForAssessment(ref, row);
  if (!forceRun) {
    final stored = row.assessmentJson?.trim();
    if (stored != null && stored.isNotEmpty) {
      try {
        final parsed = AzurePronunciationAssessmentResult.fromJson(
          jsonDecode(stored) as Map<String, dynamic>,
        );
        if (!context.mounted) return;
        await showAssessmentResultDialog(
          context: context,
          assessment: parsed,
          localeTag: pronounceLocale,
          recordingPath: row.localPath,
        );
      } on Object {
        if (!context.mounted) return;
        AppNotice.error(context, l10n.assessmentInvalidStored);
      }
      return;
    }
  }

  final notifier = ref.read(
    recordingAssessmentControllerProvider(row.id).notifier,
  );
  final outcome = await notifier.run(row);
  if (!context.mounted) return;

  switch (outcome) {
    case RecordingAssessmentSuccess(:final detail):
      await showAssessmentResultDialog(
        context: context,
        assessment: detail,
        localeTag: pronounceLocale,
        recordingPath: row.localPath,
      );
    case RecordingAssessmentFailure(:final kind, :final debugMessage):
      AppNotice.error(
        context,
        recordingAssessmentFailureMessage(
          l10n,
          kind,
          debugMessage: debugMessage,
        ),
      );
  }
}
