/// Craft controller: two-tool state (Translate + Synthesize) on one screen.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/api/api_exception.dart';
import 'package:enjoy_player/features/ai/application/ai_services.dart';
import 'package:enjoy_player/features/ai/domain/byok_not_configured_failure.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/craft/data/craft_asr_service_transcriber.dart';
import 'package:enjoy_player/features/craft/data/craft_translation_service_translator.dart';
import 'package:enjoy_player/features/craft/data/craft_tts_service_synthesizer.dart';
import 'package:enjoy_player/features/craft/domain/azure_voice.dart';
import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/features/craft/domain/craft_job_state.dart';
import 'package:enjoy_player/features/craft/domain/craft_request.dart';
import 'package:enjoy_player/features/craft/domain/craft_save_result.dart';
import 'package:enjoy_player/features/craft/domain/craft_screen_mode.dart';
import 'package:enjoy_player/features/craft/domain/craft_stage.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';
import 'package:enjoy_player/features/craft/domain/craft_transcriber.dart';
import 'package:enjoy_player/features/craft/domain/craft_translator.dart';
import 'package:enjoy_player/features/craft/domain/translation_style.dart';
import 'package:enjoy_player/features/craft/domain/word_boundary_segmenter.dart';
import 'package:enjoy_player/features/library/application/library_repository_provider.dart';
import 'package:enjoy_player/features/library/domain/craft_edit_source.dart';

/// Provider for the Craft synthesizer (wraps TtsService).
final craftSynthesizerProvider = Provider<CraftSynthesizer>((ref) {
  return CraftTtsServiceSynthesizer(ref.read(ttsServiceProvider));
});

/// Provider for the Craft translator (wraps ChatService / LLM API).
final craftTranslatorProvider = Provider<CraftTranslator>((ref) {
  return CraftTranslationServiceTranslator(ref.read(chatServiceProvider));
});

/// Provider for the Craft transcriber (wraps AsrService).
final craftTranscriberProvider = Provider<CraftTranscriber>((ref) {
  return CraftAsrServiceTranscriber(ref.read(asrServiceProvider));
});

/// Two-tool Craft controller for the full-screen Craft route.
class CraftController extends Notifier<CraftJobState> {
  @override
  CraftJobState build() => const CraftJobState();

  // === Translate tool actions ===

  void setSourceText(String text) {
    state = state.copyWith(sourceText: text, clearFailure: true);
  }

  void setSourceLanguage(String? lang) {
    state = state.copyWith(sourceLanguage: lang, clearFailure: true);
  }

  void setTargetLanguage(String lang) {
    state = state.copyWith(
      targetLanguage: lang,
      selectedVoice: _voiceMatchingLanguage(lang, state.selectedVoice),
      clearFailure: true,
    );
  }

  void setStyle(TranslationStyle style) {
    state = state.copyWith(style: style, clearFailure: true);
  }

  void setCustomPrompt(String? prompt) {
    state = state.copyWith(customPrompt: prompt, clearFailure: true);
  }

  /// Inline edit of the translated result.
  void setTranslatedText(String text) {
    state = state.copyWith(translatedText: text);
  }

  /// Inline edit of the Express native / STT transcript.
  ///
  /// Keeps [CraftJobState.sourceText] in sync so library save continues to
  /// persist the corrected native text.
  void setRawTranscript(String text) {
    state = state.copyWith(
      rawTranscript: text,
      sourceText: text,
      clearFailure: true,
    );
  }

  void swapLanguages() {
    final src = state.sourceLanguage;
    state = state.copyWith(
      sourceLanguage: state.targetLanguage,
      targetLanguage: src ?? state.targetLanguage,
      translatedText: null,
    );
  }

  /// Copy the translated text into the synthesize tool's input.
  void useTranslatedText() {
    if (state.translatedText != null && state.translatedText!.isNotEmpty) {
      state = state.copyWith(
        synthText: state.translatedText!,
        synthLanguage: state.targetLanguage,
      );
    }
  }

  Future<void> translate() async {
    final normalized = normalizeCraftText(state.sourceText);
    if (normalized.length < craftMinTextLength) return;

    final src = state.sourceLanguage;
    if (src == null || src.isEmpty) return;

    // Same-language guard.
    if (_sameBaseLanguage(src, state.targetLanguage)) {
      state = state.copyWith(failure: const CraftSameLanguageFailure());
      return;
    }

    state = state.copyWith(isTranslating: true, clearFailure: true);

    try {
      final translator = ref.read(craftTranslatorProvider);
      final result = await translator.translate(
        text: normalized,
        sourceLanguage: src,
        targetLanguage: state.targetLanguage,
        style: state.style,
        customPrompt: state.customPrompt,
      );
      state = state.copyWith(translatedText: result, isTranslating: false);
    } catch (e, st) {
      logNamed('craft.translate').warning('Translate failed: $e', e, st);
      state = state.copyWith(
        isTranslating: false,
        failure: const CraftTranslateFailure(),
      );
    }
  }

  // === Synthesize tool actions ===

  void setSynthText(String text) {
    state = state.copyWith(synthText: text, clearFailure: true);
  }

  void setSynthLanguage(String lang) {
    // Auto-pick default voice for the new language if current voice doesn't match.
    state = state.copyWith(
      synthLanguage: lang,
      selectedVoice: _voiceMatchingLanguage(lang, state.selectedVoice),
      clearPreview: true,
      clearFailure: true,
    );
  }

  void setSelectedVoice(String? voice) {
    state = state.copyWith(selectedVoice: voice, clearPreview: true);
  }

  Future<void> synthesize() async {
    final normalized = normalizeCraftText(state.synthText);
    if (normalized.length < craftMinTextLength) return;

    // Check sign-in.
    final auth = ref.read(authCtrlProvider).valueOrNull;
    if (auth is! AuthSignedIn) {
      state = state.copyWith(failure: const CraftSignInRequiredFailure());
      return;
    }

    state = state.copyWith(
      isSynthesizing: true,
      clearFailure: true,
      clearPreview: true,
    );

    try {
      final synthesizer = ref.read(craftSynthesizerProvider);
      final result = await synthesizer.synthesize(
        text: normalized,
        language: state.synthLanguage,
        voice: state.selectedVoice,
      );
      state = state.copyWith(
        previewAudioBytes: result.audioBytes,
        previewFormat: result.format,
        previewWordBoundaries: result.wordBoundaries,
        isSynthesizing: false,
      );
    } catch (e, st) {
      logNamed('craft.synthesize').warning('Synthesize failed: $e', e, st);
      state = state.copyWith(isSynthesizing: false, failure: _mapTtsFailure(e));
    }
  }

  // === Save action ===

  Future<CraftSaveResult?> saveToLibrary() async {
    if (state.previewAudioBytes == null) return null;

    final auth = ref.read(authCtrlProvider).valueOrNull;
    if (auth is! AuthSignedIn) {
      state = state.copyWith(failure: const CraftSignInRequiredFailure());
      return null;
    }

    state = state.copyWith(isSaving: true, clearFailure: true);

    try {
      final normalized = normalizeCraftText(state.synthText);
      final truncated = normalized.length > craftMaxTextLength
          ? normalized.substring(0, craftMaxTextLength)
          : normalized;

      // Solid word timings → timed AI transcript. Otherwise blank (null):
      // no fabricated duration estimates; learner generates via STT in player.
      final timelineJson = buildCraftPrimaryTimelineJson(
        state.previewWordBoundaries,
        language: state.synthLanguage,
      );
      final wroteSolid = timelineJson != null;

      // Determine if this is a translate-then-synthesize or direct synthesize.
      final hasSourceLang =
          state.sourceLanguage != null &&
          state.sourceLanguage!.isNotEmpty &&
          state.translatedText != null &&
          state.translatedText!.isNotEmpty;
      final sourceFlag = state.screenMode == CraftScreenMode.express
          ? 'craft-express'
          : (hasSourceLang ? 'craft-translate' : 'craft-direct');
      // Express stores the original native transcript as sourceText.
      final sourceTextForImport = state.screenMode == CraftScreenMode.express
          ? (state.rawTranscript ?? state.synthText)
          : state.synthText;

      final repo = ref.read(mediaLibraryRepositoryProvider);

      // Editing an existing Craft item (from Craft history) — update it in
      // place instead of creating a new library entry. Skip dedupe: the
      // user is intentionally re-saving the same item, possibly with
      // identical text.
      final editingId = state.editingMediaId;
      if (editingId != null) {
        final mediaId = await repo.updateCraftedFromText(
          mediaId: editingId,
          audioBytes: state.previewAudioBytes!,
          audioFormat: state.previewFormat ?? 'wav',
          learningLanguage: state.synthLanguage,
          text: sourceTextForImport,
          normalizedText: truncated,
          primaryTimelineJson: timelineJson,
          voice: state.selectedVoice,
          sourceFlag: sourceFlag,
        );
        state = state.copyWith(isSaving: false, resultMediaId: mediaId);
        return CraftSaveResult(
          mediaId: mediaId,
          wroteSolidTranscript: wroteSolid,
        );
      }

      // Check dedupe before writing.
      final existingId = await repo.findExistingCrafted(
        learningLanguage: state.synthLanguage,
        normalizedText: truncated,
        sourceFlag: sourceFlag,
        voice: state.selectedVoice,
      );
      if (existingId != null) {
        state = state.copyWith(isSaving: false, dedupedExistingId: existingId);
        return CraftSaveResult(
          mediaId: existingId,
          wroteSolidTranscript: false,
          wasDedupe: true,
        );
      }

      final mediaId = await repo.importCraftedFromText(
        audioBytes: state.previewAudioBytes!,
        audioFormat: state.previewFormat ?? 'wav',
        learningLanguage: state.synthLanguage,
        sourceLanguage: hasSourceLang ? state.sourceLanguage : null,
        text: sourceTextForImport,
        normalizedText: truncated,
        sourceFlag: sourceFlag,
        signedInUserId: auth.profile.id,
        primaryTimelineJson: timelineJson,
        voice: state.selectedVoice,
      );

      state = state.copyWith(isSaving: false, resultMediaId: mediaId);
      return CraftSaveResult(
        mediaId: mediaId,
        wroteSolidTranscript: wroteSolid,
      );
    } catch (e, st) {
      logNamed('craft.save').warning('Save failed: $e', e, st);
      state = state.copyWith(
        isSaving: false,
        failure: const CraftSaveFailure(),
      );
      return null;
    }
  }

  void clearResult() {
    state = state.copyWith(
      resultMediaId: null,
      dedupedExistingId: null,
      clearFailure: true,
    );
  }

  // === Craft history edit ===

  /// Loads an existing Crafted item for editing and prefills the working
  /// state so [saveToLibrary] updates it in place instead of creating a
  /// new library entry.
  ///
  /// Returns `false` when the item no longer exists (e.g. deleted from
  /// another device) — callers should surface a "no longer available"
  /// message and avoid navigating to the Craft screen.
  Future<bool> loadForEdit(String mediaId) async {
    final repo = ref.read(mediaLibraryRepositoryProvider);
    final CraftEditSource? source = await repo.getCraftEditSource(mediaId);
    if (source == null) return false;

    final matchedVoice = _voiceMatchingLanguage(source.language, source.voice);
    final isExpress =
        source.sourceFlag == 'craft-express' &&
        source.sourceText != null &&
        source.sourceText!.isNotEmpty;

    if (isExpress) {
      state = state.copyWith(
        editingMediaId: mediaId,
        screenMode: CraftScreenMode.express,
        stage: CraftStage.rewrite,
        style: TranslationStyle.auto,
        rawTranscript: source.sourceText,
        rewrittenFromTranscript: source.sourceText,
        sourceText: source.sourceText ?? '',
        translatedText: source.practiceText,
        synthText: source.practiceText,
        targetLanguage: source.language,
        synthLanguage: source.language,
        selectedVoice: matchedVoice,
        clearPreview: true,
        clearResultMediaId: true,
        clearDedupedExistingId: true,
        clearFailure: true,
      );
      return true;
    }

    state = state.copyWith(
      editingMediaId: mediaId,
      screenMode: CraftScreenMode.advanced,
      sourceText: source.sourceText ?? '',
      synthText: source.practiceText,
      targetLanguage: source.language,
      synthLanguage: source.language,
      selectedVoice: matchedVoice,
      clearPreview: true,
      clearResultMediaId: true,
      clearDedupedExistingId: true,
      clearFailure: true,
      clearTranslatedText: true,
    );
    return true;
  }

  // === Express mode actions ===

  /// Switch between Express and Advanced screen layouts.
  /// Resets all working state so each mode starts fresh, and sets the
  /// default translation style for the target mode.
  void setScreenMode(CraftScreenMode mode) {
    if (mode == state.screenMode) return;
    state = state.copyWith(
      screenMode: mode,
      stage: CraftStage.capture,
      style: mode == CraftScreenMode.express
          ? TranslationStyle.auto
          : TranslationStyle.natural,
      isCapturing: false,
      isTranscribing: false,
      clearCapturedAudio: true,
      clearRawTranscript: true,
      clearRewrittenFromTranscript: true,
      clearTranslatedText: true,
      clearPreview: true,
      clearResultMediaId: true,
      clearDedupedExistingId: true,
      clearFailure: true,
      clearEditingMediaId: true,
      sourceText: '',
      synthText: '',
    );
  }

  /// Begin voice capture — sets [isCapturing] flag and defaults the style
  /// to [TranslationStyle.auto] for the Express flow.
  /// The [CaptureStage] widget owns the actual AudioRecorder.
  void startCapture() {
    state = state.copyWith(
      isCapturing: true,
      style: TranslationStyle.auto,
      clearFailure: true,
      clearCapturedAudio: true,
      clearRawTranscript: true,
      clearRewrittenFromTranscript: true,
    );
  }

  /// Discard an in-progress capture without running ASR.
  ///
  /// Bumps [CraftJobState.captureCancelTick] so [CaptureStage] can stop and
  /// discard the live mic. Safe to call when not capturing (no-op for UI).
  void cancelCapture() {
    state = state.copyWith(
      isCapturing: false,
      isTranscribing: false,
      captureCancelTick: state.captureCancelTick + 1,
      clearCapturedAudio: true,
      clearFailure: true,
    );
  }

  /// Stop capture and store the recorded audio bytes.
  /// Automatically kicks off transcription + rewrite.
  Future<void> stopCapture(Uint8List audioBytes) async {
    state = state.copyWith(isCapturing: false, capturedAudioBytes: audioBytes);
    await transcribeAndRewrite();
  }

  /// Text fallback: skip ASR, advance directly to rewrite.
  /// Uses [TranslationStyle.auto] as the Express default.
  Future<void> useTextInput(String text) async {
    final normalized = normalizeCraftText(text);
    state = state.copyWith(
      rawTranscript: normalized.isEmpty ? null : normalized,
      sourceText: text,
      style: TranslationStyle.auto,
      isTranscribing: false,
      clearFailure: true,
    );
    if (normalized.isEmpty) return;
    // Run rewrite immediately.
    await _rewriteTranscript(normalized);
  }

  /// ASR transcription + LLM rewrite pipeline.
  Future<void> transcribeAndRewrite() async {
    final audio = state.capturedAudioBytes;
    if (audio == null) return;

    state = state.copyWith(isTranscribing: true, clearFailure: true);

    String transcript;
    try {
      final transcriber = ref.read(craftTranscriberProvider);
      transcript = await transcriber.transcribe(
        audioBytes: audio,
        language: state.sourceLanguage,
      );
    } catch (e, st) {
      logNamed('craft.asr').warning('ASR failed: $e', e, st);
      state = state.copyWith(
        isTranscribing: false,
        failure: const CraftAsrFailure(),
      );
      return;
    }

    // Empty / too-short transcript guard.
    if (transcript.trim().length < craftMinTextLength) {
      state = state.copyWith(
        isTranscribing: false,
        rawTranscript: transcript.isEmpty ? null : transcript,
        failure: const CraftEmptyTranscriptFailure(),
      );
      return;
    }

    state = state.copyWith(rawTranscript: transcript);
    await _rewriteTranscript(transcript);
  }

  /// Internal: run LLM rewrite on [rawTranscript] → [translatedText].
  Future<void> _rewriteTranscript(String transcript) async {
    final src = state.sourceLanguage;
    final target = state.targetLanguage;

    state = state.copyWith(
      isTranslating: true,
      stage: CraftStage.rewrite,
      clearFailure: true,
    );

    try {
      final translator = ref.read(craftTranslatorProvider);
      final result = await translator.translate(
        text: transcript,
        sourceLanguage: src ?? target,
        targetLanguage: target,
        style: state.style,
        customPrompt: state.customPrompt,
      );
      state = state.copyWith(
        translatedText: result,
        rewrittenFromTranscript: transcript,
        isTranslating: false,
        isTranscribing: false,
        stage: CraftStage.rewrite,
        selectedVoice: _voiceMatchingLanguage(target, state.selectedVoice),
        synthLanguage: target,
      );
    } catch (e, st) {
      logNamed('craft.rewrite').warning('Rewrite failed: $e', e, st);
      state = state.copyWith(
        isTranslating: false,
        isTranscribing: false,
        failure: const CraftTranslateFailure(),
      );
    }
  }

  /// Re-run the LLM rewrite on existing transcript with current style.
  Future<void> regenerate() async {
    final transcript = state.rawTranscript;
    if (transcript == null) return;
    final normalized = normalizeCraftText(transcript);
    if (normalized.length < craftMinTextLength) return;
    state = state.copyWith(generation: state.generation + 1);
    await _rewriteTranscript(normalized);
  }

  /// Copy [translatedText] → [synthText] and synthesize.
  /// Auto-selects a default voice if none is set.
  Future<void> generateAudio() async {
    if (state.translatedText == null || state.translatedText!.isEmpty) return;

    final target = state.targetLanguage;

    state = state.copyWith(
      stage: CraftStage.audio,
      synthText: state.translatedText!,
      synthLanguage: target,
      selectedVoice: _voiceMatchingLanguage(target, state.selectedVoice),
      clearPreview: true,
      clearFailure: true,
    );
    await synthesize();
  }

  /// Save current item to library and return the save outcome for navigation.
  Future<CraftSaveResult?> saveAndPractice() async {
    return saveToLibrary();
  }

  /// Save current item, then reset for the next capture.
  /// If the save fails, the failure is already in [state.failure] —
  /// we return early so the user's work is NOT destroyed.
  ///
  /// Returns the save outcome (including whether a solid transcript was
  /// written) so callers can show hints before the reset clears preview.
  Future<CraftSaveResult?> saveAndCaptureNext() async {
    final result = await saveToLibrary();
    if (result == null) return null; // failure already surfaced
    resetForNextCapture();
    return result;
  }

  /// Clear Express working data, preserve session preferences.
  void resetForNextCapture() {
    state = state.copyWith(
      stage: CraftStage.capture,
      isCapturing: false,
      isTranscribing: false,
      clearCapturedAudio: true,
      clearRawTranscript: true,
      clearRewrittenFromTranscript: true,
      clearTranslatedText: true,
      clearPreview: true,
      clearResultMediaId: true,
      clearDedupedExistingId: true,
      clearFailure: true,
      clearEditingMediaId: true,
      sourceText: '',
      synthText: '',
    );
  }

  // === Helpers ===

  /// Keep [current] when it belongs to [language]; otherwise pick the default.
  String? _voiceMatchingLanguage(String language, String? current) {
    final base = language.split('-').first.toLowerCase();
    final voices = voicesForLanguage(base);
    if (current != null && voices.any((v) => v.id == current)) {
      return current;
    }
    return defaultVoiceForLanguage(base)?.id;
  }

  bool _sameBaseLanguage(String a, String b) {
    final aBase = a.split('-').first.toLowerCase();
    final bBase = b.split('-').first.toLowerCase();
    return aBase == bBase;
  }

  CraftFailure _mapTtsFailure(Object error) {
    if (error is ByokNotConfiguredFailure) {
      return const CraftTtsFailure(action: CraftFailureAction.openAiSettings);
    }
    if (error is ApiException && error.statusCode == 401) {
      return const CraftTtsFailure(action: CraftFailureAction.openAiSettings);
    }
    return const CraftTtsFailure();
  }
}

/// Notifier provider for [CraftController].
final craftControllerProvider =
    NotifierProvider<CraftController, CraftJobState>(CraftController.new);
