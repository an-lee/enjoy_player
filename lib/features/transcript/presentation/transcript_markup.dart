/// Timestamp and SSA/HTML-like markup rendering for transcript lines.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/data/subtitle/subtitle_markup_parser.dart';

/// Plain text as rendered by [transcriptMarkupToTextSpan] (for selection indices).
String transcriptPlainForSelection(String raw) {
  final segments = parseSubtitleMarkup(raw);
  if (segments.isEmpty) {
    final plain = raw.replaceAll(tagStripRegExp, '').trim();
    return plain.isEmpty ? raw : plain;
  }
  return segments.map((s) => s.text).join();
}

/// Formats [startMs] as `M:SS` or `H:MM:SS` when over one hour.
String formatTranscriptTimestampMs(int startMs) {
  final totalSec = (startMs / 1000).floor().clamp(0, 1 << 30);
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// Builds a [TextSpan] tree from SSA/HTML-like subtitle markup.
///
/// [highlightRange] is UTF-16 offsets into [transcriptPlainForSelection]
/// (concatenated visible text). [highlightFill] is painted behind that
/// substring when both are set.
TextSpan transcriptMarkupToTextSpan(
  String raw,
  TextStyle baseStyle, {
  required Color defaultColor,
  bool emphasize = false,
  WordTextRange? highlightRange,
  Color? highlightFill,
}) {
  final segments = parseSubtitleMarkup(raw);
  if (segments.isEmpty) {
    final plain = raw.replaceAll(tagStripRegExp, '').trim();
    final text = plain.isEmpty ? raw : plain;
    return TextSpan(
      children: _spansForPlainChunk(
        text,
        0,
        _cueStyle(baseStyle, defaultColor: defaultColor, emphasize: emphasize),
        highlightRange,
        highlightFill,
      ),
    );
  }

  var offset = 0;
  final children = <InlineSpan>[];
  for (final seg in segments) {
    final fg = seg.colorArgb != null ? Color(seg.colorArgb!) : defaultColor;
    final style = _cueStyle(
      baseStyle,
      defaultColor: fg,
      emphasize: emphasize,
      bold: seg.bold,
      italic: seg.italic,
      underline: seg.underline,
    );
    children.addAll(
      _spansForPlainChunk(
        seg.text,
        offset,
        style,
        highlightRange,
        highlightFill,
      ),
    );
    offset += seg.text.length;
  }
  return TextSpan(children: children);
}

List<InlineSpan> _spansForPlainChunk(
  String text,
  int chunkStart,
  TextStyle style,
  WordTextRange? highlightRange,
  Color? highlightFill,
) {
  if (text.isEmpty) return const [];
  final range = highlightRange;
  final fill = highlightFill;
  if (range == null || fill == null || !range.isValid) {
    return [TextSpan(text: text, style: style)];
  }
  final chunkEnd = chunkStart + text.length;
  final hiStart = range.start.clamp(chunkStart, chunkEnd).toInt();
  final hiEnd = range.end.clamp(chunkStart, chunkEnd).toInt();
  if (hiEnd <= hiStart) {
    return [TextSpan(text: text, style: style)];
  }
  final localStart = hiStart - chunkStart;
  final localEnd = hiEnd - chunkStart;
  final out = <InlineSpan>[];
  if (localStart > 0) {
    out.add(TextSpan(text: text.substring(0, localStart), style: style));
  }
  out.add(
    TextSpan(
      text: text.substring(localStart, localEnd),
      style: style.copyWith(backgroundColor: fill),
    ),
  );
  if (localEnd < text.length) {
    out.add(TextSpan(text: text.substring(localEnd), style: style));
  }
  return out;
}

TextStyle _cueStyle(
  TextStyle base, {
  required Color defaultColor,
  bool emphasize = false,
  bool bold = false,
  bool italic = false,
  bool underline = false,
}) {
  final weight = emphasize || bold
      ? FontWeight.w600
      : base.fontWeight ?? FontWeight.normal;
  return base.copyWith(
    color: defaultColor,
    fontWeight: weight,
    fontStyle: italic ? FontStyle.italic : base.fontStyle,
    decoration: underline ? TextDecoration.underline : TextDecoration.none,
    decorationColor: defaultColor,
  );
}
