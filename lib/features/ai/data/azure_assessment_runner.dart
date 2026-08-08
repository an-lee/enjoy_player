import 'dart:io';

import 'package:azure_speech/azure_speech.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/utils/text_normalization.dart';
import 'package:enjoy_player/features/ai/data/azure_assessment_staging_path.dart';
import 'package:enjoy_player/features/ai/data/azure_assessment_wav_normalizer.dart';
import 'package:enjoy_player/features/ai/data/azure_language_mapper.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_request.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_result.dart';
import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

final Logger _log = logNamed('ai.azure.assessment');

/// Shared Azure pronunciation assessment pipeline (token or subscription key).
Future<AssessmentResult> runAzurePronunciationAssessment({
  required AssessmentRequest request,
  required AzureSpeech sdk,
  required String region,
  String? token,
  String? subscriptionKey,
}) async {
  assert(
    (token != null && token.isNotEmpty) ^
        (subscriptionKey != null && subscriptionKey.isNotEmpty),
    'Exactly one of token or subscriptionKey must be provided',
  );

  final (wavPath, deleteMaterialized) = await materializeAssessmentWav(request);
  String? normalizedPath;
  try {
    normalizedPath = await tryCreateNormalizedAzureAssessmentWav(wavPath);
    _log.fine(
      normalizedPath == null
          ? 'Azure assessment: using original WAV (normalization unavailable / silent)'
          : 'Azure assessment: using normalized WAV $normalizedPath',
    );

    final azureLanguage = mapTranscriptLanguageToAzure(request.language);
    if (azureLanguage == null) {
      throw StateError(
        'Pronunciation assessment is not supported for language '
        '"${request.language}"',
      );
    }
    final referenceText = cleanAssessmentReferenceText(request.referenceText);

    AzureSpeechAssessmentOutcome outcome = await _assessPath(
      sdk: sdk,
      audioPath: normalizedPath ?? wavPath,
      referenceText: referenceText,
      language: azureLanguage,
      region: region,
      token: token,
      subscriptionKey: subscriptionKey,
      usedNormalizedWav: normalizedPath != null,
      attempt: normalizedPath != null ? 'normalized' : 'original',
    );

    if (normalizedPath != null && looksLikeEmptyAzureAssessment(outcome)) {
      _log.warning(
        'Azure assessment normalized run came back blank; retrying with the '
        'original recording to rule out a bad FFmpeg decode.',
      );
      try {
        final originalOutcome = await _assessPath(
          sdk: sdk,
          audioPath: wavPath,
          referenceText: referenceText,
          language: azureLanguage,
          region: region,
          token: token,
          subscriptionKey: subscriptionKey,
          usedNormalizedWav: false,
          attempt: 'original-fallback',
        );
        if (!looksLikeEmptyAzureAssessment(originalOutcome)) {
          outcome = originalOutcome;
        }
      } on AzureSpeechException catch (e, st) {
        _log.warning(
          'Azure assessment original fallback failed; keeping normalized result',
          e,
          st,
        );
      }
    }

    return AssessmentResult(
      detail: outcome.detail,
      rawJson: Map<String, dynamic>.from(outcome.rawJson),
    );
  } on AzureSpeechException catch (e, st) {
    _log.warning('Azure assessment failed', e, st);
    rethrow;
  } finally {
    if (normalizedPath != null) {
      try {
        await File(normalizedPath).delete();
      } catch (e, st) {
        _log.fine('normalized wav cleanup failed: $normalizedPath', e, st);
      }
    }
    if (deleteMaterialized) {
      try {
        await File(wavPath).delete();
      } catch (e, st) {
        _log.fine('temp wav cleanup failed: $wavPath', e, st);
      }
    }
  }
}

Future<AzureSpeechAssessmentOutcome> _assessPath({
  required AzureSpeech sdk,
  required String audioPath,
  required String referenceText,
  required String language,
  required String region,
  String? token,
  String? subscriptionKey,
  required bool usedNormalizedWav,
  required String attempt,
}) async {
  final (stagedPath, deleteStaged) = await stageWavForAzureAssessment(
    audioPath,
  );
  if (deleteStaged) {
    _log.info(
      'Azure assessment: staging path=$stagedPath '
      '(source had non-ASCII characters)',
    );
  } else {
    _log.info('Azure assessment: staging path=$stagedPath');
  }
  try {
    final params = AzurePronunciationAssessmentParams(
      audioPath: stagedPath,
      referenceText: referenceText,
      language: language,
      region: region,
      token: token,
      subscriptionKey: subscriptionKey,
    );
    final audioBytes = await File(stagedPath).length();
    _log.info(
      'Azure assessment: calling native assess attempt=$attempt '
      'bytes=$audioBytes lang=$language',
    );
    final outcome = await sdk.assess(params);
    _logAzureAssessmentOutcome(
      outcome: outcome,
      audioPath: stagedPath,
      audioBytes: audioBytes,
      usedNormalizedWav: usedNormalizedWav,
      language: language,
      referenceChars: referenceText.length,
      attempt: attempt,
    );
    return outcome;
  } finally {
    if (deleteStaged) {
      try {
        await File(stagedPath).delete();
      } catch (e, st) {
        _log.fine('staged wav cleanup failed: $stagedPath', e, st);
      }
    }
  }
}

String cleanAssessmentReferenceText(String referenceText) {
  return collapseWhitespace(referenceText);
}

/// Returns `(path, shouldDeleteAfter)`.
Future<(String, bool)> materializeAssessmentWav(
  AssessmentRequest request,
) async {
  final pathArg = request.audioPath?.trim();
  if (pathArg != null && pathArg.isNotEmpty) {
    final f = File(pathArg);
    if (await f.exists()) {
      return (f.absolute.path, false);
    }
    throw StateError('Recording file not found: $pathArg');
  }

  final bytes = request.audioBytes;
  if (bytes == null || bytes.isEmpty) {
    throw StateError('No audio bytes and no valid audioPath');
  }

  final out = await newAzureAssessmentStagingWavPath();
  await File(out).writeAsBytes(bytes, flush: true);
  return (out, true);
}

bool looksLikeEmptyAzureAssessment(AzureSpeechAssessmentOutcome outcome) {
  final nb = outcome.detail.nBest.isEmpty ? null : outcome.detail.nBest.first;
  final sc = nb?.pronunciationAssessment;
  if (sc == null) return true;
  final words = nb?.words ?? const <AzureWordAssessment>[];
  final allScoresZero =
      sc.pronScore == 0 &&
      sc.accuracyScore == 0 &&
      sc.fluencyScore == 0 &&
      sc.completenessScore == 0;
  final allWordsOmitted =
      words.isNotEmpty &&
      words.every((w) => w.pronunciationAssessment.errorType == 'Omission');
  final displayLooksEmpty = outcome.detail.displayText.trim() == '.';
  return allScoresZero && (allWordsOmitted || displayLooksEmpty);
}

void _logAzureAssessmentOutcome({
  required AzureSpeechAssessmentOutcome outcome,
  required String audioPath,
  required int audioBytes,
  required bool usedNormalizedWav,
  required String language,
  required int referenceChars,
  required String attempt,
}) {
  final d = outcome.detail;
  final nb = d.nBest.isEmpty ? null : d.nBest.first;
  final sc = nb?.pronunciationAssessment;
  final words = nb?.words ?? const <AzureWordAssessment>[];
  var omissions = 0;
  for (final w in words) {
    if (w.pronunciationAssessment.errorType == 'Omission') omissions++;
  }
  _log.fine(
    'Azure assessment attempt=$attempt audio=${p.basename(audioPath)} '
    'path=$audioPath bytes=$audioBytes normalized=$usedNormalizedWav '
    'language=$language refChars=$referenceChars',
  );
  _log.fine(
    'Azure assessment result status=${d.recognitionStatus} '
    'displayText="${d.displayText}" nBest=${d.nBest.length} '
    'pronScore=${sc?.pronScore} accuracy=${sc?.accuracyScore} '
    'fluency=${sc?.fluencyScore} completeness=${sc?.completenessScore} '
    'words=${words.length} omissions=$omissions',
  );
}

int estimateAssessmentDurationSeconds(AssessmentRequest request) {
  if (request.durationMs != null && request.durationMs! > 0) {
    return (request.durationMs! / 1000).ceil().clamp(1, 300);
  }
  final bytes = request.audioBytes;
  if (bytes != null && bytes.isNotEmpty) {
    return (bytes.length ~/ 32000).clamp(1, 300);
  }
  try {
    final len = File(request.audioPath!.trim()).lengthSync();
    return (len ~/ 32000).clamp(1, 300);
  } catch (_) {
    return 15;
  }
}
