// Tests for `lib/features/ai/data/stub_ai_capabilities.dart`.
//
// Each stub is a constant `throw` — we just need to assert the right exception
// type is thrown so the UI / cache layer can switch on it (UnimplementedError
// vs `ByokNotConfiguredFailure`, etc.).
import 'dart:typed_data';

import 'package:enjoy_player/features/ai/data/stub_ai_capabilities.dart';
import 'package:enjoy_player/features/ai/domain/byok_not_configured_failure.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_request.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_request.dart';
import 'package:enjoy_player/features/ai/domain/models/tts_request.dart';
import 'package:enjoy_player/features/ai/domain/modality_kind.dart';
import 'package:enjoy_player/features/ai/domain/chat_message.dart';
import 'package:flutter_test/flutter_test.dart';

Uint8List _wavBytes() => Uint8List.fromList(const <int>[82, 73, 70, 70]);

AsrRequest _asrReq() =>
    AsrRequest(audioBytes: _wavBytes(), filename: 'test.wav', language: 'en');

AssessmentRequest _assessReq() => AssessmentRequest(
  audioBytes: _wavBytes(),
  referenceText: 'hello world',
  language: 'en',
);

void main() {
  group('ByokNotConfiguredAsrCapability', () {
    test('transcribe() throws ByokNotConfiguredFailure for ASR', () async {
      const c = ByokNotConfiguredAsrCapability();
      try {
        await c.transcribe(_asrReq());
        fail('expected throw');
      } on ByokNotConfiguredFailure catch (e) {
        expect(e.modality, ModalityKind.asr);
      }
    });
  });

  group('ByokNotConfiguredLlmCapability', () {
    test(
      'generateChatCompletion() throws ByokNotConfiguredFailure for LLM',
      () async {
        const c = ByokNotConfiguredLlmCapability();
        try {
          await c.generateChatCompletion(messages: const []);
          fail('expected throw');
        } on ByokNotConfiguredFailure catch (e) {
          expect(e.modality, ModalityKind.llm);
        }
      },
    );

    test('generateText() throws ByokNotConfiguredFailure for LLM', () async {
      const c = ByokNotConfiguredLlmCapability();
      try {
        await c.generateText(userPrompt: 'hi');
        fail('expected throw');
      } on ByokNotConfiguredFailure catch (e) {
        expect(e.modality, ModalityKind.llm);
      }
    });
  });

  group('ByokNotConfiguredTtsCapability', () {
    test('synthesize() throws ByokNotConfiguredFailure for TTS', () async {
      const c = ByokNotConfiguredTtsCapability();
      try {
        await c.synthesize(const TtsRequest(text: 'hi', language: 'en'));
        fail('expected throw');
      } on ByokNotConfiguredFailure catch (e) {
        expect(e.modality, ModalityKind.tts);
      }
    });
  });

  group('ByokNotConfiguredAssessmentCapability', () {
    test('assess() throws ByokNotConfiguredFailure for Assessment', () async {
      const c = ByokNotConfiguredAssessmentCapability();
      try {
        await c.assess(_assessReq());
        fail('expected throw');
      } on ByokNotConfiguredFailure catch (e) {
        expect(e.modality, ModalityKind.assessment);
      }
    });
  });

  group('ChatMessage defaults', () {
    // Smoke test for the `ChatMessage` constructor used in `generateChatCompletion`
    // calls above — guards against accidental signature changes.
    test('default ctor populates role + content', () {
      const m = ChatMessage(role: 'user', content: 'hi');
      expect(m.role, 'user');
      expect(m.content, 'hi');
    });
  });
}
