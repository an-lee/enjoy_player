/// Stacked English + IPA word columns (Enjoy web AlignedWord layout).
library;

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/data/subtitle/transcript_word_ipa.dart';

/// Whether [words] carry any displayable phone labels.
bool transcriptWordsHavePhones(List<TranscriptWord>? words) {
  if (words == null || words.isEmpty) return false;
  for (final w in words) {
    if (wordIpaSpelling(w) != null) return true;
  }
  return false;
}

/// IPA style: Noto Sans so IPA Extensions rasterize (Source Serif 4 cannot).
TextStyle transcriptIpaTextStyle(TextStyle bodyStyle, Color color) {
  final size = (bodyStyle.fontSize ?? 16) * 0.75;
  return GoogleFonts.notoSans(
    fontSize: size,
    height: 1.15,
    fontWeight: FontWeight.w400,
    color: color,
  );
}

/// Wrap of per-word columns: orthography on top, optional IPA underneath.
///
/// [onIpaTap] is invoked with the word index when the learner taps that
/// word's IPA label (seek-and-play). Orthography hits are not handled here
/// so selectable lookup / line InkWell keep working.
class TranscriptAlignedWords extends StatelessWidget {
  const TranscriptAlignedWords({
    required this.words,
    required this.wordStyle,
    required this.ipaStyle,
    required this.defaultColor,
    required this.emphasize,
    this.activeWordIndex,
    this.activeUnderlineColor,
    this.onIpaTap,
    this.selectableWordBuilder,
    super.key,
  });

  final List<TranscriptWord> words;
  final TextStyle wordStyle;
  final TextStyle ipaStyle;
  final Color defaultColor;
  final bool emphasize;
  final int? activeWordIndex;
  final Color? activeUnderlineColor;

  /// When set, tapping IPA for that word index calls this.
  final ValueChanged<int>? onIpaTap;

  /// Optional builder for orthography when the row is dictionary-selectable.
  /// Defaults to a plain [Text].
  final Widget Function(BuildContext context, String text, TextStyle style)?
  selectableWordBuilder;

  @override
  Widget build(BuildContext context) {
    final activeColor =
        activeUnderlineColor ?? Theme.of(context).colorScheme.primary;
    return Wrap(
      spacing: 8,
      runSpacing: 4,
      crossAxisAlignment: WrapCrossAlignment.end,
      children: [
        for (var i = 0; i < words.length; i++)
          _AlignedWordColumn(
            key: ValueKey('aligned-word-$i'),
            text: words[i].text,
            ipa: wordIpaSpelling(words[i]),
            wordStyle: wordStyle.copyWith(
              color: emphasize ? defaultColor : wordStyle.color ?? defaultColor,
              fontWeight: emphasize ? FontWeight.w600 : wordStyle.fontWeight,
            ),
            ipaStyle: ipaStyle,
            isActive: activeWordIndex == i,
            activeUnderlineColor: activeColor,
            onIpaTap: onIpaTap == null ? null : () => onIpaTap!(i),
            selectableWordBuilder: selectableWordBuilder,
          ),
      ],
    );
  }
}

class _AlignedWordColumn extends StatelessWidget {
  const _AlignedWordColumn({
    required this.text,
    required this.ipa,
    required this.wordStyle,
    required this.ipaStyle,
    required this.isActive,
    required this.activeUnderlineColor,
    this.onIpaTap,
    this.selectableWordBuilder,
    super.key,
  });

  final String text;
  final String? ipa;
  final TextStyle wordStyle;
  final TextStyle ipaStyle;
  final bool isActive;
  final Color activeUnderlineColor;
  final VoidCallback? onIpaTap;
  final Widget Function(BuildContext context, String text, TextStyle style)?
  selectableWordBuilder;

  @override
  Widget build(BuildContext context) {
    final orthography =
        selectableWordBuilder?.call(context, text, wordStyle) ??
        Text(text, style: wordStyle);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: isActive ? activeUnderlineColor : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: orthography,
        ),
        if (ipa != null && ipa!.isNotEmpty)
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: onIpaTap,
            child: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: ExcludeSemantics(
                child: Text(ipa!, style: ipaStyle, maxLines: 1),
              ),
            ),
          ),
      ],
    );
  }
}
