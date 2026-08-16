/// Pure current-word matching for karaoke highlight (no Flutter).
library;

import 'package:meta/meta.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';

/// UTF-16 offsets into plain (markup-stripped) line text.
@immutable
class WordTextRange {
  const WordTextRange({required this.start, required this.end});

  final int start;
  final int end;

  bool get isValid => start >= 0 && end > start;
}

/// Index of the timed word whose media window contains [positionMs].
///
/// Word windows are `[line.startMs + word.startMs, + duration)`. Overlaps
/// pick the last matching index. Returns null when karaoke should not paint.
int? currentWordIndex(TranscriptLine line, int positionMs) {
  final words = line.timeline;
  if (words == null || words.isEmpty) return null;
  final lineStart = line.startMs;
  final lineEnd = line.startMs + line.durationMs;
  int? last;
  for (var i = 0; i < words.length; i++) {
    final word = words[i];
    if (word.text.trim().isEmpty || word.durationMs <= 0) continue;
    final start = lineStart + word.startMs;
    final end = start + word.durationMs;
    if (end <= lineStart || start >= lineEnd) continue;
    if (positionMs >= start && positionMs < end) {
      last = i;
    }
  }
  return last;
}

/// Sequential substring range for [words]\[index] inside [plain].
WordTextRange? wordHighlightRange(
  String plain,
  List<TranscriptWord>? words,
  int index,
) {
  if (words == null || index < 0 || index >= words.length) return null;
  var cursor = 0;
  WordTextRange? found;
  for (var i = 0; i < words.length; i++) {
    final token = words[i].text;
    if (token.isEmpty) {
      if (i == index) return null;
      continue;
    }
    final at = plain.indexOf(token, cursor);
    if (at < 0) {
      if (i == index) return null;
      continue;
    }
    final range = WordTextRange(start: at, end: at + token.length);
    cursor = range.end;
    if (i == index) found = range;
  }
  return found?.isValid == true ? found : null;
}

/// Sequential substring ranges for every word in [plain], aligned with
/// [wordHighlightRange]. Missing tokens are omitted (`null` at that index).
List<WordTextRange?> allWordTextRanges(
  String plain,
  List<TranscriptWord>? words,
) {
  if (words == null || words.isEmpty) return const [];
  final out = List<WordTextRange?>.filled(words.length, null);
  var cursor = 0;
  for (var i = 0; i < words.length; i++) {
    final token = words[i].text;
    if (token.isEmpty) continue;
    final at = plain.indexOf(token, cursor);
    if (at < 0) continue;
    final range = WordTextRange(start: at, end: at + token.length);
    cursor = range.end;
    if (range.isValid) out[i] = range;
  }
  return out;
}

/// Word index whose sequential plain-text range contains [offset], or null.
int? wordIndexAtPlainOffset(
  String plain,
  List<TranscriptWord>? words,
  int offset,
) {
  if (words == null || offset < 0 || offset > plain.length) return null;
  final ranges = allWordTextRanges(plain, words);
  int? last;
  for (var i = 0; i < ranges.length; i++) {
    final range = ranges[i];
    if (range == null || !range.isValid) continue;
    if (offset >= range.start && offset < range.end) {
      last = i;
    }
  }
  return last;
}

/// Media-timeline window `[start, end)` for a timed word, or null if the word
/// is not a seek/loop target (empty text, non-positive duration, or entirely
/// outside the parent line).
({int startMs, int endMs})? wordMediaWindowMs(
  TranscriptLine line,
  int wordIndex,
) {
  final words = line.timeline;
  if (words == null || wordIndex < 0 || wordIndex >= words.length) return null;
  final word = words[wordIndex];
  if (word.text.trim().isEmpty || word.durationMs <= 0) return null;
  final lineStart = line.startMs;
  final lineEnd = line.startMs + line.durationMs;
  final start = lineStart + word.startMs;
  final end = start + word.durationMs;
  if (end <= lineStart || start >= lineEnd) return null;
  return (startMs: start, endMs: end);
}
