import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/features/ai/domain/byok_not_configured_failure.dart';
import 'package:enjoy_player/features/ai/domain/modality_kind.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/craft/application/craft_controller.dart';
import 'package:enjoy_player/features/craft/application/craft_preferences_provider.dart';
import 'package:enjoy_player/features/craft/application/craft_timeline_enricher.dart';
import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/features/craft/domain/craft_job_state.dart';
import 'package:enjoy_player/features/craft/domain/craft_preferences.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';
import 'package:enjoy_player/features/craft/domain/craft_transcriber.dart';
import 'package:enjoy_player/features/craft/domain/craft_translator.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/domain/craft_screen_mode.dart';
import 'package:enjoy_player/features/craft/domain/craft_stage.dart';
import 'package:enjoy_player/features/craft/application/craft_library_repository_provider.dart';
import 'package:enjoy_player/features/craft/data/craft_library_repository.dart';
import 'package:enjoy_player/features/craft/domain/craft_edit_source.dart';
import 'package:forced_alignment/forced_alignment.dart';

// === Fakes ===

class _SignedInAuthCtrl extends AuthCtrl {
  _SignedInAuthCtrl(this.profile);
  final UserProfile profile;
  @override
  Future<AuthState> build() async => AuthSignedIn(profile: profile);
}

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

/// Resolved app prefs without the real controller's server-sync pipeline.
class _FixedPrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => const AppPreferencesState(
    locale: kAppDefaultDisplayLocale,
    learningLanguage: 'en-US',
    nativeLanguage: 'zh-CN',
  );
}

class _TogglableAuthCtrl extends AuthCtrl {
  _TogglableAuthCtrl(this.profile);
  final UserProfile profile;
  @override
  Future<AuthState> build() async => AuthSignedIn(profile: profile);
  void forceSignedOut() => state = const AsyncData(AuthSignedOut());
}

class _FakeTranslator implements CraftTranslator {
  _FakeTranslator({this.result = 'translated text', this.error});

  final String result;
  final Object? error;

  int callCount = 0;
  String? lastText;
  String? lastSourceLanguage;
  String? lastTargetLanguage;
  TranslationStyle? lastStyle;
  String? lastCustomPrompt;

  @override
  Future<String> translate({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    TranslationStyle style = TranslationStyle.natural,
    String? customPrompt,
  }) async {
    callCount++;
    lastText = text;
    lastSourceLanguage = sourceLanguage;
    lastTargetLanguage = targetLanguage;
    lastStyle = style;
    lastCustomPrompt = customPrompt;
    if (error != null) throw error!;
    return result;
  }
}

class _FakeSynthesizer implements CraftSynthesizer {
  _FakeSynthesizer({
    Uint8List? audioBytes,
    this.format = 'wav',
    this.wordBoundaries = const [],
    this.error,
  }) : audioBytes = audioBytes ?? Uint8List.fromList(const [1, 2, 3, 4]);

  final Uint8List audioBytes;
  final String format;
  final List<CraftWordBoundary> wordBoundaries;
  final Object? error;

  int callCount = 0;
  String? lastText;
  String? lastLanguage;
  String? lastVoice;

  @override
  Future<CraftSynthesisResult> synthesize({
    required String text,
    required String language,
    String? voice,
  }) async {
    callCount++;
    lastText = text;
    lastLanguage = language;
    lastVoice = voice;
    if (error != null) throw error!;
    return CraftSynthesisResult(
      audioBytes: audioBytes,
      format: format,
      wordBoundaries: wordBoundaries,
    );
  }
}

class _FakeLibraryRepository extends CraftLibraryRepository {
  _FakeLibraryRepository(super.db, super.storage);

  String? existingId;
  String importResultId = 'media-new';
  Object? importError;

  int findExistingCalls = 0;
  int importCalls = 0;

  String? lastFindLearningLanguage;
  String? lastFindNormalizedText;
  String? lastFindSourceFlag;
  String? lastFindVoice;

  Uint8List? lastImportAudioBytes;
  String? lastImportAudioFormat;
  String? lastImportLearningLanguage;
  String? lastImportSourceLanguage;
  String? lastImportText;
  String? lastImportNormalizedText;
  String? lastImportTimelineJson;
  String? lastImportVoice;
  String? lastImportSourceFlag;
  String? lastImportSignedInUserId;

  // === Craft history edit fakes ===
  CraftEditSource? editSource;
  String updateResultId = 'media-updated';
  Object? updateError;

  int updateCalls = 0;
  String? lastUpdateMediaId;
  Uint8List? lastUpdateAudioBytes;
  String? lastUpdateAudioFormat;
  String? lastUpdateLearningLanguage;
  String? lastUpdateText;
  String? lastUpdateNormalizedText;
  String? lastUpdateTimelineJson;
  String? lastUpdateVoice;
  String? lastUpdateSourceFlag;

  @override
  Future<CraftEditSource?> getCraftEditSource(String mediaId) async {
    return editSource;
  }

  @override
  Future<String> updateCraftedFromText({
    required String mediaId,
    required Uint8List audioBytes,
    required String audioFormat,
    required String learningLanguage,
    required String text,
    required String normalizedText,
    String? primaryTimelineJson,
    String? voice,
    required String sourceFlag,
  }) async {
    updateCalls++;
    lastUpdateMediaId = mediaId;
    lastUpdateAudioBytes = audioBytes;
    lastUpdateAudioFormat = audioFormat;
    lastUpdateLearningLanguage = learningLanguage;
    lastUpdateText = text;
    lastUpdateNormalizedText = normalizedText;
    lastUpdateTimelineJson = primaryTimelineJson;
    lastUpdateVoice = voice;
    lastUpdateSourceFlag = sourceFlag;
    if (updateError != null) throw updateError!;
    return updateResultId;
  }

  @override
  Future<String?> findExistingCrafted({
    required String learningLanguage,
    required String normalizedText,
    required String sourceFlag,
    String? voice,
  }) async {
    findExistingCalls++;
    lastFindLearningLanguage = learningLanguage;
    lastFindNormalizedText = normalizedText;
    lastFindSourceFlag = sourceFlag;
    lastFindVoice = voice;
    return existingId;
  }

  @override
  Future<String> importCraftedFromText({
    required Uint8List audioBytes,
    required String audioFormat,
    required String learningLanguage,
    String? sourceLanguage,
    required String text,
    required String normalizedText,
    String? primaryTimelineJson,
    String? voice,
    required String sourceFlag,
    required String signedInUserId,
  }) async {
    importCalls++;
    lastImportAudioBytes = audioBytes;
    lastImportAudioFormat = audioFormat;
    lastImportLearningLanguage = learningLanguage;
    lastImportSourceLanguage = sourceLanguage;
    lastImportText = text;
    lastImportNormalizedText = normalizedText;
    lastImportTimelineJson = primaryTimelineJson;
    lastImportVoice = voice;
    lastImportSourceFlag = sourceFlag;
    lastImportSignedInUserId = signedInUserId;
    if (importError != null) throw importError!;
    return importResultId;
  }
}

class _FakeTranscriber implements CraftTranscriber {
  _FakeTranscriber({this.result = 'I had a great day today.', this.error});

  final String result;
  final Object? error;

  int callCount = 0;
  Uint8List? lastAudioBytes;
  String? lastLanguage;

  @override
  Future<String> transcribe({
    required Uint8List audioBytes,
    String? language,
  }) async {
    callCount++;
    lastAudioBytes = audioBytes;
    lastLanguage = language;
    if (error != null) throw error!;
    return result;
  }
}

// === Test harness ===

const _profile = UserProfile(id: 'user-1', email: 'a@b.com', name: 'Tester');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late _FakeTranslator translator;
  late _FakeSynthesizer synthesizer;
  late _FakeTranscriber transcriber;
  late _FakeLibraryRepository repo;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    translator = _FakeTranslator();
    synthesizer = _FakeSynthesizer();
    transcriber = _FakeTranscriber();
    repo = _FakeLibraryRepository(db, FileStorage());
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer container({UserProfile? profile = _profile}) {
    return ProviderContainer(
      overrides: [
        craftTranslatorProvider.overrideWithValue(translator),
        craftSynthesizerProvider.overrideWithValue(synthesizer),
        craftTranscriberProvider.overrideWithValue(transcriber),
        craftLibraryRepositoryProvider.overrideWithValue(repo),
        craftTimelineEnricherProvider.overrideWithValue(
          CraftTimelineEnricher(enabled: false),
        ),
        appDatabaseProvider.overrideWithValue(db),
        appPreferencesCtrlProvider.overrideWith(_FixedPrefsCtrl.new),
        if (profile == null)
          authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new)
        else
          authCtrlProvider.overrideWith(() => _SignedInAuthCtrl(profile)),
      ],
    );
  }

  /// Mirrors the CraftScreen subscriber: keeps the autoDispose controller
  /// alive across awaits so preference hydration applies as in production.
  /// Call after auth has resolved — Craft is only reachable when signed in.
  CraftController notifierOf(ProviderContainer c) {
    c.listen(craftControllerProvider, (_, _) {});
    return c.read(craftControllerProvider.notifier);
  }

  CraftJobState stateOf(ProviderContainer c) => c.read(craftControllerProvider);

  group('build', () {
    test('starts with default empty state', () {
      final c = container();
      addTearDown(c.dispose);
      final s = stateOf(c);
      expect(s.sourceText, '');
      // Languages are seeded synchronously from app prefs. Prefs are still
      // resolving at this instant in tests → the 'en-US' cold-start fallback.
      expect(s.sourceLanguage, 'en-US');
      expect(s.targetLanguage, 'en-US');
      expect(s.style, TranslationStyle.natural);
      expect(s.customPrompt, isNull);
      expect(s.translatedText, isNull);
      expect(s.isTranslating, isFalse);
      expect(s.synthText, '');
      expect(s.synthLanguage, 'en');
      expect(s.selectedVoice, isNull);
      expect(s.previewAudioBytes, isNull);
      expect(s.previewFormat, isNull);
      expect(s.previewWordBoundaries, isEmpty);
      expect(s.isSynthesizing, isFalse);
      expect(s.isSaving, isFalse);
      expect(s.resultMediaId, isNull);
      expect(s.dedupedExistingId, isNull);
      expect(s.failure, isNull);
      expect(s.isBusy, isFalse);
      expect(s.hasPreview, isFalse);
      expect(s.hasTranslation, isFalse);
    });
  });

  group('translate tool setters', () {
    test('setSourceText updates text and clears failure', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('en');
      n.setSourceText('long enough text');
      await n.translate();
      expect(stateOf(c).failure, isA<CraftSameLanguageFailure>());

      n.setSourceText('new source text');
      expect(stateOf(c).sourceText, 'new source text');
      expect(stateOf(c).failure, isNull);
    });

    test('setSourceLanguage updates language and clears failure', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('en');
      n.setSourceText('long enough text');
      await n.translate();
      expect(stateOf(c).failure, isNotNull);

      n.setSourceLanguage('zh');
      expect(stateOf(c).sourceLanguage, 'zh');
      expect(stateOf(c).failure, isNull);
    });

    test('setTargetLanguage updates language and clears failure', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('en');
      n.setSourceText('long enough text');
      await n.translate();
      expect(stateOf(c).failure, isNotNull);

      n.setTargetLanguage('fr');
      expect(stateOf(c).targetLanguage, 'fr');
      expect(stateOf(c).failure, isNull);
    });

    test('setTargetLanguage realigns selectedVoice to the new language', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      n.setSelectedVoice('zh-CN-XiaoxiaoNeural');
      n.setTargetLanguage('en-US');
      final voice = stateOf(c).selectedVoice;
      expect(voice, isNotNull);
      expect(voice!.startsWith('en-'), isTrue);
    });

    test('setStyle updates style and clears failure', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('en');
      n.setSourceText('long enough text');
      await n.translate();
      expect(stateOf(c).failure, isNotNull);

      n.setStyle(TranslationStyle.formal);
      expect(stateOf(c).style, TranslationStyle.formal);
      expect(stateOf(c).failure, isNull);
    });

    test('setCustomPrompt updates prompt and clears failure', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('en');
      n.setSourceText('long enough text');
      await n.translate();
      expect(stateOf(c).failure, isNotNull);

      n.setCustomPrompt('be poetic');
      expect(stateOf(c).customPrompt, 'be poetic');
      expect(stateOf(c).failure, isNull);
    });

    test('setTranslatedText edits the result inline', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setTranslatedText('hand edited');
      expect(stateOf(c).translatedText, 'hand edited');
      expect(stateOf(c).hasTranslation, isTrue);
    });
  });

  group('swapLanguages', () {
    test('swaps source and target when source is set', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('zh');
      n.setTargetLanguage('en');
      n.swapLanguages();
      expect(stateOf(c).sourceLanguage, 'en');
      expect(stateOf(c).targetLanguage, 'zh');
    });

    test('swaps the seeded pair when only target was changed', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      // Build seeds sourceLanguage, so swapping exchanges both sides.
      n.setTargetLanguage('fr');
      n.swapLanguages();
      expect(stateOf(c).sourceLanguage, 'fr');
      expect(stateOf(c).targetLanguage, 'en-US');
    });
  });

  group('useTranslatedText', () {
    test('copies translated text and target language into synth tool', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setTargetLanguage('es');
      n.setTranslatedText('hola mundo');
      n.useTranslatedText();
      expect(stateOf(c).synthText, 'hola mundo');
      expect(stateOf(c).synthLanguage, 'es');
    });

    test('is a no-op when translated text is null', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSynthText('existing');
      n.useTranslatedText();
      expect(stateOf(c).synthText, 'existing');
    });

    test('is a no-op when translated text is empty', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setTranslatedText('');
      n.setSynthText('existing');
      n.useTranslatedText();
      expect(stateOf(c).synthText, 'existing');
    });
  });

  group('translate', () {
    test('returns early when normalized text is too short', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('zh');
      n.setTargetLanguage('en');
      n.setSourceText('short');
      await n.translate();
      expect(translator.callCount, 0);
      expect(stateOf(c).isTranslating, isFalse);
      expect(stateOf(c).translatedText, isNull);
    });

    test('build-seeded languages make a bare translate hit the same-language '
        'guard instead of calling the translator', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceText('long enough text');
      await n.translate();
      expect(translator.callCount, 0);
      expect(stateOf(c).failure, isA<CraftSameLanguageFailure>());
      expect(stateOf(c).translatedText, isNull);
    });

    test('sets same-language failure when base languages match', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en-US');
      n.setTargetLanguage('en-GB');
      n.setSourceText('long enough text');
      await n.translate();
      expect(translator.callCount, 0);
      expect(stateOf(c).failure, isA<CraftSameLanguageFailure>());
      expect(
        stateOf(c).failure!.action,
        CraftFailureAction.switchToSpeakDirectly,
      );
    });

    test('stores translated result on success', () async {
      translator = _FakeTranslator(result: 'Bonjour le monde');
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('fr');
      n.setStyle(TranslationStyle.formal);
      n.setCustomPrompt('keep it short');
      n.setSourceText('  Hello   world  ');
      await n.translate();

      expect(translator.callCount, 1);
      expect(translator.lastText, 'Hello world');
      expect(translator.lastSourceLanguage, 'en');
      expect(translator.lastTargetLanguage, 'fr');
      expect(translator.lastStyle, TranslationStyle.formal);
      expect(translator.lastCustomPrompt, 'keep it short');
      expect(stateOf(c).translatedText, 'Bonjour le monde');
      expect(stateOf(c).isTranslating, isFalse);
      expect(stateOf(c).failure, isNull);
    });

    test('sets translate failure when translator throws', () async {
      translator = _FakeTranslator(error: StateError('boom'));
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('fr');
      n.setSourceText('long enough text');
      await n.translate();

      expect(stateOf(c).isTranslating, isFalse);
      expect(stateOf(c).failure, isA<CraftTranslateFailure>());
      expect(stateOf(c).failure!.action, CraftFailureAction.retry);
      expect(stateOf(c).translatedText, isNull);
    });

    test('maps a credits rejection to CraftCreditsFailure and keeps source '
        'text for retry (spec 045)', () async {
      translator = _FakeTranslator(
        error: const CreditsFailure(
          'HTTP 402',
          requiredCredits: 900,
          usedCredits: 800,
          limitCredits: 1000,
        ),
      );
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('fr');
      n.setSourceText('long enough text');
      await n.translate();

      final failure = stateOf(c).failure;
      expect(failure, isA<CraftCreditsFailure>());
      expect(failure!.action, CraftFailureAction.retry);
      // Source draft preserved so the learner can retry without re-entry.
      expect(stateOf(c).sourceText, 'long enough text');
      expect(stateOf(c).isTranslating, isFalse);
    });

    test('clears a prior failure when a later translation succeeds', () async {
      translator = _FakeTranslator(result: 'Bonjour');
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('en');
      n.setSourceText('long enough text');
      await n.translate();
      expect(stateOf(c).failure, isA<CraftSameLanguageFailure>());

      n.setTargetLanguage('fr');
      await n.translate();
      expect(stateOf(c).failure, isNull);
      expect(stateOf(c).translatedText, 'Bonjour');
    });
  });

  group('synthesize tool setters', () {
    test('setSynthText updates text and clears failure', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSourceLanguage('en');
      n.setTargetLanguage('en');
      n.setSourceText('long enough text');
      await n.translate();
      expect(stateOf(c).failure, isNotNull);

      n.setSynthText('speak this please');
      expect(stateOf(c).synthText, 'speak this please');
      expect(stateOf(c).failure, isNull);
    });

    test('setSynthLanguage picks default voice for the new language', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSynthLanguage('zh-CN');
      expect(stateOf(c).synthLanguage, 'zh-CN');
      expect(stateOf(c).selectedVoice, 'zh-CN-XiaoxiaoNeural');
    });

    test('setSynthLanguage keeps voice when it matches the new language', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      n.setSelectedVoice('zh-CN-YunxiNeural');
      n.setSynthLanguage('zh-CN');
      expect(stateOf(c).selectedVoice, 'zh-CN-YunxiNeural');
    });

    test('setSynthLanguage clears preview and failure', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      await c.read(authCtrlProvider.future);
      n.setSynthText('long enough text');
      await n.synthesize();
      expect(stateOf(c).hasPreview, isTrue);

      n.setSynthLanguage('fr-FR');
      expect(stateOf(c).previewAudioBytes, isNull);
      expect(stateOf(c).previewFormat, isNull);
      expect(stateOf(c).previewWordBoundaries, isEmpty);
      expect(stateOf(c).selectedVoice, 'fr-FR-DeniseNeural');
    });

    test('setSelectedVoice updates voice and clears preview', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);
      await c.read(authCtrlProvider.future);
      n.setSynthText('long enough text');
      await n.synthesize();
      expect(stateOf(c).hasPreview, isTrue);

      n.setSelectedVoice('en-US-GuyNeural');
      expect(stateOf(c).selectedVoice, 'en-US-GuyNeural');
      expect(stateOf(c).previewAudioBytes, isNull);
    });
  });

  group('synthesize', () {
    test('returns early when normalized text is too short', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('short');
      await n.synthesize();
      expect(synthesizer.callCount, 0);
      expect(stateOf(c).isSynthesizing, isFalse);
      expect(stateOf(c).failure, isNull);
    });

    test('requires sign-in', () async {
      final c = container(profile: null);
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();
      expect(synthesizer.callCount, 0);
      expect(stateOf(c).failure, isA<CraftSignInRequiredFailure>());
      expect(stateOf(c).failure!.action, CraftFailureAction.signIn);
    });

    test(
      'stores preview bytes, format, and word boundaries on success',
      () async {
        final bytes = Uint8List.fromList(const [9, 9, 9]);
        synthesizer = _FakeSynthesizer(
          audioBytes: bytes,
          format: 'mp3',
          wordBoundaries: const [
            CraftWordBoundary(text: 'Hello', audioOffsetMs: 0, durationMs: 300),
          ],
        );
        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        final n = notifierOf(c);
        n.setSynthLanguage('en-US');
        n.setSelectedVoice('en-US-JennyNeural');
        n.setSynthText('  Hello   world  ');
        await n.synthesize();

        expect(synthesizer.callCount, 1);
        expect(synthesizer.lastText, 'Hello world');
        expect(synthesizer.lastLanguage, 'en-US');
        expect(synthesizer.lastVoice, 'en-US-JennyNeural');
        final s = stateOf(c);
        expect(s.previewAudioBytes, bytes);
        expect(s.previewFormat, 'mp3');
        expect(s.previewWordBoundaries, hasLength(1));
        expect(s.isSynthesizing, isFalse);
        expect(s.hasPreview, isTrue);
        expect(s.failure, isNull);
      },
    );

    test('maps ByokNotConfiguredFailure to openAiSettings action', () async {
      synthesizer = _FakeSynthesizer(
        error: const ByokNotConfiguredFailure(ModalityKind.tts),
      );
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();

      final failure = stateOf(c).failure;
      expect(failure, isA<CraftTtsFailure>());
      expect(failure!.action, CraftFailureAction.openAiSettings);
      expect(stateOf(c).isSynthesizing, isFalse);
    });

    test('maps 401 ApiException to openAiSettings action', () async {
      synthesizer = _FakeSynthesizer(
        error: const ApiException(message: 'unauthorized', statusCode: 401),
      );
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();

      final failure = stateOf(c).failure;
      expect(failure, isA<CraftTtsFailure>());
      expect(failure!.action, CraftFailureAction.openAiSettings);
    });

    test('maps other errors to a retryable tts failure', () async {
      synthesizer = _FakeSynthesizer(
        error: const ApiException(message: 'server error', statusCode: 500),
      );
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();

      final failure = stateOf(c).failure;
      expect(failure, isA<CraftTtsFailure>());
      expect(failure!.action, CraftFailureAction.retry);
      expect(stateOf(c).isSynthesizing, isFalse);
    });
  });

  group('saveToLibrary', () {
    test('returns null when there is no preview audio', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final result = await notifierOf(c).saveToLibrary();
      expect(result, isNull);
      expect(repo.findExistingCalls, 0);
      expect(repo.importCalls, 0);
      expect(stateOf(c).isSaving, isFalse);
      expect(stateOf(c).failure, isNull);
    });

    test('requires sign-in at save time', () async {
      final auth = _TogglableAuthCtrl(_profile);
      final c = ProviderContainer(
        overrides: [
          craftTranslatorProvider.overrideWithValue(translator),
          craftSynthesizerProvider.overrideWithValue(synthesizer),
          craftLibraryRepositoryProvider.overrideWithValue(repo),
          craftTimelineEnricherProvider.overrideWithValue(
            CraftTimelineEnricher(enabled: false),
          ),
          appDatabaseProvider.overrideWithValue(db),
          authCtrlProvider.overrideWith(() => auth),
        ],
      );
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();
      expect(stateOf(c).hasPreview, isTrue);

      auth.forceSignedOut();
      final result = await n.saveToLibrary();
      expect(result, isNull);
      expect(stateOf(c).failure, isA<CraftSignInRequiredFailure>());
      expect(repo.importCalls, 0);
    });

    test('returns existing id and skips import on dedupe hit', () async {
      repo.existingId = 'media-existing';
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();

      final result = await n.saveToLibrary();
      expect(result?.mediaId, 'media-existing');
      expect(result?.wasDedupe, isTrue);
      expect(result?.wroteSolidTranscript, isFalse);
      expect(stateOf(c).dedupedExistingId, 'media-existing');
      expect(stateOf(c).isSaving, isFalse);
      expect(repo.findExistingCalls, 1);
      expect(repo.importCalls, 0);
    });

    test('imports with word-boundary timeline when boundaries exist', () async {
      synthesizer = _FakeSynthesizer(
        wordBoundaries: const [
          CraftWordBoundary(text: 'Hello', audioOffsetMs: 0, durationMs: 300),
          CraftWordBoundary(
            text: 'world.',
            audioOffsetMs: 300,
            durationMs: 400,
          ),
        ],
      );
      repo.importResultId = 'media-123';
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setScreenMode(CraftScreenMode.advanced);
      n.setSynthLanguage('en-US');
      n.setSelectedVoice('en-US-JennyNeural');
      n.setSynthText('Hello world.');
      await n.synthesize();

      final result = await n.saveToLibrary();
      expect(result?.mediaId, 'media-123');
      expect(result?.wroteSolidTranscript, isTrue);
      expect(result?.wasDedupe, isFalse);
      expect(stateOf(c).resultMediaId, 'media-123');
      expect(stateOf(c).isSaving, isFalse);
      expect(repo.importCalls, 1);
      expect(repo.lastImportSourceFlag, 'craft-direct');
      expect(repo.lastImportSignedInUserId, 'user-1');
      expect(repo.lastImportVoice, 'en-US-JennyNeural');
      expect(repo.lastImportLearningLanguage, 'en-US');

      final timeline = jsonDecode(repo.lastImportTimelineJson!) as List;
      expect(timeline, isNotEmpty);
      expect(timeline.first['text'], 'Hello world.');
      expect(timeline.first.containsKey('timeline'), isFalse);
    });

    test(
      'saves blank transcript (null timeline) without word boundaries',
      () async {
        synthesizer = _FakeSynthesizer(wordBoundaries: const []);
        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        final n = notifierOf(c);
        n.setSynthText('long enough text');
        await n.synthesize();

        final result = await n.saveToLibrary();
        expect(result?.mediaId, 'media-new');
        expect(result?.wroteSolidTranscript, isFalse);
        expect(repo.importCalls, 1);
        expect(repo.lastImportTimelineJson, isNull);
      },
    );

    test(
      'opt-in enrichment persists nested spans and leaves audio unchanged',
      () async {
        synthesizer = _FakeSynthesizer(
          wordBoundaries: const [
            CraftWordBoundary(text: 'Hello', audioOffsetMs: 0, durationMs: 300),
            CraftWordBoundary(
              text: 'world.',
              audioOffsetMs: 300,
              durationMs: 400,
            ),
          ],
        );
        repo.importResultId = 'media-123';
        final originalAudio = synthesizer.audioBytes;
        final enricher = CraftTimelineEnricher(
          enabled: true,
          decodePcm: (_) async => Float32List(16000),
          alignSegmentsFn:
              ({
                required sourcePcm16k,
                required language,
                required segments,
              }) async {
                expect(language, 'en-US');
                return AlignmentSuccess(
                  AlignmentResult(
                    timeline: [
                      for (final s in segments)
                        TimelineEntry(
                          type: TimelineEntryType.segment,
                          text: s.text,
                          startTime: s.startTime,
                          endTime: s.endTime,
                          id: s.id,
                          timeline: [
                            TimelineEntry(
                              type: TimelineEntryType.word,
                              text: 'Hello',
                              startTime: s.startTime,
                              endTime: s.endTime,
                              timeline: [
                                TimelineEntry(
                                  type: TimelineEntryType.phone,
                                  text: 'h',
                                  startTime: s.startTime,
                                  endTime: s.endTime,
                                ),
                              ],
                            ),
                          ],
                        ),
                    ],
                    wordTimeline: const [],
                    transcript: 'Hello',
                    language: language,
                    durationSeconds: 1,
                  ),
                );
              },
        );
        final c = ProviderContainer(
          overrides: [
            craftTranslatorProvider.overrideWithValue(translator),
            craftSynthesizerProvider.overrideWithValue(synthesizer),
            craftTranscriberProvider.overrideWithValue(transcriber),
            craftLibraryRepositoryProvider.overrideWithValue(repo),
            craftTimelineEnricherProvider.overrideWithValue(enricher),
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(() => _SignedInAuthCtrl(_profile)),
          ],
        );
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        final n = notifierOf(c);
        n.setScreenMode(CraftScreenMode.advanced);
        n.setSelectedVoice('en-US-JennyNeural');
        n.setSynthText('Hello world.');
        await n.synthesize();

        final result = await n.saveToLibrary();
        expect(result?.wroteSolidTranscript, isTrue);
        expect(repo.importCalls, 1);
        expect(repo.lastImportAudioBytes, originalAudio);
        final timeline = jsonDecode(repo.lastImportTimelineJson!) as List;
        expect(timeline.first['text'], 'Hello world.');
        expect(timeline.first['timeline'], isNotEmpty);
        expect(
          (timeline.first['timeline'] as List).first['phones'],
          isNotEmpty,
        );
      },
    );

    test(
      'dedupe skip does not rewrite the existing item when enrichment is on',
      () async {
        repo.existingId = 'media-existing';
        final enricher = CraftTimelineEnricher(
          enabled: true,
          decodePcm: (_) async => Float32List(16000),
          alignSegmentsFn:
              ({
                required sourcePcm16k,
                required language,
                required segments,
              }) async {
                fail('dedupe must not call alignSegments');
              },
        );
        final c = ProviderContainer(
          overrides: [
            craftTranslatorProvider.overrideWithValue(translator),
            craftSynthesizerProvider.overrideWithValue(synthesizer),
            craftTranscriberProvider.overrideWithValue(transcriber),
            craftLibraryRepositoryProvider.overrideWithValue(repo),
            craftTimelineEnricherProvider.overrideWithValue(enricher),
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(() => _SignedInAuthCtrl(_profile)),
          ],
        );
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        final n = notifierOf(c);
        n.setSynthText('long enough text');
        await n.synthesize();

        final result = await n.saveToLibrary();
        expect(result?.wasDedupe, isTrue);
        expect(repo.importCalls, 0);
        expect(repo.updateCalls, 0);
        expect(repo.lastImportTimelineJson, isNull);
      },
    );

    test('uses craft-translate flag when a translation is present', () async {
      translator = _FakeTranslator(result: 'Bonjour le monde');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setScreenMode(CraftScreenMode.advanced);
      n.setSourceLanguage('en');
      n.setTargetLanguage('fr');
      n.setSourceText('Hello world, friend');
      await n.translate();
      n.useTranslatedText();
      await n.synthesize();

      await n.saveToLibrary();
      expect(repo.lastImportSourceFlag, 'craft-translate');
      expect(repo.lastImportSourceLanguage, 'en');
    });

    test(
      'uses craft-direct flag and null source language for direct synth',
      () async {
        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        final n = notifierOf(c);
        n.setScreenMode(CraftScreenMode.advanced);
        n.setSynthText('long enough text');
        await n.synthesize();

        await n.saveToLibrary();
        expect(repo.lastImportSourceFlag, 'craft-direct');
        expect(repo.lastImportSourceLanguage, isNull);
      },
    );

    test('truncates normalized text beyond the max length', () async {
      final longText = 'a' * 6000;
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText(longText);
      await n.synthesize();

      await n.saveToLibrary();
      expect(repo.lastImportNormalizedText!.length, 5000);
      expect(repo.lastFindNormalizedText!.length, 5000);
      expect(repo.lastImportText, longText);
    });

    test('returns save failure when import throws', () async {
      repo.importError = StateError('disk full');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();

      final result = await n.saveToLibrary();
      expect(result, isNull);
      expect(stateOf(c).failure, isA<CraftSaveFailure>());
      expect(stateOf(c).isSaving, isFalse);
      expect(stateOf(c).resultMediaId, isNull);
    });

    test('passes preview audio bytes and format to the repository', () async {
      final bytes = Uint8List.fromList(const [5, 6, 7, 8]);
      synthesizer = _FakeSynthesizer(audioBytes: bytes, format: 'mp3');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();

      await n.saveToLibrary();
      expect(repo.lastImportAudioBytes, bytes);
      expect(repo.lastImportAudioFormat, 'mp3');
    });
  });

  group('clearResult', () {
    test('clears the active failure', () async {
      repo.importError = StateError('disk full');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      n.setSynthText('long enough text');
      await n.synthesize();
      await n.saveToLibrary();
      expect(stateOf(c).failure, isA<CraftSaveFailure>());

      n.clearResult();
      expect(stateOf(c).failure, isNull);
    });
  });

  // === Express mode tests ===

  group('express capture', () {
    test('startCapture sets isCapturing and clears previous data', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      n.startCapture();
      final s = stateOf(c);
      expect(s.isCapturing, isTrue);
      expect(s.stage, CraftStage.capture);
      expect(s.capturedAudioBytes, isNull);
      expect(s.rawTranscript, isNull);
    });

    test('cancelCapture clears isCapturing and bumps captureCancelTick', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      n.startCapture();
      final tickBefore = stateOf(c).captureCancelTick;
      n.cancelCapture();
      final s = stateOf(c);
      expect(s.isCapturing, isFalse);
      expect(s.isTranscribing, isFalse);
      expect(s.captureCancelTick, tickBefore + 1);
      expect(s.capturedAudioBytes, isNull);
    });

    test('resetForNextCapture clears stuck isCapturing', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      n.startCapture();
      n.resetForNextCapture();
      expect(stateOf(c).isCapturing, isFalse);
    });

    test('setScreenMode clears stuck isCapturing', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      n.startCapture();
      n.setScreenMode(CraftScreenMode.advanced);
      expect(stateOf(c).isCapturing, isFalse);
      expect(stateOf(c).screenMode, CraftScreenMode.advanced);
    });

    test(
      'stopCapture stores bytes and triggers transcribeAndRewrite',
      () async {
        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        final n = notifierOf(c);

        final audio = Uint8List.fromList(const [1, 2, 3]);
        await n.stopCapture(audio);

        // Allow async pipeline to settle.
        await Future<void>.delayed(Duration.zero);

        final s = stateOf(c);
        expect(s.capturedAudioBytes, audio);
        expect(s.isCapturing, isFalse);
        expect(transcriber.callCount, 1);
        expect(transcriber.lastAudioBytes, audio);
      },
    );

    test(
      'transcribeAndRewrite success: stores transcript and rewrite',
      () async {
        translator = _FakeTranslator(result: 'Hoy tuve un gran día.');
        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        final n = notifierOf(c);

        n.setSourceLanguage('en');
        n.setTargetLanguage('es');
        final audio = Uint8List.fromList(const [1, 2, 3]);
        await n.stopCapture(audio);
        await Future<void>.delayed(Duration.zero);

        final s = stateOf(c);
        expect(s.rawTranscript, 'I had a great day today.');
        expect(s.translatedText, 'Hoy tuve un gran día.');
        expect(s.stage, CraftStage.rewrite);
        expect(s.isTranslating, isFalse);
        expect(s.isTranscribing, isFalse);
        expect(s.failure, isNull);
      },
    );

    test('empty transcript → CraftEmptyTranscriptFailure', () async {
      transcriber = _FakeTranscriber(result: 'short');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      await n.stopCapture(Uint8List.fromList(const [1]));
      await Future<void>.delayed(Duration.zero);

      final s = stateOf(c);
      expect(s.failure, isA<CraftEmptyTranscriptFailure>());
      expect(s.isTranscribing, isFalse);
      expect(translator.callCount, 0);
    });

    test('ASR throws → CraftAsrFailure', () async {
      transcriber = _FakeTranscriber(error: Exception('ASR down'));
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      await n.stopCapture(Uint8List.fromList(const [1]));
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(c).failure, isA<CraftAsrFailure>());
    });
  });

  group('resetForNextCapture', () {
    test('clears working data but preserves session preferences', () async {
      translator = _FakeTranslator(result: 'Hola mundo.');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      // Simulate a completed Express flow.
      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      n.setStyle(TranslationStyle.casual);
      n.setSelectedVoice('es-ES-ElviraNeural');
      await n.stopCapture(Uint8List.fromList(const [1, 2, 3]));
      await Future<void>.delayed(Duration.zero);

      // Verify data exists.
      expect(stateOf(c).rawTranscript, isNotNull);
      expect(stateOf(c).translatedText, isNotNull);

      // Reset.
      n.resetForNextCapture();

      final s = stateOf(c);
      // Preserved.
      expect(s.screenMode, CraftScreenMode.express);
      expect(s.sourceLanguage, 'en');
      expect(s.targetLanguage, 'es');
      expect(s.style, TranslationStyle.casual);
      expect(s.selectedVoice, 'es-ES-ElviraNeural');
      // Cleared.
      expect(s.stage, CraftStage.capture);
      expect(s.capturedAudioBytes, isNull);
      expect(s.rawTranscript, isNull);
      expect(s.translatedText, isNull);
      expect(s.previewAudioBytes, isNull);
      expect(s.synthText, '');
      expect(s.sourceText, '');
      expect(s.failure, isNull);
    });
  });

  group('saveAndCaptureNext', () {
    test('saves then resets stage to capture', () async {
      translator = _FakeTranslator(result: 'Hola mundo hoy.');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      // Run Express flow to produce audio.
      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      await n.stopCapture(Uint8List.fromList(const [1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      await n.generateAudio();
      await Future<void>.delayed(Duration.zero);

      expect(stateOf(c).previewAudioBytes, isNotNull);

      await n.saveAndCaptureNext();

      expect(repo.importCalls, 1);
      expect(repo.lastImportSourceFlag, 'craft-express');
      expect(repo.lastImportText, 'I had a great day today.');
      expect(stateOf(c).stage, CraftStage.capture);
    });
  });

  group('saveToLibrary', () {
    test('returns media ID for navigation', () async {
      translator = _FakeTranslator(result: 'Hola mundo hoy.');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      await n.stopCapture(Uint8List.fromList(const [1, 2, 3]));
      await Future<void>.delayed(Duration.zero);
      await n.generateAudio();
      await Future<void>.delayed(Duration.zero);

      final result = await n.saveToLibrary();
      expect(result?.mediaId, 'media-new');
      expect(repo.lastImportSourceFlag, 'craft-express');
    });
  });

  group('generateAudio', () {
    test('copies translatedText to synthText and auto-selects voice', () async {
      translator = _FakeTranslator(result: 'Hola mundo hoy.');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      await n.stopCapture(Uint8List.fromList(const [1, 2, 3]));
      await Future<void>.delayed(Duration.zero);

      await n.generateAudio();
      await Future<void>.delayed(Duration.zero);

      final s = stateOf(c);
      expect(s.synthText, 'Hola mundo hoy.');
      expect(s.synthLanguage, 'es');
      expect(s.selectedVoice, isNotNull);
      expect(s.stage, CraftStage.audio);
      expect(s.previewAudioBytes, isNotNull);
    });
  });

  group('regenerate', () {
    test('re-runs rewrite on existing transcript', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      await n.stopCapture(Uint8List.fromList(const [1, 2, 3]));
      await Future<void>.delayed(Duration.zero);

      expect(translator.callCount, 1);

      await n.regenerate();
      await Future<void>.delayed(Duration.zero);

      expect(translator.callCount, 2);
      expect(stateOf(c).generation, 1);
    });

    test('uses edited raw transcript and clears dirty', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      await n.useTextInput('This is a test of text input mode.');
      await Future<void>.delayed(Duration.zero);
      expect(stateOf(c).isRawTranscriptDirty, isFalse);
      expect(translator.callCount, 1);

      n.setRawTranscript('Corrected transcript for regenerate path.');
      expect(stateOf(c).isRawTranscriptDirty, isTrue);
      expect(
        stateOf(c).sourceText,
        'Corrected transcript for regenerate path.',
      );

      await n.regenerate();
      await Future<void>.delayed(Duration.zero);

      expect(translator.callCount, 2);
      expect(translator.lastText, 'Corrected transcript for regenerate path.');
      expect(stateOf(c).isRawTranscriptDirty, isFalse);
      expect(
        stateOf(c).rewrittenFromTranscript,
        'Corrected transcript for regenerate path.',
      );
    });

    test('no-ops when normalized transcript is below min length', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      await n.useTextInput('This is a test of text input mode.');
      await Future<void>.delayed(Duration.zero);
      expect(translator.callCount, 1);

      n.setRawTranscript('short');
      await n.regenerate();
      await Future<void>.delayed(Duration.zero);

      expect(translator.callCount, 1);
      expect(stateOf(c).generation, 0);
      expect(stateOf(c).isRawTranscriptDirty, isTrue);
    });
  });

  group('setRawTranscript', () {
    test('updates raw transcript and sourceText', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      n.setRawTranscript('hello from stt correction');
      expect(stateOf(c).rawTranscript, 'hello from stt correction');
      expect(stateOf(c).sourceText, 'hello from stt correction');
      expect(stateOf(c).isRawTranscriptDirty, isTrue);
    });
  });

  group('useTextInput', () {
    test('sets raw transcript and triggers rewrite', () async {
      translator = _FakeTranslator(result: ' rewritten result');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      n.setSourceLanguage('en');
      n.setTargetLanguage('es');
      await n.useTextInput('This is a test of text input mode.');
      await Future<void>.delayed(Duration.zero);

      final s = stateOf(c);
      expect(s.rawTranscript, 'This is a test of text input mode.');
      expect(s.translatedText, ' rewritten result');
      expect(s.stage, CraftStage.rewrite);
      expect(transcriber.callCount, 0); // No ASR call.
    });
  });

  group('setScreenMode', () {
    test('switches mode and clears failure', () {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      expect(stateOf(c).screenMode, CraftScreenMode.express);
      n.setScreenMode(CraftScreenMode.advanced);
      expect(stateOf(c).screenMode, CraftScreenMode.advanced);
    });

    test('clears editingMediaId', () async {
      repo.editSource = const CraftEditSource(
        mediaId: 'media-1',
        practiceText: 'Hola mundo.',
        language: 'es-ES',
        sourceFlag: 'craft-direct',
      );
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      final ok = await n.loadForEdit('media-1');
      expect(ok, isTrue);
      expect(stateOf(c).editingMediaId, 'media-1');

      n.setScreenMode(CraftScreenMode.express);
      expect(stateOf(c).editingMediaId, isNull);
    });
  });

  // === Craft history edit ===

  group('loadForEdit', () {
    test('returns false when the item no longer exists', () async {
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      final ok = await n.loadForEdit('missing-media');
      expect(ok, isFalse);
      expect(stateOf(c).editingMediaId, isNull);
    });

    test('prefills Advanced mode for craft-direct items', () async {
      repo.editSource = const CraftEditSource(
        mediaId: 'media-direct',
        practiceText: 'Speak this text directly.',
        language: 'en-US',
        voice: 'en-US-JennyNeural',
        sourceFlag: 'craft-direct',
      );
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      final ok = await n.loadForEdit('media-direct');
      expect(ok, isTrue);

      final s = stateOf(c);
      expect(s.editingMediaId, 'media-direct');
      expect(s.screenMode, CraftScreenMode.advanced);
      expect(s.synthText, 'Speak this text directly.');
      expect(s.synthLanguage, 'en-US');
      expect(s.targetLanguage, 'en-US');
      expect(s.sourceText, '');
      expect(s.selectedVoice, 'en-US-JennyNeural');
    });

    test('prefills Advanced mode for craft-translate items', () async {
      repo.editSource = const CraftEditSource(
        mediaId: 'media-translate',
        practiceText: 'Bonjour le monde.',
        sourceText: 'Hello world.',
        language: 'fr-FR',
        sourceFlag: 'craft-translate',
      );
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      final ok = await n.loadForEdit('media-translate');
      expect(ok, isTrue);

      final s = stateOf(c);
      expect(s.screenMode, CraftScreenMode.advanced);
      expect(s.synthText, 'Bonjour le monde.');
      expect(s.sourceText, 'Hello world.');
      expect(s.synthLanguage, 'fr-FR');
    });

    test('prefills Express mode for craft-express items', () async {
      repo.editSource = const CraftEditSource(
        mediaId: 'media-express',
        practiceText: 'Hoy tuve un gran día.',
        sourceText: 'I had a great day today.',
        language: 'es-ES',
        voice: 'es-ES-ElviraNeural',
        sourceFlag: 'craft-express',
      );
      final c = container();
      addTearDown(c.dispose);
      final n = notifierOf(c);

      final ok = await n.loadForEdit('media-express');
      expect(ok, isTrue);

      final s = stateOf(c);
      expect(s.editingMediaId, 'media-express');
      expect(s.screenMode, CraftScreenMode.express);
      expect(s.stage, CraftStage.rewrite);
      expect(s.style, TranslationStyle.auto);
      expect(s.rawTranscript, 'I had a great day today.');
      expect(s.translatedText, 'Hoy tuve un gran día.');
      expect(s.synthText, 'Hoy tuve un gran día.');
      expect(s.targetLanguage, 'es-ES');
      expect(s.synthLanguage, 'es-ES');
      expect(s.selectedVoice, 'es-ES-ElviraNeural');
    });

    test(
      'treats craft-express without sourceText as Advanced (no native transcript)',
      () async {
        repo.editSource = const CraftEditSource(
          mediaId: 'media-express-empty',
          practiceText: 'Practice text only.',
          language: 'en-US',
          sourceFlag: 'craft-express',
        );
        final c = container();
        addTearDown(c.dispose);
        final n = notifierOf(c);

        final ok = await n.loadForEdit('media-express-empty');
        expect(ok, isTrue);
        expect(stateOf(c).screenMode, CraftScreenMode.advanced);
      },
    );
  });

  group('saveToLibrary when editing', () {
    test('updates the existing item instead of creating a new one', () async {
      repo.editSource = const CraftEditSource(
        mediaId: 'media-direct',
        practiceText: 'Speak this text directly.',
        language: 'en-US',
        sourceFlag: 'craft-direct',
      );
      repo.updateResultId = 'media-direct';
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      final ok = await n.loadForEdit('media-direct');
      expect(ok, isTrue);

      await n.synthesize();
      final result = await n.saveToLibrary();

      expect(result?.mediaId, 'media-direct');
      expect(repo.updateCalls, 1);
      expect(repo.lastUpdateMediaId, 'media-direct');
      expect(repo.importCalls, 0);
      expect(repo.findExistingCalls, 0);
      expect(stateOf(c).resultMediaId, 'media-direct');
      // Editing state is preserved until an explicit reset.
      expect(stateOf(c).editingMediaId, 'media-direct');
    });

    test('surfaces a save failure without touching create path', () async {
      repo.editSource = const CraftEditSource(
        mediaId: 'media-direct',
        practiceText: 'Speak this text directly.',
        language: 'en-US',
        sourceFlag: 'craft-direct',
      );
      repo.updateError = StateError('disk full');
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      await n.loadForEdit('media-direct');
      await n.synthesize();
      final result = await n.saveToLibrary();

      expect(result, isNull);
      expect(stateOf(c).failure, isA<CraftSaveFailure>());
      expect(repo.importCalls, 0);
    });
  });

  // === Remembered preferences ===

  Future<String?> storedRaw() =>
      db.settingsDao.getValue(SettingsKeys.craftPreferencesV1);

  group('preference hydration', () {
    test(
      'seeds languages from app prefs when they are already resolved',
      () async {
        final c = container();
        addTearDown(c.dispose);
        // Resolve prefs before the first read so build() sees real values.
        await c.read(appPreferencesCtrlProvider.future);
        c.invalidate(craftControllerProvider);

        final s = stateOf(c);
        expect(s.targetLanguage, 'en-US');
        expect(s.sourceLanguage, 'zh-CN');
      },
    );

    test(
      'applies persisted mode, style, prompt, and voice after settle',
      () async {
        const persisted = CraftPreferences(
          screenMode: CraftScreenMode.advanced,
          advancedStyle: TranslationStyle.formal,
          customPrompt: 'keep it short',
          voices: {'en': 'en-US-GuyNeural'},
        );
        await db.settingsDao.setValue(
          SettingsKeys.craftPreferencesV1,
          jsonEncode(persisted.toJson()),
        );

        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        notifierOf(c); // attach + build, mirroring entry to the Craft screen
        await pumpEventQueue(); // hydration lands

        final s = stateOf(c);
        expect(s.screenMode, CraftScreenMode.advanced);
        expect(s.style, TranslationStyle.formal);
        expect(s.customPrompt, 'keep it short');
        expect(s.selectedVoice, 'en-US-GuyNeural');
      },
    );

    test('signed-out build does not touch the DB and uses fallbacks', () async {
      final c = container(profile: null);
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      notifierOf(c);
      await pumpEventQueue();

      final s = stateOf(c);
      expect(s.sourceLanguage, 'en-US');
      expect(s.targetLanguage, 'en-US');
      expect(s.style, TranslationStyle.auto); // express default after hydrate
      expect(s.screenMode, CraftScreenMode.express);
      expect(await storedRaw(), isNull);
    });

    test('rebuild re-applies hydration', () async {
      const persisted = CraftPreferences(
        screenMode: CraftScreenMode.advanced,
        advancedStyle: TranslationStyle.formal,
      );
      await db.settingsDao.setValue(
        SettingsKeys.craftPreferencesV1,
        jsonEncode(persisted.toJson()),
      );

      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      notifierOf(c);
      await pumpEventQueue();
      expect(stateOf(c).screenMode, CraftScreenMode.advanced);

      c.invalidate(craftControllerProvider);
      await pumpEventQueue();
      expect(stateOf(c).screenMode, CraftScreenMode.advanced);
      expect(stateOf(c).style, TranslationStyle.formal);
    });

    test('user input before hydration wins', () async {
      const persisted = CraftPreferences(expressStyle: TranslationStyle.formal);
      await db.settingsDao.setValue(
        SettingsKeys.craftPreferencesV1,
        jsonEncode(persisted.toJson()),
      );

      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c); // build() scheduled the hydration microtask
      n.setStyle(TranslationStyle.casual); // synchronous, before H1 can run
      await pumpEventQueue();

      expect(stateOf(c).style, TranslationStyle.casual);
      // The user's choice is what got persisted.
      expect(
        CraftPreferences.fromJson(
          jsonDecode((await storedRaw())!) as Map<String, dynamic>,
        ).expressStyle,
        TranslationStyle.casual,
      );
    });

    test(
      'loadForEdit after hydration replaces prefs and persists nothing',
      () async {
        const persisted = CraftPreferences(
          advancedStyle: TranslationStyle.formal,
          voices: {'en': 'en-US-GuyNeural'},
        );
        final seededJson = jsonEncode(persisted.toJson());
        await db.settingsDao.setValue(
          SettingsKeys.craftPreferencesV1,
          seededJson,
        );
        repo.editSource = const CraftEditSource(
          mediaId: 'media-direct',
          practiceText: 'Speak this text directly.',
          language: 'en-US',
          voice: 'en-US-JennyNeural',
          sourceFlag: 'craft-direct',
        );

        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        await pumpEventQueue(); // hydration lands first

        final ok = await notifierOf(c).loadForEdit('media-direct');
        await pumpEventQueue();

        expect(ok, isTrue);
        final s = stateOf(c);
        expect(s.editingMediaId, 'media-direct');
        expect(s.selectedVoice, 'en-US-JennyNeural'); // the item's own voice
        expect(await storedRaw(), seededJson); // no write happened
      },
    );
  });

  group('preference persistence', () {
    test('setStyle persists under the current screen mode', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      await pumpEventQueue();
      final n = notifierOf(c);
      CraftPreferences prefsOf() => c.read(craftPreferencesCtrlProvider);

      n.setScreenMode(CraftScreenMode.advanced);
      n.setStyle(TranslationStyle.formal);
      await pumpEventQueue();
      expect(prefsOf().advancedStyle, TranslationStyle.formal);

      n.setScreenMode(CraftScreenMode.express);
      n.setStyle(TranslationStyle.casual);
      await pumpEventQueue();
      expect(prefsOf().expressStyle, TranslationStyle.casual);
      expect(prefsOf().advancedStyle, TranslationStyle.formal);
    });

    test('setScreenMode restores the remembered per-mode style', () async {
      const persisted = CraftPreferences(
        expressStyle: TranslationStyle.casual,
        advancedStyle: TranslationStyle.formal,
      );
      await db.settingsDao.setValue(
        SettingsKeys.craftPreferencesV1,
        jsonEncode(persisted.toJson()),
      );
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      await pumpEventQueue(); // hydration lands before the user acts

      n.setScreenMode(CraftScreenMode.advanced);
      expect(stateOf(c).style, TranslationStyle.formal);
      n.setScreenMode(CraftScreenMode.express);
      expect(stateOf(c).style, TranslationStyle.casual);
    });

    test('startCapture and useTextInput keep the chosen style', () async {
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);

      n.setStyle(TranslationStyle.casual);
      n.startCapture();
      expect(stateOf(c).style, TranslationStyle.casual);

      await n.useTextInput('This is a test of text input mode.');
      expect(stateOf(c).style, TranslationStyle.casual);
    });

    test(
      'voice is filed under the picked language, not a stale synthLanguage',
      () async {
        final c = container();
        addTearDown(c.dispose);
        await c.read(authCtrlProvider.future);
        await pumpEventQueue();
        final n = notifierOf(c);

        n.setSynthLanguage('zh-CN'); // makes synthLanguage the wrong key
        n.setSelectedVoice('en-US-GuyNeural', forLanguage: 'en-US');
        await pumpEventQueue();

        final voices = c.read(craftPreferencesCtrlProvider).voices;
        expect(voices['en'], 'en-US-GuyNeural');
        expect(voices.containsKey('zh'), isFalse);
      },
    );

    test('remembered voice survives a target-language round trip', () async {
      const persisted = CraftPreferences(voices: {'en': 'en-US-GuyNeural'});
      await db.settingsDao.setValue(
        SettingsKeys.craftPreferencesV1,
        jsonEncode(persisted.toJson()),
      );
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      await pumpEventQueue();
      final n = notifierOf(c);

      n.setTargetLanguage('ja-JP');
      expect(stateOf(c).selectedVoice, 'ja-JP-NanamiNeural');
      // Let the first prefs load land so the remembered tier can consult it.
      await pumpEventQueue();
      n.setTargetLanguage('en-US');
      expect(stateOf(c).selectedVoice, 'en-US-GuyNeural');
    });

    test('resetForNextCapture keeps hydrated preferences', () async {
      const persisted = CraftPreferences(
        expressStyle: TranslationStyle.casual,
        voices: {'en': 'en-US-GuyNeural'},
      );
      await db.settingsDao.setValue(
        SettingsKeys.craftPreferencesV1,
        jsonEncode(persisted.toJson()),
      );
      final c = container();
      addTearDown(c.dispose);
      await c.read(authCtrlProvider.future);
      final n = notifierOf(c);
      await pumpEventQueue(); // hydration lands before the user acts

      await n.useTextInput('This is a test of text input mode.');
      n.resetForNextCapture();

      final s = stateOf(c);
      expect(s.style, TranslationStyle.casual);
      expect(s.selectedVoice, 'en-US-GuyNeural');
      expect(s.screenMode, CraftScreenMode.express);
    });
  });
}
