import 'package:enjoy_player/features/ai/domain/ai_provider.dart';
import 'package:enjoy_player/features/ai/domain/ai_service_config.dart';
import 'package:enjoy_player/features/ai/domain/speech_byok_kind.dart';
import 'package:enjoy_player/features/ai/presentation/settings/llm_presets.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// User-visible label for the active AI provider on the playground (Enjoy vs BYOK detail).
String formatPlaygroundProviderLabel(
  AppLocalizations l10n,
  AIServiceConfig config,
) {
  return switch (config.provider) {
    AIProvider.enjoy => l10n.settingsAiProvidersEnjoyAi,
    AIProvider.byok => _byokLabel(l10n, config),
  };
}

String _byokLabel(AppLocalizations l10n, AIServiceConfig config) {
  final llm = config.llmByok;
  if (llm != null) {
    final preset = presetById(llm.presetId);
    if (preset != null) {
      return l10n.aiPlaygroundProviderByokDetail(preset.label);
    }
    return l10n.aiPlaygroundProviderByokDetail(llm.model);
  }

  final speech = config.speechByok;
  if (speech != null) {
    final kindLabel = speech.kind == SpeechByokKind.openAiCompatible
        ? l10n.settingsAiProvidersSpeechKindOpenAi
        : l10n.settingsAiProvidersSpeechKindAzure;
    return l10n.aiPlaygroundProviderByokDetail(kindLabel);
  }

  return l10n.settingsAiProvidersByok;
}
