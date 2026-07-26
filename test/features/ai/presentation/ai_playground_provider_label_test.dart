import 'package:enjoy_player/features/ai/domain/ai_provider.dart';
import 'package:enjoy_player/features/ai/domain/ai_service_config.dart';
import 'package:enjoy_player/features/ai/domain/llm_api_spec.dart';
import 'package:enjoy_player/features/ai/domain/modality_byok_config.dart';
import 'package:enjoy_player/features/ai/domain/speech_byok_kind.dart';
import 'package:enjoy_player/features/ai/presentation/ai_playground_provider_label.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

Future<AppLocalizations> _loadL10n() =>
    AppLocalizations.delegate.load(const Locale('en'));

void main() {
  test('enjoy provider → "Enjoy AI"', () async {
    final l10n = await _loadL10n();
    final label = formatPlaygroundProviderLabel(
      l10n,
      const AIServiceConfig(provider: AIProvider.enjoy),
    );
    expect(label, 'Enjoy AI');
  });

  test('local provider → "Local (unavailable)"', () async {
    final l10n = await _loadL10n();
    final label = formatPlaygroundProviderLabel(
      l10n,
      const AIServiceConfig(provider: AIProvider.local),
    );
    expect(label, 'Local (unavailable)');
  });

  test('BYOK + known preset id → "BYOK · preset label"', () async {
    final l10n = await _loadL10n();
    final config = const AIServiceConfig(
      provider: AIProvider.byok,
      llmByok: LlmByokConfig(
        apiSpec: LlmApiSpec.openAiCompatible,
        baseUrl: 'https://example.com/v1',
        model: 'gpt-4',
        presetId: 'openai',
      ),
    );
    final label = formatPlaygroundProviderLabel(l10n, config);
    expect(label, startsWith('BYOK · '));
  });

  test('BYOK + llm without preset → "BYOK · model"', () async {
    final l10n = await _loadL10n();
    final config = const AIServiceConfig(
      provider: AIProvider.byok,
      llmByok: LlmByokConfig(
        apiSpec: LlmApiSpec.openAiCompatible,
        baseUrl: 'https://example.com/v1',
        model: 'gpt-4-mini',
        // no presetId
      ),
    );
    final label = formatPlaygroundProviderLabel(l10n, config);
    expect(label, 'BYOK · gpt-4-mini');
  });

  test('BYOK + speech openAiCompatible → "BYOK · OpenAI Whisper"', () async {
    final l10n = await _loadL10n();
    final config = const AIServiceConfig(
      provider: AIProvider.byok,
      speechByok: SpeechByokConfig(
        kind: SpeechByokKind.openAiCompatible,
        baseUrl: 'https://example.com/v1',
        model: 'whisper-1',
      ),
    );
    final label = formatPlaygroundProviderLabel(l10n, config);
    expect(label, 'BYOK · OpenAI Whisper');
  });

  test('BYOK + speech azureSpeech → "BYOK · Azure Speech"', () async {
    final l10n = await _loadL10n();
    final config = const AIServiceConfig(
      provider: AIProvider.byok,
      speechByok: SpeechByokConfig(
        kind: SpeechByokKind.azureSpeech,
        region: 'eastus',
      ),
    );
    final label = formatPlaygroundProviderLabel(l10n, config);
    expect(label, 'BYOK · Azure Speech');
  });

  test('BYOK with no llm/speech sub-config → "Your API key"', () async {
    final l10n = await _loadL10n();
    final config = const AIServiceConfig(provider: AIProvider.byok);
    final label = formatPlaygroundProviderLabel(l10n, config);
    expect(label, 'Your API key');
  });
}
