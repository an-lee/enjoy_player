import 'package:uuid/uuid.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/services/ai/asr_api.dart';
import 'package:enjoy_player/data/api/services/ai/asr_media_upload_api.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/asr_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_long_form_phase.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_request.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_result.dart';
import 'package:enjoy_player/features/asr/domain/asr_long_form_constants.dart';
import 'package:enjoy_player/features/asr/domain/asr_long_form_job_exception.dart';
import 'package:enjoy_player/features/asr/domain/asr_long_form_mapper.dart';
import 'package:enjoy_player/features/asr/domain/asr_long_form_models.dart';

final _log = logNamed('ai.enjoy.asr');

final class EnjoyAsrCapability implements AsrCapability {
  EnjoyAsrCapability(
    this._api, {
    this.uploadApi,
    Uuid? uuid,
    Duration? pollInitialDelay,
    Duration? pollMaxDelay,
  }) : _uuid = uuid ?? const Uuid(),
       _pollInitialDelay = pollInitialDelay ?? kLongFormPollInitialDelay,
       _pollMaxDelay = pollMaxDelay ?? kLongFormPollMaxDelay;

  final AsrApi _api;
  final AsrMediaUploadApi? uploadApi;
  final Uuid _uuid;
  final Duration _pollInitialDelay;
  final Duration _pollMaxDelay;

  @override
  Future<AsrResult> transcribe(AsrRequest request) async {
    try {
      final language = request.language;
      final baseLanguage = language == null
          ? null
          : workerLanguageBase(language);
      final duration = request.durationSeconds;
      if (duration != null &&
          duration >= kLongFormMinDurationSeconds &&
          uploadApi != null) {
        return await _transcribeLongForm(
          request,
          language: baseLanguage,
          durationSeconds: duration,
        );
      }

      final map = await _api.transcribe(
        audioBytes: request.audioBytes.toList(),
        filename: request.filename,
        model: request.model,
        language: baseLanguage,
        prompt: request.prompt,
        responseFormat: request.responseFormat,
        durationSeconds: request.durationSeconds,
      );
      return AsrResult.fromJson(map);
    } on ApiException {
      rethrow;
    }
  }

  Future<AsrResult> _transcribeLongForm(
    AsrRequest request, {
    required String? language,
    required double durationSeconds,
  }) async {
    final uploadClient = uploadApi!;
    final idempotencyKey = request.idempotencyKey?.trim().isNotEmpty == true
        ? request.idempotencyKey!.trim()
        : _uuid.v4();

    if (request.shouldCancel?.call() ?? false) {
      throw const AsrLongFormJobException(
        category: 'cancelled',
        retryable: false,
        message: 'Cancelled',
      );
    }

    AsrLongFormJob job;
    final resumeJobId = request.existingJobId?.trim();
    if (resumeJobId != null && resumeJobId.isNotEmpty) {
      request.onLongFormPhase?.call(AsrLongFormClientPhase.polling);
      job = await _api.getTranscriptionJob(resumeJobId);
      _log.info(
        'Long-form resume poll id=${job.jobId} status=${job.status.name}',
      );
    } else {
      final existingRef = request.existingMediaReference?.trim();
      late final String mediaReference;
      if (existingRef != null && existingRef.isNotEmpty) {
        mediaReference = existingRef;
      } else {
        request.onLongFormPhase?.call(AsrLongFormClientPhase.uploading);
        final candidateRef = '${_uuid.v4()}.wav';
        final contentType = request.mimeType?.trim().isNotEmpty == true
            ? request.mimeType!.trim()
            : kLongFormDefaultAudioContentType;

        _log.info(
          'Long-form upload start bytes=${request.audioBytes.length} '
          'duration=$durationSeconds ref=$candidateRef',
        );

        final uploaded = await uploadClient.upload(
          mediaReference: candidateRef,
          bytes: request.audioBytes,
          contentType: contentType,
        );
        mediaReference = uploaded.mediaReference;
        request.onLongFormUploaded?.call(mediaReference);
      }

      if (request.shouldCancel?.call() ?? false) {
        throw const AsrLongFormJobException(
          category: 'cancelled',
          retryable: false,
          message: 'Cancelled',
        );
      }

      request.onLongFormPhase?.call(AsrLongFormClientPhase.polling);
      job = await _api.submitLongForm(
        mediaReference: mediaReference,
        durationSeconds: durationSeconds,
        idempotencyKey: idempotencyKey,
        language: language,
      );
      request.onLongFormJobAccepted?.call(job.jobId, mediaReference);
      _log.info(
        'Long-form job accepted id=${job.jobId} status=${job.status.name}',
      );
    }

    var delay = _pollInitialDelay;
    while (!job.status.isTerminal) {
      if (request.shouldCancel?.call() ?? false) {
        throw const AsrLongFormJobException(
          category: 'cancelled',
          retryable: false,
          message: 'Cancelled',
        );
      }
      await Future<void>.delayed(delay);
      if (request.shouldCancel?.call() ?? false) {
        throw const AsrLongFormJobException(
          category: 'cancelled',
          retryable: false,
          message: 'Cancelled',
        );
      }
      job = await _api.getTranscriptionJob(job.jobId);
      if (delay < _pollMaxDelay) {
        final nextMs = (delay.inMilliseconds * 2).clamp(
          _pollInitialDelay.inMilliseconds,
          _pollMaxDelay.inMilliseconds,
        );
        delay = Duration(milliseconds: nextMs);
      }
    }

    if (job.status == AsrLongFormJobStatus.failed) {
      final failure = job.failure;
      throw AsrLongFormJobException(
        category: failure?.category ?? 'provider_failure',
        retryable: failure?.retryable ?? true,
        message: failure?.message,
      );
    }

    final transcript = job.transcript;
    if (transcript == null || transcript.text.trim().isEmpty) {
      throw const AsrLongFormJobException(
        category: 'provider_failure',
        retryable: true,
        message: 'Empty transcript',
      );
    }

    _log.info(
      'Long-form job completed id=${job.jobId} '
      'credits=${job.usage?.creditsCharged}',
    );
    return mapLongFormTranscriptToAsrResult(transcript);
  }
}
