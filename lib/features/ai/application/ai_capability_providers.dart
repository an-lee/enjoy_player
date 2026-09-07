import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/api/byok_secret_store.dart';
import 'package:enjoy_player/data/api/services/ai/ai_api_providers.dart';
import 'package:enjoy_player/features/ai/application/ai_modality_config_controller.dart';
import 'package:enjoy_player/features/ai/application/ai_modality_configs.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_asr_azure_capability.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_asr_openai_capability.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_assessment_azure_capability.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_dictionary_capability.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_llm_capability.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_tts_azure_capability.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_tts_openai_capability.dart';
import 'package:enjoy_player/features/ai/data/byok/byok_translation_capability.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_asr_capability.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_assessment_capability.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_contextual_translation_capability.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_dictionary_capability.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_llm_capability.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_translation_capability.dart';
import 'package:enjoy_player/features/ai/data/enjoy/enjoy_tts_capability.dart';
import 'package:enjoy_player/features/ai/data/stub_ai_capabilities.dart';
import 'package:enjoy_player/features/ai/domain/ai_provider.dart';
import 'package:enjoy_player/features/ai/domain/ai_service_config.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/asr_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/assessment_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/contextual_translation_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/dictionary_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/llm_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/translation_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/tts_capability.dart';
import 'package:enjoy_player/features/ai/domain/speech_byok_kind.dart';

part 'ai_capability_providers.g.dart';

AsrCapability resolveAsrCapability(Ref ref, AIServiceConfig config) {
  switch (config.provider) {
    case AIProvider.enjoy:
      return EnjoyAsrCapability(
        ref.read(asrApiProvider),
        uploadApi: ref.read(asrMediaUploadApiProvider),
      );
    case AIProvider.byok:
      final speechByok = config.speechByok;
      if (speechByok == null) return const ByokNotConfiguredAsrCapability();
      return switch (speechByok.kind) {
        SpeechByokKind.openAiCompatible => ByokAsrOpenAiCapability(
          config: speechByok,
          secrets: ref.read(byokSecretStoreProvider),
        ),
        SpeechByokKind.azureSpeech => ByokAsrAzureCapability(
          config: speechByok,
          secrets: ref.read(byokSecretStoreProvider),
        ),
      };
  }
}

LlmCapability resolveLlmCapability(Ref ref, AIServiceConfig config) {
  switch (config.provider) {
    case AIProvider.enjoy:
      return EnjoyLlmCapability(ref.read(chatApiProvider));
    case AIProvider.byok:
      final llmByok = config.llmByok;
      if (llmByok == null) return const ByokNotConfiguredLlmCapability();
      return ByokLlmCapability(llmByok, ref.read(byokSecretStoreProvider));
  }
}

TranslationCapability resolveTranslationCapability(
  Ref ref,
  AIServiceConfig config,
) {
  switch (config.provider) {
    case AIProvider.enjoy:
      return EnjoyTranslationCapability(ref.read(translationApiProvider));
    case AIProvider.byok:
      return ByokTranslationCapability(resolveLlmCapability(ref, config));
  }
}

DictionaryCapability resolveDictionaryCapability(
  Ref ref,
  AIServiceConfig config,
) {
  switch (config.provider) {
    case AIProvider.enjoy:
      return EnjoyDictionaryCapability(ref.read(dictionaryApiProvider));
    case AIProvider.byok:
      return ByokDictionaryCapability(resolveLlmCapability(ref, config));
  }
}

ContextualTranslationCapability resolveContextualTranslationCapability(
  Ref ref,
  AIServiceConfig config,
) {
  switch (config.provider) {
    case AIProvider.enjoy:
      return EnjoyContextualTranslationCapability(
        ref.read(llmCapabilityProvider),
      );
    case AIProvider.byok:
      return EnjoyContextualTranslationCapability(
        resolveLlmCapability(ref, config),
      );
  }
}

TtsCapability resolveTtsCapability(Ref ref, AIServiceConfig config) {
  switch (config.provider) {
    case AIProvider.enjoy:
      return EnjoyTtsCapability(tokenCache: ref.read(azureTokenCacheProvider));
    case AIProvider.byok:
      final speechByok = config.speechByok;
      if (speechByok == null) return const ByokNotConfiguredTtsCapability();
      return switch (speechByok.kind) {
        SpeechByokKind.openAiCompatible => ByokTtsOpenAiCapability(
          config: speechByok,
          secrets: ref.read(byokSecretStoreProvider),
        ),
        SpeechByokKind.azureSpeech => ByokTtsAzureCapability(
          config: speechByok,
          secrets: ref.read(byokSecretStoreProvider),
        ),
      };
  }
}

AssessmentCapability resolveAssessmentCapability(
  Ref ref,
  AIServiceConfig config,
) {
  switch (config.provider) {
    case AIProvider.enjoy:
      return EnjoyAssessmentCapability(
        tokenCache: ref.read(azureTokenCacheProvider),
      );
    case AIProvider.byok:
      final speechByok = config.speechByok;
      if (speechByok == null) {
        return const ByokNotConfiguredAssessmentCapability();
      }
      return ByokAssessmentAzureCapability(
        config: speechByok,
        secrets: ref.read(byokSecretStoreProvider),
      );
  }
}

@Riverpod(keepAlive: true)
AiModalityConfigs aiModalityConfigs(Ref ref) {
  return ref.watch(aiModalityConfigCtrlProvider);
}

@Riverpod(keepAlive: true)
AsrCapability asrCapability(Ref ref) {
  final c = ref.watch(aiModalityConfigsProvider);
  return resolveAsrCapability(ref, c.asr);
}

@Riverpod(keepAlive: true)
LlmCapability llmCapability(Ref ref) {
  final c = ref.watch(aiModalityConfigsProvider);
  return resolveLlmCapability(ref, c.llm);
}

@Riverpod(keepAlive: true)
TranslationCapability translationCapability(Ref ref) {
  final c = ref.watch(aiModalityConfigsProvider);
  return resolveTranslationCapability(ref, c.translation);
}

@Riverpod(keepAlive: true)
DictionaryCapability dictionaryCapability(Ref ref) {
  final c = ref.watch(aiModalityConfigsProvider);
  return resolveDictionaryCapability(ref, c.dictionary);
}

@Riverpod(keepAlive: true)
ContextualTranslationCapability contextualTranslationCapability(Ref ref) {
  final c = ref.watch(aiModalityConfigsProvider);
  return resolveContextualTranslationCapability(ref, c.llm);
}

@Riverpod(keepAlive: true)
TtsCapability ttsCapability(Ref ref) {
  final c = ref.watch(aiModalityConfigsProvider);
  return resolveTtsCapability(ref, c.tts);
}

@Riverpod(keepAlive: true)
AssessmentCapability assessmentCapability(Ref ref) {
  final c = ref.watch(aiModalityConfigsProvider);
  return resolveAssessmentCapability(ref, c.assessment);
}
