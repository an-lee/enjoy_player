import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/transcript/application/transcript_line_alignment.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptLine cue(int startMs, int durationMs, [String text = 'x']) {
  return TranscriptLine(text: text, startMs: startMs, durationMs: durationMs);
}

EchoState echoRange(int startLineIndex, int endLineIndex) {
  return EchoState(
    active: true,
    startLineIndex: startLineIndex,
    endLineIndex: endLineIndex,
    startTimeSeconds: 0,
    endTimeSeconds: 0,
  );
}

void main() {
  group('echoReferencePlainText', () {
    test('returns empty string when echo is inactive', () {
      final lines = [cue(0, 1000, 'hello'), cue(1000, 1000, 'world')];
      expect(echoReferencePlainText(lines, EchoState.inactive), '');
    });

    test('returns empty string when start index is negative', () {
      final lines = [cue(0, 1000, 'hello')];
      expect(echoReferencePlainText(lines, echoRange(-1, 0)), '');
    });

    test('returns empty string when end index is negative', () {
      final lines = [cue(0, 1000, 'hello')];
      expect(echoReferencePlainText(lines, echoRange(0, -1)), '');
    });

    test('returns empty string when start > end', () {
      final lines = [cue(0, 1000, 'hello'), cue(1000, 1000, 'world')];
      expect(echoReferencePlainText(lines, echoRange(1, 0)), '');
    });

    test('returns single line text when start == end', () {
      final lines = [cue(0, 1000, 'hello')];
      expect(echoReferencePlainText(lines, echoRange(0, 0)), 'hello');
    });

    test('joins multiple lines with single space', () {
      final lines = [
        cue(0, 1000, 'hello'),
        cue(1000, 1000, 'world'),
        cue(2000, 1000, 'foo'),
      ];
      expect(echoReferencePlainText(lines, echoRange(0, 2)), 'hello world foo');
    });

    test('clamps to lines.length when end is out of bounds', () {
      final lines = [cue(0, 1000, 'hello'), cue(1000, 1000, 'world')];
      expect(echoReferencePlainText(lines, echoRange(0, 5)), 'hello world');
    });

    test('skips empty-text lines within range', () {
      final lines = [
        cue(0, 1000, 'hello'),
        cue(1000, 1000, '   '),
        cue(2000, 1000, ''),
        cue(3000, 1000, 'world'),
      ];
      expect(echoReferencePlainText(lines, echoRange(0, 3)), 'hello world');
    });

    test('returns empty string when all lines in range have empty text', () {
      final lines = [
        cue(0, 1000, ''),
        cue(1000, 1000, '   '),
        cue(2000, 1000, ''),
      ];
      expect(echoReferencePlainText(lines, echoRange(0, 2)), '');
    });

    test('strips subtitle markup tags before joining', () {
      final lines = [
        cue(0, 1000, '<i>hello</i>'),
        cue(1000, 1000, '<b>brave</b> <font color="red">world</font>'),
      ];
      expect(
        echoReferencePlainText(lines, echoRange(0, 1)),
        'hello brave world',
      );
    });

    test('trims whitespace on each line before joining', () {
      final lines = [cue(0, 1000, '   hello   '), cue(1000, 1000, '\tworld\n')];
      expect(echoReferencePlainText(lines, echoRange(0, 1)), 'hello world');
    });

    test('range subset returns just those lines', () {
      final lines = [
        cue(0, 1000, 'first'),
        cue(1000, 1000, 'second'),
        cue(2000, 1000, 'third'),
        cue(3000, 1000, 'fourth'),
      ];
      expect(echoReferencePlainText(lines, echoRange(1, 2)), 'second third');
    });

    test('returns empty string when start is at end of lines', () {
      final lines = [cue(0, 1000, 'hello')];
      expect(echoReferencePlainText(lines, echoRange(1, 1)), '');
    });

    test('returns empty string when start and end are both past lines', () {
      final lines = [cue(0, 1000, 'hello')];
      expect(echoReferencePlainText(lines, echoRange(5, 10)), '');
    });

    test('empty lines list returns empty string for active echo', () {
      expect(echoReferencePlainText([], echoRange(0, 0)), '');
    });
  });
}
