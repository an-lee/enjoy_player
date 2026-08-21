import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/domain/auto_translate.dart';
import 'package:enjoy_player/features/transcript/application/auto_translate_resolved_text.dart';
import 'package:enjoy_player/features/transcript/application/transcript_line_alignment.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptLine cue(
  int startMs,
  int durationMs,
  String text, {
  String? sourceKey,
}) {
  return TranscriptLine(
    text: text,
    startMs: startMs,
    durationMs: durationMs,
    sourceKey: sourceKey,
  );
}

({String? secondaryText, bool canRetranslate, bool isFailed, bool isInFlight})
callResolve({
  required bool autoTranslateActive,
  required List<TranscriptLine> primaryLines,
  required List<TranscriptLine> aiLines,
  required int lineIndex,
  String? sourceLanguage,
  String? targetLanguage,
  required TranscriptSecondaryMatcher matcher,
  required TranscriptLine line,
  required Set<int> failedIndexes,
  required Set<int> inFlightIndexes,
  String? l10nLineFailed,
  String? l10nLinePending,
}) {
  return resolveAutoTranslateTextForDisplay(
    autoTranslateActive: autoTranslateActive,
    primaryLines: primaryLines,
    aiLines: aiLines,
    lineIndex: lineIndex,
    sourceLanguage: sourceLanguage,
    targetLanguage: targetLanguage,
    matcher: matcher,
    line: line,
    isLineFailed: (i) => failedIndexes.contains(i),
    isLineInFlight: (i) => inFlightIndexes.contains(i),
    l10nLineFailed: l10nLineFailed,
    l10nLinePending: l10nLinePending,
  );
}

void main() {
  group('resolveAutoTranslateTextForDisplay', () {
    group('autoTranslateActive=false (echo / echo-match path)', () {
      test('falls back to matcher.match(line).text', () {
        final primary = [cue(0, 2000, 'hola')];
        final echoSecondary = [cue(500, 1500, 'hello world')];
        final matcher = TranscriptSecondaryMatcher.from(echoSecondary);
        final result = callResolve(
          autoTranslateActive: false,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, 'hello world');
        expect(result.canRetranslate, isFalse);
        expect(result.isFailed, isFalse);
        expect(result.isInFlight, isFalse);
      });

      test('secondaryText is null when matcher returns null', () {
        final primary = [cue(0, 2000, 'hola')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: false,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {0},
          inFlightIndexes: const {0},
        );
        expect(result.secondaryText, isNull);
        // Even with failed/inFlight flags set, isFailed / isInFlight are
        // suppressed when autoTranslateActive is false — only the
        // auto-translate overlay surfaces them.
        expect(result.isFailed, isFalse);
        expect(result.isInFlight, isFalse);
        expect(result.canRetranslate, isFalse);
      });
    });

    group('autoTranslateActive=true with sourceKey enforcement', () {
      test('returns ai text when sourceKey matches', () {
        final primary = [cue(0, 2000, 'hola')];
        const src = 'es';
        const tgt = 'en';
        final key = autoTranslateSourceKey(
          primaryText: 'hola',
          sourceLanguage: src,
          targetLanguage: tgt,
        );
        final ai = [cue(0, 2000, 'hello', sourceKey: key)];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 0,
          sourceLanguage: src,
          targetLanguage: tgt,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, 'hello');
        expect(result.canRetranslate, isTrue);
      });

      test('returns null when sourceKey mismatches (soft-stale)', () {
        final primary = [cue(0, 2000, 'hola')];
        final ai = [cue(0, 2000, 'hello', sourceKey: 'stale-key')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 0,
          sourceLanguage: 'es',
          targetLanguage: 'en',
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, isNull);
      });

      test(
        'returns null when sourceLanguage provided but ai slot lacks sourceKey',
        () {
          final primary = [cue(0, 2000, 'hola')];
          final ai = [cue(0, 2000, 'hello')];
          final matcher = TranscriptSecondaryMatcher.from(const []);
          final result = callResolve(
            autoTranslateActive: true,
            primaryLines: primary,
            aiLines: ai,
            lineIndex: 0,
            sourceLanguage: 'es',
            targetLanguage: 'en',
            matcher: matcher,
            line: primary.first,
            failedIndexes: const {},
            inFlightIndexes: const {},
          );
          expect(result.secondaryText, isNull);
        },
      );

      test('skips sourceKey check when neither language is provided', () {
        final primary = [cue(0, 2000, 'hola')];
        final ai = [cue(0, 2000, 'hello')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, 'hello');
      });

      test(
        'skips sourceKey check when only one of the languages is provided',
        () {
          final primary = [cue(0, 2000, 'hola')];
          final ai = [cue(0, 2000, 'hello')];
          final matcher = TranscriptSecondaryMatcher.from(const []);
          final result = callResolve(
            autoTranslateActive: true,
            primaryLines: primary,
            aiLines: ai,
            lineIndex: 0,
            sourceLanguage: 'es',
            matcher: matcher,
            line: primary.first,
            failedIndexes: const {},
            inFlightIndexes: const {},
          );
          expect(result.secondaryText, 'hello');
        },
      );
    });

    group('bounds and empty text', () {
      test('returns null when lineIndex is out of primary range', () {
        final primary = [cue(0, 2000, 'a'), cue(2000, 2000, 'b')];
        final ai = [cue(0, 2000, 'A'), cue(2000, 2000, 'B')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 5,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, isNull);
      });

      test('returns null when aiLines shorter than lineIndex', () {
        final primary = [cue(0, 2000, 'a'), cue(2000, 2000, 'b')];
        final ai = [cue(0, 2000, 'A')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 1,
          matcher: matcher,
          line: primary.last,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, isNull);
      });

      test('returns null when ai slot text is whitespace-only', () {
        final primary = [cue(0, 2000, 'hola')];
        final ai = [cue(0, 2000, '   ')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, isNull);
      });
    });

    group('l10n fallback for empty secondary text', () {
      const failedL10n = '[failed]';
      const pendingL10n = '[pending]';

      test('uses l10nLineFailed when failed flag is set and raw is empty', () {
        final primary = [cue(0, 2000, 'hola')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {0},
          inFlightIndexes: const {},
          l10nLineFailed: failedL10n,
          l10nLinePending: pendingL10n,
        );
        expect(result.secondaryText, failedL10n);
        expect(result.isFailed, isTrue);
        expect(result.isInFlight, isFalse);
        expect(result.canRetranslate, isTrue);
      });

      test(
        'uses l10nLinePending when inFlight (and not failed) and raw is empty',
        () {
          final primary = [cue(0, 2000, 'hola')];
          final matcher = TranscriptSecondaryMatcher.from(const []);
          final result = callResolve(
            autoTranslateActive: true,
            primaryLines: primary,
            aiLines: const [],
            lineIndex: 0,
            matcher: matcher,
            line: primary.first,
            failedIndexes: const {},
            inFlightIndexes: const {0},
            l10nLineFailed: failedL10n,
            l10nLinePending: pendingL10n,
          );
          expect(result.secondaryText, pendingL10n);
          expect(result.isFailed, isFalse);
          expect(result.isInFlight, isTrue);
        },
      );

      test('failed wins over inFlight when both flags are set', () {
        final primary = [cue(0, 2000, 'hola')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {0},
          inFlightIndexes: const {0},
          l10nLineFailed: failedL10n,
          l10nLinePending: pendingL10n,
        );
        expect(result.secondaryText, failedL10n);
        expect(result.isFailed, isTrue);
        expect(result.isInFlight, isTrue);
      });

      test('returns null when raw empty and l10nLineFailed is null', () {
        final primary = [cue(0, 2000, 'hola')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {0},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, isNull);
        expect(result.isFailed, isTrue);
        expect(result.canRetranslate, isTrue);
      });

      test('non-empty raw is preserved even when failed flag is set', () {
        final primary = [cue(0, 2000, 'hola')];
        final ai = [cue(0, 2000, 'hello')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {0},
          inFlightIndexes: const {},
          l10nLineFailed: failedL10n,
          l10nLinePending: pendingL10n,
        );
        expect(result.secondaryText, 'hello');
        expect(result.isFailed, isTrue);
      });

      test('raw is preserved when empty AND neither failed nor inFlight', () {
        final primary = [cue(0, 2000, 'hola')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
          l10nLineFailed: failedL10n,
          l10nLinePending: pendingL10n,
        );
        // Empty raw + no flags → display stays null (no fallback).
        expect(result.secondaryText, isNull);
      });
    });

    group('canRetranslate semantics', () {
      test('false when autoTranslateActive is false', () {
        final primary = [cue(0, 2000, 'hola')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: false,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.canRetranslate, isFalse);
      });

      test('true when failed=true regardless of display text', () {
        final primary = [cue(0, 2000, 'hola')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: const [],
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {0},
          inFlightIndexes: const {},
        );
        expect(result.canRetranslate, isTrue);
      });

      test('true when display has non-empty trimmed text', () {
        final primary = [cue(0, 2000, 'hola')];
        final ai = [cue(0, 2000, 'hello')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, 'hello');
        expect(result.canRetranslate, isTrue);
      });

      test('false when not failed AND display is whitespace-only', () {
        final primary = [cue(0, 2000, 'hola')];
        final ai = [cue(0, 2000, '   ')];
        final matcher = TranscriptSecondaryMatcher.from(const []);
        final result = callResolve(
          autoTranslateActive: true,
          primaryLines: primary,
          aiLines: ai,
          lineIndex: 0,
          matcher: matcher,
          line: primary.first,
          failedIndexes: const {},
          inFlightIndexes: const {},
        );
        expect(result.secondaryText, isNull);
        expect(result.canRetranslate, isFalse);
      });
    });
  });
}
