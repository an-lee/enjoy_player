/// Pure function that turns an [AsrResult] into time-aligned
/// [TranscriptLine]s.
///
/// Mirrors the webapp's `transcript-segmentation` pipeline (per the spec):
///
/// 1. **Word-level** when [AsrSegment.words] is non-empty with timings —
///    group consecutive words until `maxLineDurationMs` / `maxLineChars`
///    / a sentence terminator / a long pause (> 350 ms) is reached.
/// 2. **Segment-level** fallback when no words are present — coalesce
///    adjacent short segments until `minLineDurationMs` or a terminator
///    or `maxLineDurationMs`.
/// 3. **Plain-text** fallback when no timings are available — distribute
///    evenly across [mediaDurationMs] with one line per terminator or
///    `maxLineChars`.
/// 4. **Empty input** — return `[]`; the controller surfaces a friendly
///    "no speech detected" message and does **not** persist a row.
///
/// The function is intentionally deterministic: identical input +
/// duration → identical output. This guarantees SC-004 (re-generation
/// produces byte-equal `timelineJson` for the same input).
library;

import 'package:enjoy_player/core/utils/text_normalization.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/ai/domain/models/asr_result.dart';

const _sentenceTerminators = <String>{'.', '?', '!', '。', '？', '！'};

const int _kDefaultMinLineDurationMs = 800;
const int _kDefaultMaxLineDurationMs = 6000;
const int _kDefaultMaxLineChars = 140;
const int _kDefaultPauseThresholdMs = 350;

List<TranscriptLine> buildAsrTranscriptLines({
  required AsrResult result,
  required int mediaDurationMs,
  int minLineDurationMs = _kDefaultMinLineDurationMs,
  int maxLineDurationMs = _kDefaultMaxLineDurationMs,
  int maxLineChars = _kDefaultMaxLineChars,
  int pauseThresholdMs = _kDefaultPauseThresholdMs,
}) {
  if (result.text.trim().isEmpty &&
      (result.segments == null || result.segments!.isEmpty)) {
    return const <TranscriptLine>[];
  }

  final segments = result.segments;
  if (segments != null && segments.isNotEmpty) {
    final firstWithWords = segments
        .where((s) => s.words != null && s.words!.isNotEmpty)
        .firstOrNull;
    if (firstWithWords != null) {
      return _groupFromWords(
        segments: segments,
        maxLineDurationMs: maxLineDurationMs,
        maxLineChars: maxLineChars,
        pauseThresholdMs: pauseThresholdMs,
      );
    }
    return _groupFromSegments(
      segments: segments,
      maxLineDurationMs: maxLineDurationMs,
      maxLineChars: maxLineChars,
    );
  }

  return _distributePlainText(
    text: result.text,
    mediaDurationMs: mediaDurationMs,
    maxLineChars: maxLineChars,
  );
}

List<TranscriptLine> _groupFromWords({
  required List<AsrSegment> segments,
  required int maxLineDurationMs,
  required int maxLineChars,
  required int pauseThresholdMs,
}) {
  final words = <_Word>[];
  for (final seg in segments) {
    final ws = seg.words;
    if (ws == null) continue;
    for (final w in ws) {
      if (w.word.trim().isEmpty) continue;
      words.add(
        _Word(
          text: _wordText(w.word),
          startMs: (w.start * 1000).round(),
          endMs: (w.end * 1000).round(),
        ),
      );
    }
  }
  if (words.isEmpty) return const <TranscriptLine>[];

  final lines = <_Line>[];
  var current = _Line(words: <_Word>[words.first]);
  for (var i = 1; i < words.length; i++) {
    final next = words[i];
    final gap = next.startMs - current.words.last.endMs;
    final wouldText = '${current.text} ${next.text}';
    final wouldDuration = next.endMs - current.words.first.startMs;

    final shouldBreak =
        _endsWithTerminator(current.text) ||
        gap > pauseThresholdMs ||
        wouldDuration > maxLineDurationMs ||
        wouldText.length > maxLineChars;

    if (shouldBreak && current.words.isNotEmpty) {
      lines.add(current);
      current = _Line(words: <_Word>[next]);
    } else {
      current.words.add(next);
    }
  }
  if (current.words.isNotEmpty) lines.add(current);

  return lines.map(_lineToTranscriptLine).toList(growable: false);
}

List<TranscriptLine> _groupFromSegments({
  required List<AsrSegment> segments,
  required int maxLineDurationMs,
  required int maxLineChars,
}) {
  final lines = <_Line>[];
  _Line? current;
  for (final seg in segments) {
    final startMs = (seg.start * 1000).round();
    final endMs = (seg.end * 1000).round();
    final segText = seg.text.trim();
    if (segText.isEmpty) continue;

    if (current == null) {
      current = _Line(
        words: <_Word>[_Word(text: segText, startMs: startMs, endMs: endMs)],
      );
      continue;
    }

    final candidate = _Line(
      words: <_Word>[
        ...current.words,
        _Word(text: segText, startMs: startMs, endMs: endMs),
      ],
    );
    final candidateDuration =
        candidate.words.last.endMs - candidate.words.first.startMs;
    final candidateText = candidate.text;

    final shouldBreak =
        _endsWithTerminator(current.text) ||
        candidateDuration >= maxLineDurationMs ||
        candidateText.length > maxLineChars;

    if (shouldBreak) {
      lines.add(current);
      current = _Line(
        words: <_Word>[_Word(text: segText, startMs: startMs, endMs: endMs)],
      );
    } else {
      current = candidate;
    }
  }
  if (current != null) lines.add(current);

  return lines.map(_lineToTranscriptLine).toList(growable: false);
}

List<TranscriptLine> _distributePlainText({
  required String text,
  required int mediaDurationMs,
  required int maxLineChars,
}) {
  final raw = collapseWhitespace(text);
  if (raw.isEmpty) return const <TranscriptLine>[];
  if (mediaDurationMs <= 0) {
    return <TranscriptLine>[
      TranscriptLine(text: raw, startMs: 0, durationMs: 0),
    ];
  }

  final chunks = <String>[];
  final buf = StringBuffer();
  for (var i = 0; i < raw.length; i++) {
    final ch = raw[i];
    buf.write(ch);
    if (_sentenceTerminators.contains(ch) || buf.length >= maxLineChars) {
      chunks.add(buf.toString().trim());
      buf.clear();
    }
  }
  if (buf.isNotEmpty) chunks.add(buf.toString().trim());
  if (chunks.isEmpty) return const <TranscriptLine>[];

  final perChunk = mediaDurationMs ~/ chunks.length;
  final out = <TranscriptLine>[];
  for (var i = 0; i < chunks.length; i++) {
    final t = chunks[i];
    if (t.isEmpty) continue;
    final startMs = perChunk * i;
    final isLast = i == chunks.length - 1;
    final durationMs = isLast
        ? (mediaDurationMs - startMs).clamp(0, mediaDurationMs)
        : perChunk;
    out.add(TranscriptLine(text: t, startMs: startMs, durationMs: durationMs));
  }
  return out;
}

TranscriptLine _lineToTranscriptLine(_Line line) {
  final startMs = line.words.first.startMs;
  final endMs = line.words.last.endMs;
  final durationMs = (endMs - startMs).clamp(0, 1 << 31);
  final text = line.text.trimRight();
  return TranscriptLine(text: text, startMs: startMs, durationMs: durationMs);
}

String _wordText(String s) {
  return s.startsWith(' ') ? s.substring(1) : s;
}

bool _endsWithTerminator(String s) {
  if (s.isEmpty) return false;
  final last = s.substring(s.length - 1);
  return _sentenceTerminators.contains(last);
}

class _Word {
  _Word({required this.text, required this.startMs, required this.endMs});
  final String text;
  final int startMs;
  final int endMs;
}

class _Line {
  _Line({required this.words});
  final List<_Word> words;
  String get text => words.map((w) => w.text).join(' ');
}
