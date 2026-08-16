import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';

TranscriptLine _line({
  required String text,
  int startMs = 1000,
  int durationMs = 3000,
  List<TranscriptWord>? timeline,
}) {
  return TranscriptLine(
    text: text,
    startMs: startMs,
    durationMs: durationMs,
    timeline: timeline,
  );
}

void main() {
  group('currentWordIndex', () {
    const words = [
      TranscriptWord(text: 'Hello', startMs: 0, durationMs: 500),
      TranscriptWord(text: 'there', startMs: 500, durationMs: 500),
      TranscriptWord(text: 'world', startMs: 1000, durationMs: 500),
    ];

    test('follows positionMs across three timed words', () {
      final line = _line(text: 'Hello there world', timeline: words);
      expect(currentWordIndex(line, 1000), 0);
      expect(currentWordIndex(line, 1499), 0);
      expect(currentWordIndex(line, 1500), 1);
      expect(currentWordIndex(line, 1999), 1);
      expect(currentWordIndex(line, 2000), 2);
      expect(currentWordIndex(line, 2499), 2);
    });

    test('overlap picks the last matching index', () {
      final line = _line(
        text: 'Hello there',
        timeline: const [
          TranscriptWord(text: 'Hello', startMs: 0, durationMs: 800),
          TranscriptWord(text: 'there', startMs: 400, durationMs: 800),
        ],
      );
      expect(currentWordIndex(line, 1000), 0);
      expect(currentWordIndex(line, 1400), 1);
      expect(currentWordIndex(line, 1799), 1);
    });

    test('returns null for omitted or empty timeline', () {
      expect(currentWordIndex(_line(text: 'Hello'), 1200), isNull);
      expect(
        currentWordIndex(_line(text: 'Hello', timeline: const []), 1200),
        isNull,
      );
    });

    test('skips zero-duration and empty-text words', () {
      final line = _line(
        text: 'Hello world',
        timeline: const [
          TranscriptWord(text: 'Hello', startMs: 0, durationMs: 0),
          TranscriptWord(text: '   ', startMs: 0, durationMs: 500),
          TranscriptWord(text: 'world', startMs: 500, durationMs: 500),
        ],
      );
      expect(currentWordIndex(line, 1100), isNull);
      expect(currentWordIndex(line, 1600), 2);
    });

    test('ignores words whose window lies entirely outside the line', () {
      final line = _line(
        text: 'Hello',
        startMs: 1000,
        durationMs: 500,
        timeline: const [
          TranscriptWord(text: 'Hello', startMs: 800, durationMs: 100),
        ],
      );
      expect(currentWordIndex(line, 1800), isNull);
      expect(currentWordIndex(line, 1200), isNull);
    });

    test('gap between words is not a current word', () {
      final line = _line(
        text: 'Hello world',
        timeline: const [
          TranscriptWord(text: 'Hello', startMs: 0, durationMs: 400),
          TranscriptWord(text: 'world', startMs: 800, durationMs: 400),
        ],
      );
      expect(currentWordIndex(line, 1600), isNull);
    });

    test('does not rewrite line start or duration', () {
      const original = TranscriptLine(
        text: 'Hello',
        startMs: 1000,
        durationMs: 2000,
        timeline: [TranscriptWord(text: 'Hello', startMs: 0, durationMs: 500)],
      );
      currentWordIndex(original, 1100);
      expect(original.startMs, 1000);
      expect(original.durationMs, 2000);
      expect(original.text, 'Hello');
    });
  });

  group('wordHighlightRange', () {
    const words = [
      TranscriptWord(text: 'Hello', startMs: 0, durationMs: 500),
      TranscriptWord(text: 'world', startMs: 500, durationMs: 500),
    ];

    test('sequential substring ranges for Hello world', () {
      const plain = 'Hello world';
      final hello = wordHighlightRange(plain, words, 0);
      final world = wordHighlightRange(plain, words, 1);
      expect(hello, isNotNull);
      expect(hello!.start, 0);
      expect(hello.end, 5);
      expect(plain.substring(hello.start, hello.end), 'Hello');
      expect(world, isNotNull);
      expect(world!.start, 6);
      expect(world.end, 11);
      expect(plain.substring(world.start, world.end), 'world');
    });

    test('missing substring for the requested word returns null', () {
      expect(wordHighlightRange('Hello world', words, 0), isNotNull);
      expect(
        wordHighlightRange('Hello world', [
          const TranscriptWord(text: 'xyz', startMs: 0, durationMs: 500),
        ], 0),
        isNull,
      );
    });

    test('out-of-range index and null timeline return null', () {
      expect(wordHighlightRange('Hello', null, 0), isNull);
      expect(wordHighlightRange('Hello', words, -1), isNull);
      expect(wordHighlightRange('Hello', words, 9), isNull);
    });
  });
}
