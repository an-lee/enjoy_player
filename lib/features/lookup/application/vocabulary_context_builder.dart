/// Builds transcript context for lookup AI and vocabulary persistence.
library;

import 'dart:math' as math;

import 'package:enjoy_player/core/utils/text_normalization.dart';
import 'package:enjoy_player/data/subtitle/subtitle_markup_parser.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/lookup/application/sentence_boundaries.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_cue_selection.dart';

/// Resolved context span: joined text plus inclusive line indexes.
typedef VocabularyContextSpan = ({
  String text,
  int startLineIndex,
  int endLineIndex,
});

/// How many cues to walk backward/forward from the seed line when searching
/// for sentence boundaries, and the hard cap when the transcript has no
/// punctuation (so context never becomes the full echo / transcript).
const int kVocabularyContextLineRadius = 3;

String plainCueText(String raw) {
  return collapseWhitespace(raw.replaceAll(tagStripRegExp, ''));
}

({int startArrayIndex, int endArrayIndex}) expandContextLines(
  int startArrayIndex,
  int endArrayIndex,
  int lineCount, {
  int radius = kVocabularyContextLineRadius,
}) {
  var expandedStart = startArrayIndex;
  var expandedEnd = endArrayIndex;

  final backwardExpansion = math.min(radius, startArrayIndex);
  for (var i = 0; i < backwardExpansion; i++) {
    if (expandedStart > 0) expandedStart--;
  }

  final forwardExpansion = math.min(radius, lineCount - 1 - endArrayIndex);
  for (var i = 0; i < forwardExpansion; i++) {
    if (expandedEnd < lineCount - 1) expandedEnd++;
  }

  return (startArrayIndex: expandedStart, endArrayIndex: expandedEnd);
}

/// True when [text] contains more than one sentence (or a sentence plus more).
bool isMoreThanOneSentence(String text, String primaryLanguage) {
  final boundaries = getSentenceBoundaries(text, primaryLanguage);
  if (boundaries.length >= 2) return true;
  if (boundaries.length == 1) {
    return text.substring(boundaries.first).trim().isNotEmpty;
  }
  return false;
}

/// Returns surrounding transcript text for contextual translation (LLM).
String? buildVocabularyContext({
  required List<TranscriptLine> lines,
  required EchoState echo,
  required double currentTimeSeconds,
  required String primaryLanguage,
}) => resolveVocabularyContextSpan(
  lines: lines,
  echo: echo,
  currentTimeSeconds: currentTimeSeconds,
  primaryLanguage: primaryLanguage,
)?.text;

/// Resolves context text and the inclusive cue line range used to build it.
///
/// Rules:
/// 1. Prefer a **complete sentence** containing the seed cue (active line).
/// 2. If echo is active and the echo region itself is **more than one sentence**,
///    use the full echo region (do not shrink to a single sentence).
/// 3. Expansion / no-punctuation fallback is always seeded from a **single**
///    cue and capped at ±[kVocabularyContextLineRadius] lines — never the
///    unbounded echo window or full transcript.
VocabularyContextSpan? resolveVocabularyContextSpan({
  required List<TranscriptLine> lines,
  required EchoState echo,
  required double currentTimeSeconds,
  required String primaryLanguage,
}) {
  if (lines.isEmpty) return null;

  final echoValid =
      echo.active &&
      echo.startLineIndex >= 0 &&
      echo.endLineIndex >= 0 &&
      echo.startLineIndex < lines.length &&
      echo.endLineIndex < lines.length &&
      echo.startLineIndex <= echo.endLineIndex;

  if (echoValid) {
    final echoText = _joinLines(lines, echo.startLineIndex, echo.endLineIndex);
    if (echoText != null && isMoreThanOneSentence(echoText, primaryLanguage)) {
      return (
        text: echoText,
        startLineIndex: echo.startLineIndex,
        endLineIndex: echo.endLineIndex,
      );
    }
  }

  final activeIdx = transcriptActiveIndex(lines, currentTimeSeconds);
  // Seed from one cue so ±radius cannot grow with a large echo span.
  final seedIdx = activeIdx >= 0
      ? activeIdx
      : (echoValid ? echo.startLineIndex : -1);
  if (seedIdx < 0) return null;

  final expanded = expandContextLines(seedIdx, seedIdx, lines.length);
  final expStart = expanded.startArrayIndex;
  final expEnd = expanded.endArrayIndex;
  final expandedLines = lines.sublist(expStart, expEnd + 1);
  if (expandedLines.isEmpty) return null;

  final expandedText = expandedLines.map((l) => plainCueText(l.text)).join(' ');
  if (expandedText.isEmpty) return null;

  final sentenceBoundaries = getSentenceBoundaries(
    expandedText,
    primaryLanguage,
  );

  // No terminators — keep the bounded ±radius window (not the full echo).
  if (sentenceBoundaries.isEmpty) {
    return _fallbackSpan(lines, expStart, expEnd);
  }

  var charIndex = 0;
  final lineCharPositions = <({int start, int end, int lineIndex})>[];
  for (var i = 0; i < expandedLines.length; i++) {
    final line = expandedLines[i];
    final plain = plainCueText(line.text);
    final lineStart = charIndex;
    charIndex += plain.length;
    final lineEnd = charIndex;
    lineCharPositions.add((
      start: lineStart,
      end: lineEnd,
      lineIndex: expStart + i,
    ));
    if (i < expandedLines.length - 1) {
      charIndex += 1;
    }
  }

  final baseLineIndex = seedIdx - expStart;
  if (baseLineIndex < 0 || baseLineIndex >= lineCharPositions.length) {
    return _fallbackSpan(lines, expStart, expEnd);
  }

  final baseStartCharIndex = lineCharPositions[baseLineIndex].start;
  final baseEndCharIndex = lineCharPositions[baseLineIndex].end;

  var sentenceStartCharIndex = 0;
  var sentenceEndCharIndex = expandedText.length;

  var prevBoundary = 0;
  for (var i = 0; i < sentenceBoundaries.length; i++) {
    if (sentenceBoundaries[i] > baseStartCharIndex) {
      sentenceStartCharIndex = prevBoundary;
      break;
    }
    prevBoundary = sentenceBoundaries[i];
  }
  if (baseStartCharIndex >= sentenceBoundaries.last) {
    sentenceStartCharIndex = sentenceBoundaries.last;
  }

  for (var i = 0; i < sentenceBoundaries.length; i++) {
    if (sentenceBoundaries[i] >= baseEndCharIndex) {
      sentenceEndCharIndex = sentenceBoundaries[i];
      break;
    }
  }
  if (baseEndCharIndex > sentenceBoundaries.last) {
    sentenceEndCharIndex = sentenceBoundaries.last;
  }

  var contextStartLineIndex = expStart;
  var contextEndLineIndex = expEnd;

  for (var i = 0; i < lineCharPositions.length; i++) {
    final pos = lineCharPositions[i];
    final lineRangeEnd = i < lineCharPositions.length - 1
        ? lineCharPositions[i + 1].start
        : pos.end + 1;
    if (pos.start <= sentenceStartCharIndex &&
        sentenceStartCharIndex < lineRangeEnd) {
      contextStartLineIndex = pos.lineIndex;
      break;
    }
  }

  for (var i = lineCharPositions.length - 1; i >= 0; i--) {
    final pos = lineCharPositions[i];
    final lineRangeEnd = i < lineCharPositions.length - 1
        ? lineCharPositions[i + 1].start
        : pos.end + 1;
    if (pos.start < sentenceEndCharIndex &&
        sentenceEndCharIndex <= lineRangeEnd) {
      contextEndLineIndex = pos.lineIndex;
      break;
    }
  }

  if (contextStartLineIndex < 0) {
    contextStartLineIndex = expStart;
  }
  if (contextEndLineIndex >= lines.length) {
    contextEndLineIndex = expEnd;
  }
  if (contextStartLineIndex > contextEndLineIndex) {
    return _fallbackSpan(lines, expStart, expEnd);
  }

  final endExclusive = math.min(contextEndLineIndex + 1, lines.length);
  if (contextStartLineIndex < 0 || contextStartLineIndex >= endExclusive) {
    return _fallbackSpan(lines, expStart, expEnd);
  }

  final text = _joinLines(lines, contextStartLineIndex, contextEndLineIndex);
  if (text == null) {
    return _fallbackSpan(lines, expStart, expEnd);
  }
  return (
    text: text,
    startLineIndex: contextStartLineIndex,
    endLineIndex: contextEndLineIndex,
  );
}

VocabularyContextSpan? _fallbackSpan(
  List<TranscriptLine> lines,
  int start,
  int end,
) {
  final text = _joinLines(lines, start, end);
  if (text == null) return null;
  return (text: text, startLineIndex: start, endLineIndex: end);
}

String? _joinLines(List<TranscriptLine> lines, int start, int end) {
  if (start < 0 || end >= lines.length || start > end) return null;
  final buf = StringBuffer();
  for (var i = start; i <= end; i++) {
    if (i > start) buf.write(' ');
    buf.write(plainCueText(lines[i].text));
  }
  final s = buf.toString().trim();
  return s.isEmpty ? null : s;
}
