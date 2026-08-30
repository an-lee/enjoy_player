/// Riverpod controller for one-shot pronunciation assessment per recording row.
library;

import 'dart:convert';
import 'dart:io';

import 'package:azure_speech/azure_speech.dart';
import 'package:meta/meta.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/ai/application/ai_services.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_request.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';

part 'recording_assessment_controller.g.dart';

final _log = logNamed('RecordingAssessment');

/// UI-only phase (spinner while [run] is in flight).
enum RecordingAssessmentPhase { idle, running }

@immutable
class RecordingAssessmentUiState {
  const RecordingAssessmentUiState({required this.phase});

  final RecordingAssessmentPhase phase;

  bool get isRunning => phase == RecordingAssessmentPhase.running;

  static const idle = RecordingAssessmentUiState(
    phase: RecordingAssessmentPhase.idle,
  );

  static const running = RecordingAssessmentUiState(
    phase: RecordingAssessmentPhase.running,
  );
}

sealed class RecordingAssessmentOutcome {}

final class RecordingAssessmentSuccess extends RecordingAssessmentOutcome {
  RecordingAssessmentSuccess(this.detail);

  final AzurePronunciationAssessmentResult detail;
}

enum RecordingAssessmentFailureKind {
  noRecording,
  emptyReference,
  fileTooSmall,
  unsupportedLanguage,

  /// Credits exhausted / billing rejection (worker 402). Carries the
  /// [RecordingAssessmentFailure.creditsFailure] envelope so the flow can
  /// show the numbered message + subscription CTA (spec 045) instead of
  /// leaking the raw status string through `serviceError`.
  credits,
  serviceError,
}

final class RecordingAssessmentFailure extends RecordingAssessmentOutcome {
  RecordingAssessmentFailure(
    this.kind, {
    this.debugMessage,
    this.creditsFailure,
  });

  final RecordingAssessmentFailureKind kind;
  final String? debugMessage;

  /// Set only for [RecordingAssessmentFailureKind.credits].
  final CreditsFailure? creditsFailure;
}

@Riverpod(keepAlive: true)
class RecordingAssessmentController extends _$RecordingAssessmentController {
  @override
  RecordingAssessmentUiState build(String recordingId) =>
      RecordingAssessmentUiState.idle;

  /// Runs pronunciation assessment for [row] when [row.id] matches this
  /// controller's [recordingId].
  Future<RecordingAssessmentOutcome> run(RecordingRow row) async {
    if (row.id != recordingId) {
      _log.fine('run: id mismatch ${row.id} vs $recordingId');
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.serviceError,
        debugMessage: 'id mismatch',
      );
    }

    final path = row.localPath?.trim();
    if (path == null || path.isEmpty) {
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.noRecording,
      );
    }

    if (row.referenceText.trim().isEmpty) {
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.emptyReference,
      );
    }

    final file = File(path);
    if (!await file.exists()) {
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.noRecording,
      );
    }

    final len = await file.length();
    if (len < 100) {
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.fileTooSmall,
      );
    }

    final learningLanguage = ref
        .read(appPreferencesCtrlProvider)
        .valueOrNull
        ?.effectiveLearningLanguage;
    final assessmentLocale = resolveAzureAssessmentLocaleForPractice(
      row.language,
      learningLanguage: learningLanguage,
    );
    if (assessmentLocale == null) {
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.unsupportedLanguage,
      );
    }

    state = RecordingAssessmentUiState.running;
    try {
      final result = await ref
          .read(assessmentServiceProvider)
          .assess(
            AssessmentRequest(
              audioPath: path,
              referenceText: row.referenceText,
              language: assessmentLocale,
              durationMs: row.duration,
            ),
          );

      final ps = result.detail.primaryScores;
      if (ps != null &&
          ps.pronScore == 0 &&
          ps.accuracyScore == 0 &&
          ps.fluencyScore == 0 &&
          ps.completenessScore == 0) {
        _log.warning(
          'RecordingAssessment: stored scores are all zero for recording=${row.id} '
          '(status=${result.detail.recognitionStatus} display="${result.detail.displayText}"). '
          'See ai.enjoy.assessment logs for audio path and Azure fields.',
        );
      }

      final score = switch (ps) {
        null => null,
        final s => s.pronScore.round(),
      };

      final json = jsonEncode(result.rawJson);
      final now = DateTime.now();
      await ref
          .read(appDatabaseProvider)
          .recordingDao
          .updateAssessment(
            id: row.id,
            pronunciationScore: score,
            assessmentJson: json,
            updatedAt: now,
          );

      await ref.read(syncEnqueueProvider)(
        SyncEntityType.recording,
        row.id,
        SyncAction.update,
      );

      return RecordingAssessmentSuccess(result.detail);
    } on CreditsFailure catch (failure, st) {
      _log.warning('Assessment rejected: credits', failure, st);
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.credits,
        creditsFailure: failure,
      );
    } on Object catch (e, st) {
      _log.warning('Assessment failed', e, st);
      return RecordingAssessmentFailure(
        RecordingAssessmentFailureKind.serviceError,
        debugMessage: e.toString(),
      );
    } finally {
      if (ref.mounted) {
        state = RecordingAssessmentUiState.idle;
      }
    }
  }
}
