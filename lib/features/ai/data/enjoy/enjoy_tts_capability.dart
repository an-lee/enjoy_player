import 'package:azure_speech/azure_speech.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/api/services/ai/azure_token_cache.dart';
import 'package:enjoy_player/features/ai/data/azure_language_mapper.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/tts_capability.dart';
import 'package:enjoy_player/features/ai/domain/models/tts_request.dart';
import 'package:enjoy_player/features/ai/domain/models/tts_result.dart';

/// Enjoy TTS: worker-issued Azure token + native Speech SDK synthesis.
///
/// Mirrors [EnjoyAssessmentCapability] — fetches a short-lived token via
/// [AzureTokenCache], then calls [AzureSpeech.instance.synthesize] on the
/// native plugin. The token route keeps credit accounting on the Enjoy side.
final class EnjoyTtsCapability implements TtsCapability {
  EnjoyTtsCapability({required this._tokenCache, AzureSpeech? sdk})
    : _sdk = sdk ?? AzureSpeech.instance;

  final AzureTokenCache _tokenCache;
  final AzureSpeech _sdk;

  @override
  Future<TtsResult> synthesize(TtsRequest request) async {
    final log = logNamed('ai.enjoy.tts');
    final text = request.text.trim();
    if (text.isEmpty) {
      throw const ApiException(
        message: 'TTS input text is empty',
        statusCode: 400,
      );
    }

    final azureLanguage = mapTranscriptLanguageToAzure(request.language);
    if (azureLanguage == null) {
      log.warning(
        'Language "${request.language}" is not supported by Azure Speech mapper',
      );
      throw ApiException(
        message:
            'Speech synthesis is not supported for language '
            '"${request.language}"',
        statusCode: 400,
      );
    }

    // The worker-side cost signal for TTS is the character count of the
    // text to synthesize (mirrors the web `@enjoy/ai` `textLength` field,
    // and the `azureTokenBodySchema` Zod validator on the worker).
    final textLength = text.length;

    log.info(
      'Synthesizing $textLength chars in $azureLanguage'
      '${request.voice != null ? ' voice=${request.voice}' : ''}',
    );

    final token = await _tokenCache.getToken(
      purpose: 'tts',
      textLength: textLength,
    );

    try {
      final outcome = await _sdk.synthesize(
        AzureSpeechSynthesisParams(
          text: text,
          language: azureLanguage,
          token: token.token,
          region: token.region,
          voice: request.voice,
        ),
      );

      log.info(
        'Synthesis succeeded: ${outcome.audioBytes.length} bytes, '
        'format=${outcome.format}, ${outcome.wordBoundaries.length} word boundaries',
      );

      return TtsResult(
        audioBytes: outcome.audioBytes,
        format: outcome.format,
        wordBoundaries: outcome.wordBoundaries
            .map(
              (w) => TtsWordBoundary(
                text: w.text,
                audioOffsetMs: w.audioOffsetMs,
                durationMs: w.durationMs,
              ),
            )
            .toList(),
      );
    } on AzureSpeechException catch (e) {
      log.warning(
        'Azure Speech synthesis failed: ${e.message} (code=${e.code})',
      );
      throw ApiException(message: e.message, statusCode: 502, body: e.code);
    } catch (e, st) {
      log.severe('Unexpected TTS error: $e', e, st);
      rethrow;
    }
  }
}
