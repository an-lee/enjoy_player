/// Map [phonemizeLines] output onto line-only [TranscriptLine]s (untimed).
library;

import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';

/// Attaches untimed nested words + IPA labels without changing line identity.
///
/// [results] must be the same length as [lines]. Empty results leave that
/// cue line-only. Word and phone clocks are omitted.
List<TranscriptLine> attachPhonemesToLines(
  List<TranscriptLine> lines,
  List<PhonemizeLineResult> results,
) {
  if (lines.isEmpty) return lines;
  if (results.length != lines.length) {
    throw ArgumentError.value(
      results.length,
      'results.length',
      'must match lines (${lines.length})',
    );
  }

  return [
    for (var i = 0; i < lines.length; i++) _attachOne(lines[i], results[i]),
  ];
}

TranscriptLine _attachOne(TranscriptLine line, PhonemizeLineResult result) {
  final words = <TranscriptWord>[];
  for (final engineWord in result.words) {
    final text = engineWord.text.trim();
    if (text.isEmpty) continue;
    final wordIndex = words.length;
    final phones = [
      for (final label in engineWord.phones)
        if (label.trim().isNotEmpty)
          TranscriptPhone(
            phone: label.trim(),
            text: label.trim(),
            wordIndex: wordIndex,
          ),
    ];
    words.add(
      TranscriptWord(text: text, phones: phones.isEmpty ? null : phones),
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
