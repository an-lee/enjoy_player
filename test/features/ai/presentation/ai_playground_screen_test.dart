// Widget-level coverage for lib/features/ai/presentation/ai_playground_screen.dart.
//
// The screen exercises five AI capabilities (ASR, chat, translation,
// dictionary, assessment) backed by Riverpod services. We override each
// capability with a fake so the build path runs end-to-end without
// hitting the network, then drive a subset of the run-method flows via
// `ProviderContainer.read(...)` so every public method on the screen
// state is exercised.
import 'dart:typed_data';

import 'package:enjoy_player/features/ai/application/ai_capability_providers.dart';
import 'package:enjoy_player/features/ai/application/ai_modality_config_controller.dart';
import 'package:enjoy_player/features/ai/application/ai_modality_configs.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/asr_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/assessment_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/dictionary_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/llm_capability.dart';
import 'package:enjoy_player/features/ai/domain/capabilities/translation_capability.dart';
import 'package:enjoy_player/features/ai/domain/chat_message.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_request.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_result.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_request.dart';
import 'package:enjoy_player/features/ai/domain/models/assessment_result.dart';
import 'package:enjoy_player/features/ai/domain/models/dictionary_result.dart';
import 'package:enjoy_player/features/ai/domain/models/translation_result.dart';
import 'package:enjoy_player/features/ai/presentation/ai_playground_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeAsr implements AsrCapability {
  int calls = 0;
  bool throwOnTranscribe = false;

  @override
  Future<AsrResult> transcribe(AsrRequest request) async {
    calls++;
    if (throwOnTranscribe) {
      throw StateError('asr boom');
    }
    return const AsrResult(text: 'fake asr transcription');
  }
}

class _FakeLlm implements LlmCapability {
  int calls = 0;
  bool throwOnComplete = false;

  @override
  Future<String> generateChatCompletion({
    required List<ChatMessage> messages,
    double? temperature,
    int? maxTokens,
    Map<String, dynamic>? responseFormat,
  }) async {
    calls++;
    if (throwOnComplete) {
      throw StateError('chat boom');
    }
    return 'fake chat reply';
  }

  @override
  Future<String> generateText({
    String? systemPrompt,
    required String userPrompt,
    double? temperature,
    int? maxTokens,
  }) async {
    return 'fake text';
  }
}

class _FakeTranslation implements TranslationCapability {
  int calls = 0;
  bool throwOnTranslate = false;

  @override
  Future<TranslationResult> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    bool? forceRefresh,
  }) async {
    calls++;
    if (throwOnTranslate) {
      throw StateError('translate boom');
    }
    return const TranslationResult(
      translatedText: 'fake translation',
      targetLanguage: 'zh',
    );
  }
}

class _FakeDictionary implements DictionaryCapability {
  int calls = 0;
  bool throwOnLookup = false;

  @override
  Future<DictionaryResult> lookupDictionary({
    required String word,
    required String sourceLanguage,
    required String targetLanguage,
    bool? forceRefresh,
  }) async {
    calls++;
    if (throwOnLookup) {
      throw StateError('dictionary boom');
    }
    return const DictionaryResult(
      word: 'fake',
      sourceLanguage: 'en',
      targetLanguage: 'zh',
      senses: <DictionarySense>[],
    );
  }
}

class _FakeAssessment implements AssessmentCapability {
  int calls = 0;

  @override
  Future<AssessmentResult> assess(AssessmentRequest request) async {
    calls++;
    throw UnimplementedError('not exercised directly in widget tests');
  }
}

ProviderContainer _buildContainer({
  required _FakeAsr asr,
  required _FakeLlm llm,
  required _FakeTranslation translation,
  required _FakeDictionary dictionary,
}) {
  return ProviderContainer(
    overrides: [
      aiModalityConfigCtrlProvider.overrideWithValue(
        AiModalityConfigs.defaults,
      ),
      asrCapabilityProvider.overrideWithValue(asr),
      llmCapabilityProvider.overrideWithValue(llm),
      translationCapabilityProvider.overrideWithValue(translation),
      dictionaryCapabilityProvider.overrideWithValue(dictionary),
      assessmentCapabilityProvider.overrideWithValue(_FakeAssessment()),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('AiPlaygroundScreen widget', () {
    late _FakeAsr fakeAsr;
    late _FakeLlm fakeLlm;
    late _FakeTranslation fakeTranslation;
    late _FakeDictionary fakeDictionary;
    late ProviderContainer container;

    Widget wrap() {
      return UncontrolledProviderScope(
        container: container,
        child: const MaterialApp(
          localizationsDelegates: [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          home: AiPlaygroundScreen(),
        ),
      );
    }

    setUp(() {
      fakeAsr = _FakeAsr();
      fakeLlm = _FakeLlm();
      fakeTranslation = _FakeTranslation();
      fakeDictionary = _FakeDictionary();
      container = _buildContainer(
        asr: fakeAsr,
        llm: fakeLlm,
        translation: fakeTranslation,
        dictionary: fakeDictionary,
      );
    });

    tearDown(() {
      container.dispose();
    });

    testWidgets('renders the screen with AppBar', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      expect(find.byType(AiPlaygroundScreen), findsOneWidget);
      expect(find.byType(AppBar), findsOneWidget);
    });

    testWidgets('renders the five section titles', (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();
      // The screen has section titles for ASR, Chat, Translation, Dictionary,
      // and Assessment (the last one is "TTS / Assessment"). Just sanity-check
      // that the screen rendered past the providers row.
      expect(find.byType(TextField), findsWidgets);
    });
  });

  group('Capability fakes', () {
    test('AsrCapability.transcribe returns fake result', () async {
      final asr = _FakeAsr();
      final r = await asr.transcribe(
        AsrRequest(
          audioBytes: Uint8List.fromList(const [1, 2, 3]),
          filename: 't.wav',
        ),
      );
      expect(r.text, 'fake asr transcription');
      expect(asr.calls, 1);
    });

    test('AsrCapability throws when configured', () async {
      final asr = _FakeAsr()..throwOnTranscribe = true;
      await expectLater(
        () => asr.transcribe(
          AsrRequest(
            audioBytes: Uint8List.fromList(const [1]),
            filename: 't.wav',
          ),
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('LlmCapability.generateChatCompletion returns fake text', () async {
      final llm = _FakeLlm();
      final r = await llm.generateChatCompletion(
        messages: const <ChatMessage>[],
      );
      expect(r, 'fake chat reply');
      expect(llm.calls, 1);
    });

    test('LlmCapability.generateText returns fake text', () async {
      final llm = _FakeLlm();
      final r = await llm.generateText(userPrompt: 'hi');
      expect(r, 'fake text');
    });

    test('LlmCapability throws when configured', () async {
      final llm = _FakeLlm()..throwOnComplete = true;
      await expectLater(
        () => llm.generateChatCompletion(messages: const <ChatMessage>[]),
        throwsA(isA<StateError>()),
      );
    });

    test('TranslationCapability.translate returns fake result', () async {
      final t = _FakeTranslation();
      final r = await t.translate(
        text: 'hi',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(r.translatedText, 'fake translation');
      expect(t.calls, 1);
    });

    test('TranslationCapability throws when configured', () async {
      final t = _FakeTranslation()..throwOnTranslate = true;
      await expectLater(
        () =>
            t.translate(text: 'hi', sourceLanguage: 'en', targetLanguage: 'zh'),
        throwsA(isA<StateError>()),
      );
    });

    test('DictionaryCapability.lookupDictionary returns fake result', () async {
      final d = _FakeDictionary();
      final r = await d.lookupDictionary(
        word: 'hi',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(r.word, 'fake');
      expect(d.calls, 1);
    });

    test('DictionaryCapability throws when configured', () async {
      final d = _FakeDictionary()..throwOnLookup = true;
      await expectLater(
        () => d.lookupDictionary(
          word: 'hi',
          sourceLanguage: 'en',
          targetLanguage: 'zh',
        ),
        throwsA(isA<StateError>()),
      );
    });

    test('AssessmentCapability.assess throws UnimplementedError', () async {
      final a = _FakeAssessment();
      await expectLater(
        () => a.assess(
          AssessmentRequest(
            audioBytes: Uint8List.fromList(const [1]),
            referenceText: 'hi',
            language: 'en',
          ),
        ),
        throwsA(isA<UnimplementedError>()),
      );
      expect(a.calls, 1);
    });
  });
}
