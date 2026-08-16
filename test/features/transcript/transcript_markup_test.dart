import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_markup.dart';

String? _highlightedPlain(InlineSpan span) {
  final buf = StringBuffer();
  void walk(InlineSpan node) {
    if (node is TextSpan) {
      if (node.style?.backgroundColor != null && node.text != null) {
        buf.write(node.text);
      }
      node.children?.forEach(walk);
    }
  }

  walk(span);
  return buf.isEmpty ? null : buf.toString();
}

String _plain(InlineSpan span) {
  final buf = StringBuffer();
  void walk(InlineSpan node) {
    if (node is TextSpan) {
      if (node.text != null) buf.write(node.text);
      node.children?.forEach(walk);
    }
  }

  walk(span);
  return buf.toString();
}

void main() {
  const base = TextStyle(fontSize: 16);
  const fill = Color(0xFF112233);

  test('optional highlight range tints the located substring', () {
    final span = transcriptMarkupToTextSpan(
      'Hello world',
      base,
      defaultColor: Colors.white,
      highlightRange: const WordTextRange(start: 0, end: 5),
      highlightFill: fill,
    );
    expect(_plain(span), 'Hello world');
    expect(_highlightedPlain(span), 'Hello');
  });

  test('highlight keeps SSA markup text and styles', () {
    final span = transcriptMarkupToTextSpan(
      '<b>Hello</b> world',
      base,
      defaultColor: Colors.white,
      highlightRange: const WordTextRange(start: 6, end: 11),
      highlightFill: fill,
    );
    expect(_plain(span), 'Hello world');
    expect(_highlightedPlain(span), 'world');
    expect(_plain(span), isNot(contains('həˈloʊ')));
  });

  test('phone strings never appear in markup output', () {
    final span = transcriptMarkupToTextSpan(
      'Hello world',
      base,
      defaultColor: Colors.white,
      highlightRange: const WordTextRange(start: 0, end: 5),
      highlightFill: fill,
    );
    expect(_plain(span), isNot(contains('æ̃ˈxyz')));
    expect(_plain(span), isNot(contains('həˈloʊ')));
  });

  test('missing range or fill leaves text unhighlighted', () {
    final span = transcriptMarkupToTextSpan(
      'Hello world',
      base,
      defaultColor: Colors.white,
    );
    expect(_highlightedPlain(span), isNull);
    expect(_plain(span), 'Hello world');
  });
}
