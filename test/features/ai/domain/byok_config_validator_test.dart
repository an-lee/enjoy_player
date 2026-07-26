import 'package:enjoy_player/features/ai/domain/ai_provider.dart';
import 'package:enjoy_player/features/ai/domain/ai_service_config.dart';
import 'package:enjoy_player/features/ai/domain/byok_config_validator.dart';
import 'package:enjoy_player/features/ai/domain/llm_api_spec.dart';
import 'package:enjoy_player/features/ai/domain/modality_byok_config.dart';
import 'package:enjoy_player/features/ai/domain/modality_kind.dart';
import 'package:enjoy_player/features/ai/domain/speech_byok_kind.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validator = ByokConfigValidator();

  group('LLM BYOK', () {
    test('requires api key on first save', () {
      final result = validator.validate(
        modality: ModalityKind.llm,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          llmByok: LlmByokConfig(
            apiSpec: LlmApiSpec.openAiCompatible,
            baseUrl: 'https://api.openai.com/v1',
            model: 'gpt-4o-mini',
          ),
        ),
        hasExistingApiKey: false,
      );

      expect(result.isValid, isFalse);
      expect(result.errors, contains(ByokValidationError.apiKeyRequired));
    });

    test('accepts valid config with key', () {
      final result = validator.validate(
        modality: ModalityKind.llm,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          llmByok: LlmByokConfig(
            apiSpec: LlmApiSpec.openAiCompatible,
            baseUrl: 'https://api.deepseek.com/v1',
            model: 'deepseek-chat',
          ),
        ),
        hasExistingApiKey: false,
        apiKey: 'sk-test',
      );

      expect(result.isValid, isTrue);
    });

    test('rejects private base URL', () {
      final result = validator.validate(
        modality: ModalityKind.llm,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          llmByok: LlmByokConfig(
            apiSpec: LlmApiSpec.openAiCompatible,
            baseUrl: 'https://192.168.1.5/v1',
            model: 'gpt-4o-mini',
          ),
        ),
        hasExistingApiKey: true,
      );

      expect(result.errors, contains(ByokValidationError.baseUrlInvalid));
    });
  });

  group('LLM missing fields', () {
    test('apiSpecRequired when llmByok is null', () {
      final result = validator.validate(
        modality: ModalityKind.llm,
        config: const AIServiceConfig(provider: AIProvider.byok),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.apiSpecRequired));
    });

    test('baseUrlRequired when baseUrl is empty', () {
      final result = validator.validate(
        modality: ModalityKind.llm,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          llmByok: LlmByokConfig(
            apiSpec: LlmApiSpec.openAiCompatible,
            baseUrl: '  ',
            model: 'gpt-4o-mini',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.baseUrlRequired));
    });

    test('modelRequired when model is empty', () {
      final result = validator.validate(
        modality: ModalityKind.llm,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          llmByok: LlmByokConfig(
            apiSpec: LlmApiSpec.openAiCompatible,
            baseUrl: 'https://api.openai.com/v1',
            model: '',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.modelRequired));
    });
  });

  group('Speech BYOK (ASR / TTS)', () {
    test('apiSpecRequired when speechByok is null', () {
      final result = validator.validate(
        modality: ModalityKind.asr,
        config: const AIServiceConfig(provider: AIProvider.byok),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.apiSpecRequired));
    });

    test('openAiCompatible: baseUrlRequired when empty', () {
      final result = validator.validate(
        modality: ModalityKind.tts,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(
            kind: SpeechByokKind.openAiCompatible,
            baseUrl: '',
            model: 'tts-1',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.baseUrlRequired));
    });

    test('openAiCompatible: baseUrlInvalid for private IP', () {
      final result = validator.validate(
        modality: ModalityKind.asr,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(
            kind: SpeechByokKind.openAiCompatible,
            baseUrl: 'https://10.0.0.1/v1',
            model: 'whisper-1',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.baseUrlInvalid));
    });

    test('openAiCompatible: modelRequired when model empty', () {
      final result = validator.validate(
        modality: ModalityKind.tts,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(
            kind: SpeechByokKind.openAiCompatible,
            baseUrl: 'https://api.openai.com/v1',
            model: '',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.modelRequired));
    });

    test('azureSpeech: regionRequired when region empty', () {
      final result = validator.validate(
        modality: ModalityKind.asr,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(
            kind: SpeechByokKind.azureSpeech,
            region: '',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.regionRequired));
    });

    test('azureSpeech: valid config passes', () {
      final result = validator.validate(
        modality: ModalityKind.tts,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(
            kind: SpeechByokKind.azureSpeech,
            region: 'westus2',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.isValid, isTrue);
    });
  });

  group('Assessment BYOK', () {
    test('requires Azure kind and region', () {
      final result = validator.validate(
        modality: ModalityKind.assessment,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(kind: SpeechByokKind.openAiCompatible),
        ),
        hasExistingApiKey: true,
      );

      expect(result.errors, contains(ByokValidationError.azureKindRequired));
    });

    test('regionRequired when azure region is empty', () {
      final result = validator.validate(
        modality: ModalityKind.assessment,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(
            kind: SpeechByokKind.azureSpeech,
            region: '  ',
          ),
        ),
        hasExistingApiKey: true,
      );
      expect(result.errors, contains(ByokValidationError.regionRequired));
    });

    test('accepts Azure assessment config', () {
      final result = validator.validate(
        modality: ModalityKind.assessment,
        config: const AIServiceConfig(
          provider: AIProvider.byok,
          speechByok: SpeechByokConfig(
            kind: SpeechByokKind.azureSpeech,
            region: 'eastus',
          ),
        ),
        hasExistingApiKey: true,
      );

      expect(result.isValid, isTrue);
    });
  });

  test('non-byok provider always valid', () {
    final result = validator.validate(
      modality: ModalityKind.llm,
      config: const AIServiceConfig(provider: AIProvider.enjoy),
      hasExistingApiKey: false,
    );
    expect(result.isValid, isTrue);
  });
}
