// Tests for the Craft in-memory job state value object.
//
// CraftJobState is the single source of truth for both Craft tools
// (Translate / Synthesize) on the same screen. The controller test exercises
// state transitions indirectly; this file pins down the derived getters and
// the copyWith `clear*` semantics directly so adding/removing a field, or
// regressing a clear-vs-set precedence rule, surfaces as a focused failure
// rather than a downstream controller flake.
import 'dart:typed_data';

import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/features/craft/domain/craft_job_state.dart';
import 'package:enjoy_player/features/craft/domain/craft_stage.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Defaults
  // ---------------------------------------------------------------------------
  group('CraftJobState defaults', () {
    test('every field defaults to the value documented in the constructor', () {
      const s = CraftJobState();

      expect(s.screenMode.name, 'express');
      expect(s.stage.name, 'capture');
      expect(s.sourceText, '');
      expect(s.sourceLanguage, isNull);
      expect(s.targetLanguage, 'en');
      expect(s.style.name, 'natural');
      expect(s.customPrompt, isNull);
      expect(s.translatedText, isNull);
      expect(s.isTranslating, isFalse);
      expect(s.capturedAudioBytes, isNull);
      expect(s.rawTranscript, isNull);
      expect(s.rewrittenFromTranscript, isNull);
      expect(s.isCapturing, isFalse);
      expect(s.isTranscribing, isFalse);
      expect(s.captureCancelTick, 0);
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
      expect(s.generation, 0);
      expect(s.editingMediaId, isNull);
    });
  });

  // ---------------------------------------------------------------------------
  // Derived getters
  // ---------------------------------------------------------------------------
  group('isBusy', () {
    test('is false when no async flag is set', () {
      expect(const CraftJobState().isBusy, isFalse);
    });

    test('reflects each of the five async flags independently', () {
      const flags = [
        ('isCapturing', _Flag.isCapturing),
        ('isTranscribing', _Flag.isTranscribing),
        ('isTranslating', _Flag.isTranslating),
        ('isSynthesizing', _Flag.isSynthesizing),
        ('isSaving', _Flag.isSaving),
      ];
      for (final (label, flag) in flags) {
        final s = _stateWith(flag);
        expect(s.isBusy, isTrue, reason: 'expected $label to make isBusy true');
      }
    });

    test('clears back to false once all flags drop', () {
      const s = CraftJobState(isCapturing: true);
      expect(s.copyWith(isCapturing: false).isBusy, isFalse);
    });
  });

  group('hasPreview', () {
    test('is false when previewAudioBytes is null', () {
      expect(const CraftJobState().hasPreview, isFalse);
    });

    test('is true when previewAudioBytes is set, even empty Uint8List', () {
      // An empty payload still means "a preview slot was opened"; the
      // synthesizer guards on byte length at a different layer.
      final s = const CraftJobState().copyWith(previewAudioBytes: Uint8List(0));
      expect(s.hasPreview, isTrue);
    });
  });

  group('hasUnsavedPreview', () {
    test('requires previewAudioBytes to be set', () {
      const s = CraftJobState();
      expect(s.hasUnsavedPreview, isFalse);
    });

    test('is true when preview bytes exist and no resultMediaId/dedup', () {
      final s = const CraftJobState().copyWith(previewAudioBytes: Uint8List(8));
      expect(s.hasUnsavedPreview, isTrue);
    });

    test('is false when resultMediaId is set (save succeeded)', () {
      final s = const CraftJobState().copyWith(
        previewAudioBytes: Uint8List(8),
        resultMediaId: 'media-1',
      );
      expect(s.hasUnsavedPreview, isFalse);
    });

    test('is false when dedupedExistingId is set (reused existing row)', () {
      final s = const CraftJobState().copyWith(
        previewAudioBytes: Uint8List(8),
        dedupedExistingId: 'media-existing',
      );
      expect(s.hasUnsavedPreview, isFalse);
    });

    test('clearing previewAudioBytes also clears hasUnsavedPreview', () {
      final s = const CraftJobState()
          .copyWith(previewAudioBytes: Uint8List(8))
          .copyWith(clearPreview: true);
      expect(s.hasUnsavedPreview, isFalse);
      expect(s.hasPreview, isFalse);
    });
  });

  group('hasTranslation', () {
    test('is false when translatedText is null', () {
      expect(const CraftJobState().hasTranslation, isFalse);
    });

    test('is false when translatedText is empty string', () {
      const s = CraftJobState(translatedText: '');
      expect(s.hasTranslation, isFalse);
    });

    test('is true when translatedText has any non-whitespace content', () {
      const s = CraftJobState(translatedText: 'hola');
      expect(s.hasTranslation, isTrue);
    });
  });

  group('hasCapturedAudio', () {
    test('mirrors capturedAudioBytes nullability', () {
      expect(const CraftJobState().hasCapturedAudio, isFalse);
      final s = const CraftJobState().copyWith(
        capturedAudioBytes: Uint8List(4),
      );
      expect(s.hasCapturedAudio, isTrue);
    });
  });

  group('isRawTranscriptDirty', () {
    test('is false when both transcripts are null', () {
      expect(const CraftJobState().isRawTranscriptDirty, isFalse);
    });

    test('is false when rawTranscript equals rewrittenFromTranscript', () {
      const s = CraftJobState(
        rawTranscript: 'hola',
        rewrittenFromTranscript: 'hola',
      );
      expect(s.isRawTranscriptDirty, isFalse);
    });

    test('ignores whitespace differences (normalizeCraftText semantics)', () {
      const s = CraftJobState(
        rawTranscript: 'hola  mundo',
        rewrittenFromTranscript: '  hola mundo\n',
      );
      expect(s.isRawTranscriptDirty, isFalse);
    });

    test('is true when rawTranscript differs from rewrittenFromTranscript', () {
      const s = CraftJobState(
        rawTranscript: 'hola mundo',
        rewrittenFromTranscript: 'hola',
      );
      expect(s.isRawTranscriptDirty, isTrue);
    });

    test('is true when only rawTranscript is set', () {
      const s = CraftJobState(rawTranscript: 'hola');
      expect(s.isRawTranscriptDirty, isTrue);
    });

    test('is true when only rewrittenFromTranscript is set', () {
      // The contract is "rawTranscript differs from rewrittenFromTranscript";
      // an empty rawTranscript normalized to '' still differs from any
      // non-empty prior rewrite, so the flag stays true until the user
      // explicitly re-matches the saved transcript.
      const s = CraftJobState(rewrittenFromTranscript: 'hola');
      expect(s.isRawTranscriptDirty, isTrue);
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith — basic field replacement
  // ---------------------------------------------------------------------------
  group('copyWith basic', () {
    test('returns a new instance with the requested field set', () {
      const base = CraftJobState();
      final s = base.copyWith(sourceText: 'hola');
      expect(identical(s, base), isFalse);
      expect(s.sourceText, 'hola');
    });

    test('leaves unspecified fields untouched', () {
      const base = CraftJobState(
        sourceText: 'a',
        targetLanguage: 'es',
        synthLanguage: 'fr',
      );
      final s = base.copyWith(stage: CraftStage.audio);
      expect(s.sourceText, 'a');
      expect(s.targetLanguage, 'es');
      expect(s.synthLanguage, 'fr');
      expect(s.stage, CraftStage.audio);
    });

    test('replaces previewWordBoundaries with the new list', () {
      const base = CraftJobState(
        previewWordBoundaries: [
          CraftWordBoundary(text: 'a', audioOffsetMs: 0, durationMs: 10),
        ],
      );
      final next = const CraftWordBoundary(
        text: 'b',
        audioOffsetMs: 20,
        durationMs: 30,
      );
      final s = base.copyWith(previewWordBoundaries: [next]);
      expect(s.previewWordBoundaries.length, 1);
      expect(s.previewWordBoundaries.first.text, 'b');
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith — clear* flag semantics
  // ---------------------------------------------------------------------------
  group('copyWith clear* flags', () {
    test('clearTranslatedText forces translatedText to null', () {
      const base = CraftJobState(translatedText: 'hola');
      final s = base.copyWith(clearTranslatedText: true);
      expect(s.translatedText, isNull);
    });

    test('clearCapturedAudio forces capturedAudioBytes to null', () {
      final base = const CraftJobState().copyWith(
        capturedAudioBytes: Uint8List(4),
      );
      final s = base.copyWith(clearCapturedAudio: true);
      expect(s.capturedAudioBytes, isNull);
    });

    test('clearRawTranscript forces rawTranscript to null', () {
      const base = CraftJobState(rawTranscript: 'hola');
      final s = base.copyWith(clearRawTranscript: true);
      expect(s.rawTranscript, isNull);
    });

    test(
      'clearRewrittenFromTranscript forces rewrittenFromTranscript to null',
      () {
        const base = CraftJobState(rewrittenFromTranscript: 'hola');
        final s = base.copyWith(clearRewrittenFromTranscript: true);
        expect(s.rewrittenFromTranscript, isNull);
      },
    );

    test('clearResultMediaId forces resultMediaId to null', () {
      const base = CraftJobState(resultMediaId: 'media-1');
      final s = base.copyWith(clearResultMediaId: true);
      expect(s.resultMediaId, isNull);
    });

    test('clearDedupedExistingId forces dedupedExistingId to null', () {
      const base = CraftJobState(dedupedExistingId: 'media-existing');
      final s = base.copyWith(clearDedupedExistingId: true);
      expect(s.dedupedExistingId, isNull);
    });

    test('clearEditingMediaId forces editingMediaId to null', () {
      const base = CraftJobState(editingMediaId: 'media-edit');
      final s = base.copyWith(clearEditingMediaId: true);
      expect(s.editingMediaId, isNull);
    });

    test('clearFailure forces failure to null', () {
      const base = CraftJobState(failure: CraftEmptyTranscriptFailure());
      final s = base.copyWith(clearFailure: true);
      expect(s.failure, isNull);
    });

    test('clearPreview nulls previewAudioBytes, previewFormat and bounds', () {
      final base = const CraftJobState().copyWith(
        previewAudioBytes: Uint8List(8),
        previewFormat: 'mp3',
        previewWordBoundaries: const [
          CraftWordBoundary(text: 'a', audioOffsetMs: 0, durationMs: 1),
        ],
      );
      final s = base.copyWith(clearPreview: true);
      expect(s.previewAudioBytes, isNull);
      expect(s.previewFormat, isNull);
      expect(s.previewWordBoundaries, isEmpty);
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith — clear precedence over value
  // ---------------------------------------------------------------------------
  group('copyWith clear precedence', () {
    test(
      'clearTranslatedText wins over a non-null translatedText argument',
      () {
        const base = CraftJobState(translatedText: 'old');
        final s = base.copyWith(
          translatedText: 'new',
          clearTranslatedText: true,
        );
        expect(s.translatedText, isNull);
      },
    );

    test('clearCapturedAudio wins over a non-null capturedAudioBytes', () {
      final base = const CraftJobState().copyWith(
        capturedAudioBytes: Uint8List(4),
      );
      final s = base.copyWith(
        capturedAudioBytes: Uint8List(8),
        clearCapturedAudio: true,
      );
      expect(s.capturedAudioBytes, isNull);
    });

    test('clearPreview wins over a replacement previewAudioBytes', () {
      final base = const CraftJobState().copyWith(
        previewAudioBytes: Uint8List(4),
      );
      final s = base.copyWith(
        previewAudioBytes: Uint8List(16),
        clearPreview: true,
      );
      expect(s.previewAudioBytes, isNull);
      expect(s.previewFormat, isNull);
      expect(s.previewWordBoundaries, isEmpty);
    });

    test('clearFailure wins over a replacement failure', () {
      const base = CraftJobState(failure: CraftEmptyTranscriptFailure());
      final s = base.copyWith(
        failure: const CraftOfflineFailure(),
        clearFailure: true,
      );
      expect(s.failure, isNull);
    });

    test('without clear*, an explicit value still replaces the field', () {
      const base = CraftJobState(sourceText: 'old');
      final s = base.copyWith(sourceText: 'new');
      expect(s.sourceText, 'new');
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith — generation
  // ---------------------------------------------------------------------------
  group('copyWith generation', () {
    test('increments generation when explicitly set', () {
      const base = CraftJobState(generation: 4);
      final s = base.copyWith(generation: 7);
      expect(s.generation, 7);
    });

    test('preserves generation when omitted from copyWith', () {
      const base = CraftJobState(generation: 4);
      final s = base.copyWith(sourceText: 'x');
      expect(s.generation, 4);
    });
  });

  // ---------------------------------------------------------------------------
  // copyWith — captureCancelTick
  // ---------------------------------------------------------------------------
  group('captureCancelTick', () {
    test('controller bumps the tick to discard a live mic', () {
      const base = CraftJobState();
      expect(base.captureCancelTick, 0);
      final s1 = base.copyWith(captureCancelTick: 1);
      final s2 = s1.copyWith(captureCancelTick: 2);
      expect(s1.captureCancelTick, 1);
      expect(s2.captureCancelTick, 2);
    });
  });
}

enum _Flag {
  isCapturing,
  isTranscribing,
  isTranslating,
  isSynthesizing,
  isSaving,
}

CraftJobState _stateWith(_Flag flag) {
  switch (flag) {
    case _Flag.isCapturing:
      return const CraftJobState(isCapturing: true);
    case _Flag.isTranscribing:
      return const CraftJobState(isTranscribing: true);
    case _Flag.isTranslating:
      return const CraftJobState(isTranslating: true);
    case _Flag.isSynthesizing:
      return const CraftJobState(isSynthesizing: true);
    case _Flag.isSaving:
      return const CraftJobState(isSaving: true);
  }
}
