import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/share_poster/domain/practice_poster_data.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptLine _line(String text, {int startMs = 0, int durationMs = 1000}) =>
    TranscriptLine(text: text, startMs: startMs, durationMs: durationMs);

RecordingRow _recording({
  String id = 'r-1',
  String referenceText = '',
  int duration = 1000,
  int referenceStart = 0,
  int referenceDuration = 1000,
}) => RecordingRow(
  id: id,
  targetType: 'video',
  targetId: 'v-1',
  referenceStart: referenceStart,
  referenceDuration: referenceDuration,
  referenceText: referenceText,
  language: 'en',
  duration: duration,
  createdAt: DateTime.utc(2026, 7, 1),
  updatedAt: DateTime.utc(2026, 7, 1),
);

void main() {
  group('PracticePosterQuoteLine', () {
    test('displayText appends ellipsis when trailingEllipsis=true', () {
      const line = PracticePosterQuoteLine(
        text: 'hello',
        trailingEllipsis: true,
      );
      expect(line.displayText, 'hello...');
    });

    test('displayText returns plain text when trailingEllipsis=false', () {
      const line = PracticePosterQuoteLine(text: 'done.');
      expect(line.displayText, 'done.');
    });
  });

  group('PracticePosterQuote', () {
    test('isEmpty true for whitespace-only text', () {
      const q = PracticePosterQuote(line: PracticePosterQuoteLine(text: '   '));
      expect(q.isEmpty, isTrue);
    });

    test('isEmpty false for non-blank text', () {
      const q = PracticePosterQuote(line: PracticePosterQuoteLine(text: 'hi'));
      expect(q.isEmpty, isFalse);
    });
  });

  group('PracticePosterData', () {
    test('hasPractice false when takes=0', () {
      const data = PracticePosterData(
        title: 'T',
        coverSeed: 's',
        isVideo: true,
        takes: 0,
        sentencesPracticed: 0,
        spokenDurationMs: 0,
      );
      expect(data.hasPractice, isFalse);
    });

    test('hasPractice true when takes>0', () {
      const data = PracticePosterData(
        title: 'T',
        coverSeed: 's',
        isVideo: true,
        takes: 3,
        sentencesPracticed: 2,
        spokenDurationMs: 5000,
      );
      expect(data.hasPractice, isTrue);
    });
  });

  group('isLikelyIncompleteSentence', () {
    test('returns true for mid-sentence text', () {
      expect(isLikelyIncompleteSentence('hello world'), isTrue);
      expect(isLikelyIncompleteSentence('and then we'), isTrue);
    });

    test('returns false for ASCII terminators', () {
      expect(isLikelyIncompleteSentence('Hello world.'), isFalse);
      expect(isLikelyIncompleteSentence('Really?'), isFalse);
      expect(isLikelyIncompleteSentence('Wow!'), isFalse);
    });

    test('returns false for fullwidth Chinese terminators', () {
      expect(isLikelyIncompleteSentence('你好。'), isFalse);
      expect(isLikelyIncompleteSentence('什么？'), isFalse);
    });

    test('returns false for empty / whitespace', () {
      expect(isLikelyIncompleteSentence(''), isFalse);
      expect(isLikelyIncompleteSentence('   '), isFalse);
    });

    test('handles closing quotes after the terminator', () {
      expect(isLikelyIncompleteSentence('"Hello."'), isFalse);
      expect(isLikelyIncompleteSentence('"Hello"'), isTrue);
    });
  });

  group('computePracticePosterStats', () {
    test('returns zeros for empty recordings', () {
      final stats = computePracticePosterStats(
        recordings: const [],
        lines: const [],
      );
      expect(stats.takes, 0);
      expect(stats.sentencesPracticed, 0);
      expect(stats.spokenDurationMs, 0);
    });

    test('aggregates takes, spoken duration, and per-line sentence counts', () {
      final lines = [
        _line('line one.', startMs: 0, durationMs: 1000),
        _line('line two.', startMs: 1000, durationMs: 1000),
        _line('line three.', startMs: 2000, durationMs: 1000),
      ];
      final recordings = [
        _recording(id: 'a', duration: 1000, referenceStart: 0),
        _recording(id: 'b', duration: 2000, referenceStart: 0),
        _recording(id: 'c', duration: 3000, referenceStart: 2000),
      ];
      final stats = computePracticePosterStats(
        recordings: recordings,
        lines: lines,
      );
      expect(stats.takes, 3);
      expect(stats.spokenDurationMs, 6000);
      expect(stats.sentencesPracticed, 2);
    });
  });

  group('joinTranscriptLineTexts', () {
    test('returns empty string for empty lines', () {
      expect(
        joinTranscriptLineTexts(const [], startLineIndex: 0, endLineIndex: 2),
        '',
      );
    });

    test('returns empty string when start > end', () {
      expect(
        joinTranscriptLineTexts(
          [_line('a'), _line('b')],
          startLineIndex: 5,
          endLineIndex: 1,
        ),
        '',
      );
    });

    test('joins with spaces and trims', () {
      final out = joinTranscriptLineTexts(
        [_line('hello'), _line('world'), _line('foo')],
        startLineIndex: 0,
        endLineIndex: 2,
      );
      expect(out, 'hello world foo');
    });

    test('clamps out-of-range indices', () {
      final out = joinTranscriptLineTexts(
        [_line('a'), _line('b')],
        startLineIndex: -5,
        endLineIndex: 99,
      );
      expect(out, 'a b');
    });

    test('strips subtitle markup before joining', () {
      final out = joinTranscriptLineTexts(
        [_line('<i>hello</i>'), _line('world')],
        startLineIndex: 0,
        endLineIndex: 1,
      );
      expect(out, 'hello world');
    });
  });

  group('resolvePracticePosterQuote', () {
    test('returns null when no recordings', () {
      expect(
        resolvePracticePosterQuote(lines: [_line('hi.')], recordings: const []),
        isNull,
      );
    });

    test('uses echo range text when echoStart/End are set and lines exist', () {
      final q = resolvePracticePosterQuote(
        lines: [_line('hello'), _line('world')],
        recordings: [_recording()],
        echoStartLineIndex: 0,
        echoEndLineIndex: 1,
      );
      expect(q, isNotNull);
      expect(q!.line.text, 'hello world');
    });

    test('falls back to most-practiced line when echo range is empty', () {
      // Build lines with overlapping reference windows:
      //   line 0: 0..1000  ("hi there")
      //   line 1: 1000..2000 ("this is short")
      final lines = [
        _line('hi there', startMs: 0, durationMs: 1000),
        _line('this is short', startMs: 1000, durationMs: 1000),
      ];
      final q = resolvePracticePosterQuote(
        lines: lines,
        recordings: [
          // 3 recordings overlap line 1's window (1000..2000)
          _recording(
            id: 'r1',
            referenceText: 'short',
            referenceStart: 1000,
            referenceDuration: 1000,
          ),
          _recording(
            id: 'r2',
            referenceText: 'short',
            referenceStart: 1100,
            referenceDuration: 800,
          ),
          _recording(
            id: 'r3',
            referenceText: 'short',
            referenceStart: 1500,
            referenceDuration: 500,
          ),
          // 1 recording overlaps line 0
          _recording(
            id: 'r4',
            referenceText: 'short',
            referenceStart: 0,
            referenceDuration: 800,
          ),
        ],
      );
      expect(q, isNotNull);
      expect(q!.line.text, 'this is short');
    });

    test('marks incomplete sentences with trailingEllipsis', () {
      final q = resolvePracticePosterQuote(
        lines: [_line('mid sentence')],
        recordings: [_recording()],
      );
      expect(q!.line.trailingEllipsis, isTrue);
    });

    test(
      'falls back to longest referenceText when transcript lines are empty',
      () {
        final q = resolvePracticePosterQuote(
          lines: const [],
          recordings: [
            _recording(id: 'a', referenceText: 'short ref'),
            _recording(
              id: 'b',
              referenceText: 'much longer reference text here',
            ),
          ],
        );
        expect(q, isNotNull);
        expect(q!.line.text, 'much longer reference text here');
      },
    );

    test('returns null when nothing is usable', () {
      final q = resolvePracticePosterQuote(
        lines: const [],
        recordings: [
          _recording(id: 'a', referenceText: ''),
          _recording(id: 'b', referenceText: ''),
        ],
      );
      expect(q, isNull);
    });
  });
}
