/// Map a successful [AlignmentResult] onto spec 030 [TranscriptLine]s.
library;

import 'dart:math' as math;

import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';

/// Attaches nested word/phone spans onto [lines] without changing line
/// identity (`text`, `startMs`, `durationMs`, `sourceKey`, `confidence`).
///
/// Segment `id` is the line index. Word times become milliseconds relative
/// to the parent line. Phone times stay in media-timeline seconds.
/// `wordIndex` is rebased per line. Empty timelines are omitted (`null`).
List<TranscriptLine> attachAlignmentToLines(
  List<TranscriptLine> lines,
  AlignmentResult result,
) {
  if (lines.isEmpty) return lines;

  final segmentsById = <int, TimelineEntry>{};
  for (final entry in result.timeline) {
    if (entry.type != TimelineEntryType.segment) continue;
    final id = entry.id;
    if (id is int) {
      segmentsById[id] = entry;
    }
  }

  return [
    for (var i = 0; i < lines.length; i++)
      _attachOne(
        line: lines[i],
        isLast: i == lines.length - 1,
        tagged: segmentsById[i],
        result: result,
      ),
  ];
}

TranscriptLine _attachOne({
  required TranscriptLine line,
  required bool isLast,
  required TimelineEntry? tagged,
  required AlignmentResult result,
}) {
  final engineWords = tagged != null
      ? _collectWords(tagged)
      : _wordsInWindow(line, result, isLast: isLast);
  if (engineWords.isEmpty) return line;

  final words = <TranscriptWord>[];
  for (final engineWord in engineWords) {
    final text = engineWord.text.trim();
    if (text.isEmpty) continue;
    final startMs = math.max(
      0,
      ((engineWord.startTime - line.startSeconds) * 1000).round(),
    );
    final durationMs = math.max(
      0,
      ((engineWord.endTime - engineWord.startTime) * 1000).round(),
    );
    final wordIndex = words.length;
    final phones = _phonesForWord(engineWord, wordIndex);
    words.add(
      TranscriptWord(
        text: text,
        startMs: startMs,
        durationMs: durationMs,
        phones: phones,
      ),
    );
  }
  if (words.isEmpty) return line;

  return TranscriptLine(
    text: line.text,
    startMs: line.startMs,
    durationMs: line.durationMs,
    sourceKey: line.sourceKey,
    confidence: line.confidence,
    timeline: words,
  );
}

List<TimelineEntry> _collectWords(TimelineEntry root) {
  final out = <TimelineEntry>[];
  void walk(TimelineEntry entry) {
    if (entry.type == TimelineEntryType.word) {
      if (entry.text.trim().isNotEmpty) {
        out.add(entry);
      }
      return;
    }
    final children = entry.timeline;
    if (children == null) return;
    for (final child in children) {
      walk(child);
    }
  }

  walk(root);
  return out;
}

List<TimelineEntry> _allWords(AlignmentResult result) {
  final fromTree = [
    for (final entry in result.timeline) ..._collectWords(entry),
  ];
  if (fromTree.isNotEmpty) return fromTree;
  return [
    for (final entry in result.wordTimeline)
      if (entry.type == TimelineEntryType.word && entry.text.trim().isNotEmpty)
        entry,
  ];
}

List<TimelineEntry> _wordsInWindow(
  TranscriptLine line,
  AlignmentResult result, {
  required bool isLast,
}) {
  final start = line.startSeconds;
  final end = line.endSeconds;
  return [
    for (final word in _allWords(result))
      if (_startInWindow(word.startTime, start, end, isLast: isLast)) word,
  ];
}

bool _startInWindow(
  double t,
  double start,
  double end, {
  required bool isLast,
}) {
  if (t < start) return false;
  if (isLast) return t <= end;
  return t < end;
}

List<TranscriptPhone>? _phonesForWord(TimelineEntry word, int wordIndex) {
  final children = word.timeline;
  if (children == null || children.isEmpty) return null;
  final phones = <TranscriptPhone>[];
  for (final child in children) {
    if (child.type != TimelineEntryType.phone) continue;
    final label = child.text.trim();
    if (label.isEmpty) continue;
    phones.add(
      TranscriptPhone(
        phone: label,
        text: label,
        startTime: child.startTime,
        endTime: child.endTime,
        wordIndex: wordIndex,
      ),
    );
  }
  return phones.isEmpty ? null : phones;
}
