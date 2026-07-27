/// In-memory Craft job state for the two-tool Craft screen.
library;

import 'package:flutter/foundation.dart';

import 'craft_failure.dart';
import 'craft_request.dart';
import 'craft_screen_mode.dart';
import 'craft_stage.dart';
import 'craft_synthesizer.dart';
import 'translation_style.dart';

/// The full state of one Craft session — covers both Translate and
/// Synthesize tools on the same screen.
@immutable
class CraftJobState {
  const CraftJobState({
    // Screen mode + stage (Express flow)
    this.screenMode = CraftScreenMode.express,
    this.stage = CraftStage.capture,
    // Translate tool
    this.sourceText = '',
    this.sourceLanguage,
    this.targetLanguage = 'en',
    this.style = TranslationStyle.natural,
    this.customPrompt,
    this.translatedText,
    this.isTranslating = false,
    // Express capture
    this.capturedAudioBytes,
    this.rawTranscript,
    this.rewrittenFromTranscript,
    this.isCapturing = false,
    this.isTranscribing = false,
    this.captureCancelTick = 0,
    // Synthesize tool
    this.synthText = '',
    this.synthLanguage = 'en',
    this.selectedVoice,
    this.previewAudioBytes,
    this.previewFormat,
    this.previewWordBoundaries = const [],
    this.isSynthesizing = false,
    this.isSaving = false,
    // Result
    this.resultMediaId,
    this.dedupedExistingId,
    this.failure,
    this.generation = 0,
    // Editing an existing Craft item (from Craft history)
    this.editingMediaId,
  });

  // --- Screen mode + stage (Express flow) ---
  final CraftScreenMode screenMode;
  final CraftStage stage;

  // --- Translate tool ---
  final String sourceText;
  final String? sourceLanguage;
  final String targetLanguage;
  final TranslationStyle style;
  final String? customPrompt;
  final String? translatedText;
  final bool isTranslating;

  // --- Express capture ---
  final Uint8List? capturedAudioBytes;
  final String? rawTranscript;

  /// Native transcript that produced the current [translatedText], set after
  /// a successful Express rewrite. Used to detect STT corrections that still
  /// need re-translation.
  final String? rewrittenFromTranscript;
  final bool isCapturing;
  final bool isTranscribing;

  /// Incremented by [CraftController.cancelCapture] so [CaptureStage] can
  /// discard the live mic without committing ASR.
  final int captureCancelTick;

  // --- Synthesize tool ---
  final String synthText;
  final String synthLanguage;
  final String? selectedVoice;
  final Uint8List? previewAudioBytes;
  final String? previewFormat;
  final List<CraftWordBoundary> previewWordBoundaries;
  final bool isSynthesizing;
  final bool isSaving;

  // --- Result ---
  final String? resultMediaId;
  final String? dedupedExistingId;
  final CraftFailure? failure;
  final int generation;

  /// Media id of the existing Crafted item being edited, or `null` when
  /// this session is creating a new item. Set by
  /// `CraftController.loadForEdit`; cleared on reset / mode switch.
  final String? editingMediaId;

  // --- Derived ---
  bool get isBusy =>
      isCapturing ||
      isTranscribing ||
      isTranslating ||
      isSynthesizing ||
      isSaving;
  bool get hasPreview => previewAudioBytes != null;
  bool get hasTranslation =>
      translatedText != null && translatedText!.isNotEmpty;
  bool get hasCapturedAudio => capturedAudioBytes != null;

  /// True when the editable native transcript differs from the last successful
  /// rewrite input (whitespace-normalized).
  bool get isRawTranscriptDirty =>
      normalizeCraftText(rawTranscript ?? '') !=
      normalizeCraftText(rewrittenFromTranscript ?? '');

  CraftJobState copyWith({
    CraftScreenMode? screenMode,
    CraftStage? stage,
    String? sourceText,
    String? sourceLanguage,
    String? targetLanguage,
    TranslationStyle? style,
    String? customPrompt,
    String? translatedText,
    bool? isTranslating,
    Uint8List? capturedAudioBytes,
    String? rawTranscript,
    String? rewrittenFromTranscript,
    bool? isCapturing,
    bool? isTranscribing,
    int? captureCancelTick,
    String? synthText,
    String? synthLanguage,
    String? selectedVoice,
    Uint8List? previewAudioBytes,
    String? previewFormat,
    List<CraftWordBoundary>? previewWordBoundaries,
    bool? isSynthesizing,
    bool? isSaving,
    String? resultMediaId,
    String? dedupedExistingId,
    CraftFailure? failure,
    int? generation,
    String? editingMediaId,
    bool clearPreview = false,
    bool clearFailure = false,
    bool clearCapturedAudio = false,
    bool clearRawTranscript = false,
    bool clearRewrittenFromTranscript = false,
    bool clearTranslatedText = false,
    bool clearResultMediaId = false,
    bool clearDedupedExistingId = false,
    bool clearEditingMediaId = false,
  }) {
    return CraftJobState(
      screenMode: screenMode ?? this.screenMode,
      stage: stage ?? this.stage,
      sourceText: sourceText ?? this.sourceText,
      sourceLanguage: sourceLanguage ?? this.sourceLanguage,
      targetLanguage: targetLanguage ?? this.targetLanguage,
      style: style ?? this.style,
      customPrompt: customPrompt ?? this.customPrompt,
      translatedText: clearTranslatedText
          ? null
          : (translatedText ?? this.translatedText),
      isTranslating: isTranslating ?? this.isTranslating,
      capturedAudioBytes: clearCapturedAudio
          ? null
          : (capturedAudioBytes ?? this.capturedAudioBytes),
      rawTranscript: clearRawTranscript
          ? null
          : (rawTranscript ?? this.rawTranscript),
      rewrittenFromTranscript: clearRewrittenFromTranscript
          ? null
          : (rewrittenFromTranscript ?? this.rewrittenFromTranscript),
      isCapturing: isCapturing ?? this.isCapturing,
      isTranscribing: isTranscribing ?? this.isTranscribing,
      captureCancelTick: captureCancelTick ?? this.captureCancelTick,
      synthText: synthText ?? this.synthText,
      synthLanguage: synthLanguage ?? this.synthLanguage,
      selectedVoice: selectedVoice ?? this.selectedVoice,
      previewAudioBytes: clearPreview
          ? null
          : (previewAudioBytes ?? this.previewAudioBytes),
      previewFormat: clearPreview
          ? null
          : (previewFormat ?? this.previewFormat),
      previewWordBoundaries: clearPreview
          ? const []
          : (previewWordBoundaries ?? this.previewWordBoundaries),
      isSynthesizing: isSynthesizing ?? this.isSynthesizing,
      isSaving: isSaving ?? this.isSaving,
      resultMediaId: clearResultMediaId
          ? null
          : (resultMediaId ?? this.resultMediaId),
      dedupedExistingId: clearDedupedExistingId
          ? null
          : (dedupedExistingId ?? this.dedupedExistingId),
      failure: clearFailure ? null : (failure ?? this.failure),
      generation: generation ?? this.generation,
      editingMediaId: clearEditingMediaId
          ? null
          : (editingMediaId ?? this.editingMediaId),
    );
  }
}
