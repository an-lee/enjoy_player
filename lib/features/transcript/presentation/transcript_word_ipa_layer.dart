/// IgnorePointer IPA annotation aligned to stored word boxes.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/data/subtitle/transcript_word_ipa.dart';

/// Extra top inset so ruby IPA is not clipped by the line tile.
double transcriptIpaOverlayReserve(TextStyle ipaStyle) {
  final size = ipaStyle.fontSize ?? 11;
  return size * 1.25;
}

/// Layout boxes for stored IPA labels (plain-text word alignment).
List<TranscriptIpaOverlayLabel> transcriptIpaOverlayLabels({
  required String plain,
  required List<TranscriptWord>? words,
  required TextStyle wordStyle,
  required double maxWidth,
}) {
  if (words == null || words.isEmpty || plain.isEmpty || maxWidth <= 0) {
    return const [];
  }
  final ranges = allWordTextRanges(plain, words);
  final painter = TextPainter(
    text: TextSpan(text: plain, style: wordStyle),
    textDirection: TextDirection.ltr,
    maxLines: 40,
  )..layout(maxWidth: maxWidth);
  final out = <TranscriptIpaOverlayLabel>[];
  for (var i = 0; i < words.length; i++) {
    final spelling = wordIpaSpelling(words[i]);
    final range = i < ranges.length ? ranges[i] : null;
    if (spelling == null || range == null || !range.isValid) continue;
    final boxes = painter.getBoxesForSelection(
      TextSelection(baseOffset: range.start, extentOffset: range.end),
    );
    if (boxes.isEmpty) continue;
    final box = boxes.first;
    out.add(
      TranscriptIpaOverlayLabel(left: box.left, top: box.top, text: spelling),
    );
  }
  painter.dispose();
  return out;
}

class TranscriptIpaOverlayLabel {
  const TranscriptIpaOverlayLabel({
    required this.left,
    required this.top,
    required this.text,
  });

  final double left;
  final double top;
  final String text;
}

/// Paints stored IPA above each word that has phone pieces. [child] is the
/// orthography [Text]/[SelectableText] and stays the lookup/karaoke target.
///
/// Uses [CustomPaint] (not [LayoutBuilder] / [Stack]) so the overlay can sit
/// in unbounded-height columns and inside [IntrinsicHeight] active-cue rails.
class TranscriptWordIpaLayer extends StatelessWidget {
  const TranscriptWordIpaLayer({
    required this.plain,
    required this.words,
    required this.wordStyle,
    required this.ipaStyle,
    required this.child,
    super.key,
  });

  final String plain;
  final List<TranscriptWord>? words;
  final TextStyle wordStyle;
  final TextStyle ipaStyle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final reserve = transcriptIpaOverlayReserve(ipaStyle);
    return Padding(
      padding: EdgeInsets.only(top: reserve),
      child: CustomPaint(
        foregroundPainter: _IpaOverlayPainter(
          plain: plain,
          words: words,
          wordStyle: wordStyle,
          ipaStyle: ipaStyle,
          reserve: reserve,
        ),
        child: child,
      ),
    );
  }
}

class _IpaOverlayPainter extends CustomPainter {
  _IpaOverlayPainter({
    required this.plain,
    required this.words,
    required this.wordStyle,
    required this.ipaStyle,
    required this.reserve,
  });

  final String plain;
  final List<TranscriptWord>? words;
  final TextStyle wordStyle;
  final TextStyle ipaStyle;
  final double reserve;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.width <= 0) return;
    final labels = transcriptIpaOverlayLabels(
      plain: plain,
      words: words,
      wordStyle: wordStyle,
      maxWidth: size.width,
    );
    for (final label in labels) {
      final ipa = TextPainter(
        text: TextSpan(text: label.text, style: ipaStyle),
        textDirection: TextDirection.ltr,
        maxLines: 1,
      )..layout();
      ipa.paint(canvas, Offset(label.left, label.top - reserve));
      ipa.dispose();
    }
  }

  @override
  bool shouldRepaint(covariant _IpaOverlayPainter oldDelegate) {
    return plain != oldDelegate.plain ||
        words != oldDelegate.words ||
        wordStyle != oldDelegate.wordStyle ||
        ipaStyle != oldDelegate.ipaStyle ||
        reserve != oldDelegate.reserve;
  }

  @override
  bool hitTest(Offset position) => false;
}
