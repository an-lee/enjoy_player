/// In-memory state for a single ASR generation pass.
///
/// Lives in [AsrGenerationController] only — never persisted. UI binds
/// to `AsyncValue<AsrGenerationJob?>` via Riverpod.
library;

import 'package:enjoy_player/core/errors/app_failure.dart';

enum AsrGenerationPhase {
  /// No job has been started for this `mediaId` (or the last result was cleared).
  idle,

  /// FFmpeg is extracting audio from a video source.
  extracting,

  /// Uploading recognition audio to Worker storage (Enjoy long-form).
  uploading,

  /// `AsrService.transcribe` is running (short-clip sync recognition).
  recognizing,

  /// Polling Enjoy long-form job status.
  polling,

  /// The resulting `TranscriptLine[]` is being upserted to Drift.
  persisting,

  /// Row written and primary updated. Terminal.
  success,

  /// Something failed (mapped to a friendly ARB key). Terminal.
  error,

  /// The user explicitly cancelled, or a newer job superseded this one.
  /// Terminal — the resulting row was **not** persisted.
  cancelled,
}

class AsrGenerationJob {
  const AsrGenerationJob({
    required this.mediaId,
    required this.language,
    required this.phase,
    this.detectedLanguage,
    this.progress,
    this.errorMessage,
    this.creditsFailure,
    this.startedAt,
    this.completedAt,
    this.trackId,
    this.creditsCharged,
  });

  final String mediaId;

  /// BCP47 base tag the user chose (or the media row's stored language
  /// when not specified).
  final String language;

  /// Updated as the controller advances; null when [phase] is `idle` /
  /// `success` / `cancelled`.
  final AsrGenerationPhase phase;

  /// Populated after recognition completes (Enjoy path only).
  final String? detectedLanguage;

  /// Best-effort 0..1; null when not applicable.
  final double? progress;

  /// Localized, friendly error text — never a raw exception message.
  /// (SC-007 / FR-017.)
  final String? errorMessage;

  /// The credits rejection when [errorMessage] is a credits key, carried so
  /// the launcher can show the numbered message and the subscription CTA
  /// (spec 045). Null for every other failure.
  final CreditsFailure? creditsFailure;

  final DateTime? startedAt;
  final DateTime? completedAt;

  /// Resulting `enjoyTranscriptId` after the persist step. Used by the UI
  /// to confirm the new row is the active primary.
  final String? trackId;

  /// Credits charged for a completed Enjoy long-form job, when reported.
  final int? creditsCharged;

  AsrGenerationJob copyWith({
    AsrGenerationPhase? phase,
    String? detectedLanguage,
    double? progress,
    String? errorMessage,
    CreditsFailure? creditsFailure,
    DateTime? startedAt,
    DateTime? completedAt,
    String? trackId,
    int? creditsCharged,
  }) {
    return AsrGenerationJob(
      mediaId: mediaId,
      language: language,
      phase: phase ?? this.phase,
      detectedLanguage: detectedLanguage ?? this.detectedLanguage,
      progress: progress ?? this.progress,
      errorMessage: errorMessage ?? this.errorMessage,
      creditsFailure: creditsFailure ?? this.creditsFailure,
      startedAt: startedAt ?? this.startedAt,
      completedAt: completedAt ?? this.completedAt,
      trackId: trackId ?? this.trackId,
      creditsCharged: creditsCharged ?? this.creditsCharged,
    );
  }
}
