import 'package:enjoy_player/features/ai/domain/byok_not_configured_failure.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/asr_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/assessment_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/llm_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/tts_capability.dart';
import 'package:enjoy_player/features/ai/domain/chat_message.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_request.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_result.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_request.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_result.dart';
import 'package:enjoy_player/features/ai/domain/models/tts_request.dart';
import 'package:enjoy_player/features/ai/domain/models/tts_result.dart';
import 'package:enjoy_player/features/ai/domain/modality_kind.dart';

final class ByokNotConfiguredAsrCapability implements AsrCapability {
  const ByokNotConfiguredAsrCapability();

  @override
  Future<AsrResult> transcribe(AsrRequest request) {
    throw const ByokNotConfiguredFailure(ModalityKind.asr);
  }
}

final class ByokNotConfiguredLlmCapability implements LlmCapability {
  const ByokNotConfiguredLlmCapability();

  @override
  Future<String> generateChatCompletion({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? responseFormat,
  }) {
    throw const ByokNotConfiguredFailure(ModalityKind.llm);
  }

  @override
  Future<String> generateText({
    String? systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
  }) {
    throw const ByokNotConfiguredFailure(ModalityKind.llm);
  }
}

final class ByokNotConfiguredTtsCapability implements TtsCapability {
  const ByokNotConfiguredTtsCapability();

  @override
  Future<TtsResult> synthesize(TtsRequest request) {
    throw const ByokNotConfiguredFailure(ModalityKind.tts);
  }
}

final class ByokNotConfiguredAssessmentCapability
    implements AssessmentCapability {
  const ByokNotConfiguredAssessmentCapability();

  @override
  Future<AssessmentResult> assess(AssessmentRequest request) {
    throw const ByokNotConfiguredFailure(ModalityKind.assessment);
  }
}
