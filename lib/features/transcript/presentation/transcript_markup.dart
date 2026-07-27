/// Timestamp and SSA/HTML-like markup rendering for transcript lines.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/data/subtitle/subtitle_markup_parser.dart';

final _tagStripRegExp = RegExp(r'<[^>]*>');

/// Plain text as rendered by [transcriptMarkupToTextSpan] (for selection indices).
String transcriptPlainForSelection(String raw) {
  final segments = parseSubtitleMarkup(raw);
  if (segments.isEmpty) {
    final plain = raw.replaceAll(_tagStripRegExp, '').trim();
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
TextSpan transcriptMarkupToTextSpan(
  String raw,
  TextStyle baseStyle, {
  required Color defaultColor,
  bool emphasize = false,
}) {
  final segments = parseSubtitleMarkup(raw);
  if (segments.isEmpty) {
    final plain = raw.replaceAll(_tagStripRegExp, '').trim();
    final text = plain.isEmpty ? raw : plain;
    return TextSpan(
      text: text,
      style: _cueStyle(
        baseStyle,
        defaultColor: defaultColor,
        emphasize: emphasize,
      ),
    );
  }

  return TextSpan(
    children: segments.map((seg) {
      final fg = seg.colorArgb != null ? Color(seg.colorArgb!) : defaultColor;
      return TextSpan(
        text: seg.text,
        style: _cueStyle(
          baseStyle,
          defaultColor: fg,
          emphasize: emphasize,
          bold: seg.bold,
          italic: seg.italic,
          underline: seg.underline,
        ),
      );
    }).toList(),
  );
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
