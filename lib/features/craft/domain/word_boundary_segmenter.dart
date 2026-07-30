/// Segments word-level timing data from Azure TTS into shadow-friendly chunks.
///
/// Lines are sized for shadow-reading practice: each line targets a spoken
/// duration a learner can echo in one breath (roughly 1.5–6 s, capped at 7 s),
/// breaking at the most natural speech boundary available — sentence end,
/// clause punctuation, or the largest inter-word silence — rather than an
/// arbitrary word count. CJK text (zh/ja/ko) breaks by punctuation + duration
/// only, never by word count. See `specs/032-craft-shadow-cues/research.md`.
library;

import 'dart:convert';

import 'package:enjoy_player/core/application/cjk_language.dart';
import 'package:enjoy_player/features/craft/domain/craft_synthesizer.dart';

/// One transcript segment: a chunk of text with audio timing.
class TranscriptSegment {
  const TranscriptSegment({
    required this.text,
    required this.startMs,
    required this.durationMs,
  });

  final String text;
  final int startMs;
  final int durationMs;
}

/// Shadow-friendly duration thresholds (milliseconds).
///
/// Derived from applied-linguistics research on shadowing / shadow reading
/// (research.md §R1–R7): a repeatable unit is one thought/breath group.
/// Beginners echo at the short end; the soft max serves advanced learners.
class ShadowLineBudget {
  const ShadowLineBudget({
    this.minLineMs = 1200,
    this.softMaxMs = 6000,
    this.hardMaxMs = 7000,
    this.pauseGapMs = 250,
  });

  /// Absolute floor for a standalone line; shorter fragments merge into a
  /// neighbor so no line is a lone token / function-word run.
  final int minLineMs;

  /// Preferred split point — accumulate words while the spoken span is below
  /// this and break at the best natural boundary.
  final int softMaxMs;

  /// Hard ceiling — no line may exceed this duration.
  final int hardMaxMs;

  /// Minimum inter-word silence to count as a meaningful pause break point.
  final int pauseGapMs;

  static const ShadowLineBudget defaults = ShadowLineBudget();
}

/// Priority order for choosing a split point inside a long sentence (FR-004).
enum BreakPriority {
  /// `.。！？!?` — already handled by sentence partitioning, highest priority.
  sentenceEnd,

  /// `,;:—、，；：` — clause / phrase punctuation (FR-005).
  clauseMark,

  /// Largest inter-word silence ≥ [ShadowLineBudget.pauseGapMs].
  silenceGap,

  /// Forced split at [ShadowLineBudget.hardMaxMs] when nothing else applies.
  hardCap,
}

final _sentenceEnd = RegExp(r'[.。！？!?]\s*$');
// Any token made solely of sentence-ending OR clause punctuation. Azure emits
// both kinds as standalone tokens (contract: azure-speech-word-boundaries.md);
// merging them onto the prior word keeps joined text clean ("word," not "word ,")
// and satisfies FR-007 (no line begins with punctuation-only text).
final _punctuationOnly = RegExp(r'^[.。！？!?,;:—、，；：]+$');
final _clauseEnd = RegExp(r'[,;:—、，；：]\s*$');

/// Whether [text] is sentence-ending / clause punctuation with no letters.
bool isPunctuationOnlyToken(String text) =>
    _punctuationOnly.hasMatch(text.trim());

/// Merges punctuation-only tokens onto the previous word and extends timing
/// so punctuation never starts a segment alone.
List<CraftWordBoundary> mergePunctuationTokens(
  List<CraftWordBoundary> wordBoundaries,
) {
  if (wordBoundaries.isEmpty) return const [];

  final merged = <CraftWordBoundary>[];
  for (final token in wordBoundaries) {
    final trimmed = token.text.trim();
    if (trimmed.isEmpty) continue;

    if (isPunctuationOnlyToken(trimmed)) {
      if (merged.isEmpty) {
        // Leading punct with no prior word — skip so a line cannot start with it.
        continue;
      }
      final prev = merged.removeLast();
      final prevEnd = prev.audioOffsetMs + prev.durationMs;
      final punctEnd = token.audioOffsetMs + token.durationMs;
      final newEnd = punctEnd > prevEnd ? punctEnd : prevEnd;
      merged.add(
        CraftWordBoundary(
          text: '${prev.text}$trimmed',
          audioOffsetMs: prev.audioOffsetMs,
          durationMs: newEnd - prev.audioOffsetMs,
        ),
      );
      continue;
    }

    merged.add(token);
  }
  return merged;
}

/// Splits word boundaries into segments sized for shadow-reading practice.
///
/// Algorithm (data-model.md §3):
/// 1. Merge standalone punctuation tokens onto the previous word (FR-007).
/// 2. Partition into sentences at sentence-ending punctuation.
/// 3. Per sentence, accumulate words while the spoken span < [budget.softMaxMs];
///    on overflow, break at the highest-priority natural boundary
///    (clause mark > largest silence > hard cap).
/// 4. Merge any standalone line shorter than [ShadowLineBudget.minLineMs]
///    into a neighbor.
///
/// For CJK languages (zh/ja/ko), word count is never used; breaks follow
/// punctuation + duration + silence gaps only (FR-006).
///
/// Returns an empty list if [wordBoundaries] is empty or only punctuation.
List<TranscriptSegment> segmentWordBoundaries(
  List<CraftWordBoundary> wordBoundaries, {
  String? language,
  ShadowLineBudget budget = ShadowLineBudget.defaults,
}) {
  final words = mergePunctuationTokens(wordBoundaries);
  if (words.isEmpty) return [];

  final cjk = language != null && isCjkLanguage(language);

  // Partition into sentence groups at sentence-ending punctuation.
  final sentences = <List<CraftWordBoundary>>[];
  var current = <CraftWordBoundary>[];
  for (final word in words) {
    current.add(word);
    if (_sentenceEnd.hasMatch(word.text)) {
      sentences.add(current);
      current = [];
    }
  }
  if (current.isNotEmpty) sentences.add(current);

  // Shadow-split each sentence, then merge too-short fragments WITHIN that
  // sentence only (never across sentence boundaries — a short complete
  // sentence stays a standalone line).
  final lines = <List<CraftWordBoundary>>[];
  for (final sentence in sentences) {
    final sentenceLines = _shadowSplitSentence(
      sentence,
      budget: budget,
      cjk: cjk,
    );
    _mergeShortFragments(sentenceLines, budget: budget);
    lines.addAll(sentenceLines);
  }
  if (lines.isEmpty) return [];

  // Build segments from the surviving word groups.
  return [
    for (final group in lines)
      TranscriptSegment(
        text: _joinText(group, cjk: cjk),
        startMs: group.first.audioOffsetMs,
        durationMs:
            (group.last.audioOffsetMs + group.last.durationMs) -
            group.first.audioOffsetMs,
      ),
  ];
}

/// Joins word texts, spaceless for CJK scripts.
String _joinText(List<CraftWordBoundary> words, {required bool cjk}) {
  return words.map((w) => w.text).join(cjk ? '' : ' ').trim();
}

/// Splits a single sentence (no internal sentence-end) into shadow-friendly
/// line groups.
List<List<CraftWordBoundary>> _shadowSplitSentence(
  List<CraftWordBoundary> sentence, {
  required ShadowLineBudget budget,
  required bool cjk,
}) {
  if (sentence.isEmpty) return const [];

  final lines = <List<CraftWordBoundary>>[];
  var start = 0;

  while (start < sentence.length) {
    // Grow the line until it would exceed the soft max.
    var end = start;
    var lineEndMs = sentence[start].audioOffsetMs + sentence[start].durationMs;
    while (end + 1 < sentence.length) {
      final next = sentence[end + 1];
      final nextEnd = next.audioOffsetMs + next.durationMs;
      if (nextEnd - sentence[start].audioOffsetMs > budget.softMaxMs) break;
      end++;
      lineEndMs = lineEndMs > nextEnd ? lineEndMs : nextEnd;
    }

    // If the remainder fits in one line, take it all.
    if (end == sentence.length - 1) {
      lines.add(sentence.sublist(start));
      break;
    }

    // Try to break at a clause mark within [start, end].
    final clauseBreak = _lastClauseBreak(sentence, start, end);
    if (clauseBreak != -1) {
      lines.add(sentence.sublist(start, clauseBreak + 1));
      start = clauseBreak + 1;
      continue;
    }

    // Try the largest silence gap within [start, end+1].
    final gapBreak = _largestGapBreak(sentence, start, end + 1, budget);
    if (gapBreak != -1) {
      lines.add(sentence.sublist(start, gapBreak + 1));
      start = gapBreak + 1;
      continue;
    }

    // Force a split at the soft-max boundary (hardCap fallback).
    lines.add(sentence.sublist(start, end + 1));
    start = end + 1;
  }

  return lines;
}

/// Index of the last word in [start..end] ending with clause punctuation.
int _lastClauseBreak(List<CraftWordBoundary> words, int start, int end) {
  for (var i = end; i >= start; i--) {
    if (_clauseEnd.hasMatch(words[i].text)) return i;
  }
  return -1;
}

/// Index of the word *before* the largest inter-word silence gap in
/// [start..end-1], or -1 if no gap ≥ [ShadowLineBudget.pauseGapMs].
int _largestGapBreak(
  List<CraftWordBoundary> words,
  int start,
  int end,
  ShadowLineBudget budget,
) {
  var bestGap = budget.pauseGapMs;
  var bestIdx = -1;
  for (var i = start; i < end - 1; i++) {
    final thisEnd = words[i].audioOffsetMs + words[i].durationMs;
    final nextStart = words[i + 1].audioOffsetMs;
    final gap = nextStart - thisEnd;
    if (gap >= bestGap) {
      bestGap = gap;
      bestIdx = i;
    }
  }
  return bestIdx;
}

/// Merges any standalone line shorter than [ShadowLineBudget.minLineMs] into
/// an adjacent neighbor, preferring the previous line. Does not merge if the
/// combined span would exceed [ShadowLineBudget.hardMaxMs].
void _mergeShortFragments(
  List<List<CraftWordBoundary>> lines, {
  required ShadowLineBudget budget,
}) {
  var i = 0;
  while (i < lines.length) {
    final line = lines[i];
    final span =
        (line.last.audioOffsetMs + line.last.durationMs) -
        line.first.audioOffsetMs;
    if (span >= budget.minLineMs || lines.length <= 1) {
      i++;
      continue;
    }
    // Try merging into the previous line if the combined span fits hardMax.
    if (i > 0) {
      final prev = lines[i - 1];
      final combinedEnd = line.last.audioOffsetMs + line.last.durationMs;
      if (combinedEnd - prev.first.audioOffsetMs <= budget.hardMaxMs) {
        lines[i - 1] = [...prev, ...line];
        lines.removeAt(i);
        continue;
      }
    }
    // Try merging into the next line.
    if (i + 1 < lines.length) {
      final next = lines[i + 1];
      final nextEnd = next.last.audioOffsetMs + next.last.durationMs;
      if (nextEnd - line.first.audioOffsetMs <= budget.hardMaxMs) {
        lines[i + 1] = [...line, ...next];
        lines.removeAt(i);
        continue;
      }
    }
    i++;
  }
}

/// Encodes the segments as a JSON string for the Drift `timelineJson` column.
String segmentsToTimelineJson(List<TranscriptSegment> segments) {
  return jsonEncode(
    segments
        .map(
          (s) => {'text': s.text, 'start': s.startMs, 'duration': s.durationMs},
        )
        .toList(),
  );
}

/// Builds Craft primary `timelineJson` when timings are solid.
///
/// Returns `null` when [wordBoundaries] is empty or segmentation yields no
/// valid lines (blank transcript — learner generates via STT in the player).
String? buildCraftPrimaryTimelineJson(
  List<CraftWordBoundary> wordBoundaries, {
  String? language,
}) {
  final segments = segmentWordBoundaries(wordBoundaries, language: language);
  if (segments.isEmpty) return null;
  return segmentsToTimelineJson(segments);
}
