import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:http/http.dart' as http;

AppFailure mapApiExceptionToAppFailure(ApiException e) {
  if (e.isUnauthorized) {
    return AuthFailure(e.message, code: AuthFailureCode.sessionRevoked);
  }
  if (e.statusCode == 402) {
    // A 402 from the user's own provider (BYOK) is about the provider's
    // billing, not Enjoy credits — it must never trigger the Enjoy
    // subscription upsell (spec 045 FR-008).
    if (e.byokProvider) {
      return ProviderBillingFailure(e.message);
    }
    return CreditsFailure.fromApiException(e);
  }
  return NetworkFailure(e.message, statusCode: e.statusCode);
}

/// Runs [op] and translates any [ApiException] thrown by the underlying
/// REST client into the user-facing [AppFailure] hierarchy used by the
/// AI presentation layer.
///
/// Centralising the catch means any future cross-cutting change
/// (mapping new `ApiException` subclasses, adding telemetry,
/// propagating context-specific failure codes) happens in one place for
/// every AI capability (`AsrService.transcribe`, `ChatService.complete`,
/// `TranslationService.translate`, `ContextualTranslationService.translate`,
/// `DictionaryService.lookup`, `TtsService.synthesize`, and
/// `AssessmentService.assess`) instead of in N near-identical try/catch
/// blocks.
Future<T> guardAiCall<T>(Future<T> Function() op) async {
  try {
    return await op();
  } on ApiException catch (e) {
    throw mapApiExceptionToAppFailure(e);
  } on http.ClientException catch (e) {
    throw NetworkFailure(e.message);
  }
}
