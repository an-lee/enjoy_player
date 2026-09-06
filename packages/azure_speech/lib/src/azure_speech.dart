import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';

import 'azure_speech_assessment_outcome.dart';
import 'azure_speech_exception.dart';
import 'azure_speech_params.dart';
import 'azure_speech_synthesis_outcome.dart';
import 'azure_speech_synthesis_params.dart';
import 'azure_speech_transcription_outcome.dart';
import 'azure_speech_transcription_params.dart';
import 'models.dart';

/// Entry point for Azure Speech operations from Dart.
///
/// Single implementation holding the platform [MethodChannel] — the former
/// `AzureSpeechPlatform` interface + facade double layer collapsed into this
/// class (one implementation existed; the interface was never reassigned).
final class AzureSpeech {
  AzureSpeech._({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('azure_speech');

  static final AzureSpeech instance = AzureSpeech._();

  final MethodChannel _channel;

  /// One-shot pronunciation assessment from a WAV file (token or subscription key).
  Future<AzureSpeechAssessmentOutcome> assess(
    AzurePronunciationAssessmentParams params,
  ) => _guard(() async {
    final raw = await _channel.invokeMethod<String>('assess', params.toMap());
    if (raw == null || raw.isEmpty) {
      throw const AzureSpeechException(
        code: 'empty_result',
        message: 'Native layer returned no JSON.',
      );
    }
    final decoded = jsonDecode(raw);
    if (decoded is! Map) {
      throw AzureSpeechException(
        code: 'parse_error',
        message: 'Assessment JSON root was not an object.',
        details: raw,
      );
    }
    final root = Map<String, dynamic>.from(decoded);
    final detail = AzurePronunciationAssessmentResult.fromJson(root);
    return AzureSpeechAssessmentOutcome(detail: detail, rawJson: root);
  });

  /// One-shot speech recognition from a WAV file (subscription key).
  Future<AzureSpeechTranscriptionOutcome> transcribe(
    AzureSpeechTranscriptionParams params,
  ) => _guard(() async {
    final raw = await _channel.invokeMethod<String>(
      'transcribe',
      params.toMap(),
    );
    if (raw == null) {
      throw const AzureSpeechException(
        code: 'empty_result',
        message: 'Native layer returned no transcription text.',
      );
    }
    return AzureSpeechTranscriptionOutcome(text: raw);
  });

  /// Text-to-speech synthesis (subscription key); returns WAV bytes.
  Future<AzureSpeechSynthesisOutcome> synthesize(
    AzureSpeechSynthesisParams params,
  ) => _guard(() async {
    final raw = await _channel.invokeMethod<String>(
      'synthesize',
      params.toMap(),
    );
    if (raw == null || raw.isEmpty) {
      throw const AzureSpeechException(
        code: 'empty_result',
        message: 'Native layer returned no synthesis audio.',
      );
    }

    // The native side returns a JSON object with audio (base64) and
    // optionally wordBoundaries array. For backwards compatibility,
    // a plain base64 string (no JSON) is treated as audio-only.
    if (raw.startsWith('{')) {
      final decoded = jsonDecode(raw) as Map<String, dynamic>;
      final audioB64 = decoded['audio'] as String? ?? '';
      if (audioB64.isEmpty) {
        throw const AzureSpeechException(
          code: 'empty_result',
          message: 'Native layer returned no synthesis audio.',
        );
      }
      final bytes = base64Decode(audioB64);
      final wbList = decoded['wordBoundaries'] as List? ?? [];
      final wordBoundaries = wbList.map((w) {
        final m = w as Map<String, dynamic>;
        // Native side sends ticks (100ns units); convert to ms.
        final audioOffsetTicks = (m['audioOffset'] as num?)?.toInt() ?? 0;
        final durationTicks = (m['duration'] as num?)?.toInt() ?? 0;
        return AzureWordBoundary(
          text: m['text'] as String? ?? '',
          audioOffsetMs: (audioOffsetTicks / 10000).round(),
          durationMs: (durationTicks / 10000).round(),
        );
      }).toList();
      return AzureSpeechSynthesisOutcome(
        audioBytes: Uint8List.fromList(bytes),
        wordBoundaries: wordBoundaries,
      );
    }

    // Legacy: plain base64 string.
    final bytes = base64Decode(raw);
    return AzureSpeechSynthesisOutcome(audioBytes: Uint8List.fromList(bytes));
  });

  /// Maps platform errors onto [AzureSpeechException] with the original
  /// stack trace preserved.
  static Future<T> _guard<T>(Future<T> Function() body) async {
    try {
      return await body();
    } on PlatformException catch (e, st) {
      Error.throwWithStackTrace(
        AzureSpeechException(
          code: e.code,
          message: e.message ?? e.code,
          details: e.details,
        ),
        st,
      );
    } on FormatException catch (e, st) {
      Error.throwWithStackTrace(
        AzureSpeechException(code: 'parse_error', message: e.message),
        st,
      );
    }
  }
}
