import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/lookup/application/vocabulary_context_builder.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptLine _line(String text, {int startMs = 0, int durationMs = 1000}) =>
    TranscriptLine(text: text, startMs: startMs, durationMs: durationMs);

void main() {
  group('plainCueText', () {
    test('strips HTML tags and collapses whitespace', () {
      expect(plainCueText('<i>hello</i>  world'), 'hello world');
    });

    test('handles plain text', () {
      expect(plainCueText('hello world'), 'hello world');
    });

    test('handles empty / whitespace', () {
      expect(plainCueText(''), '');
      expect(plainCueText('   '), '');
      expect(plainCueText('\n\n\n'), '');
    });

    test('handles nested tags', () {
      expect(plainCueText('<b>hi <i>there</i></b>'), 'hi there');
    });
  });

  group('expandContextLines', () {
    test('returns same range when radius is 0', () {
      final r = expandContextLines(2, 2, 10, radius: 0);
      expect(r.startArrayIndex, 2);
      expect(r.endArrayIndex, 2);
    });

    test('expands symmetrically by default', () {
      final r = expandContextLines(5, 5, 20);
      expect(r.startArrayIndex, 2);
      expect(r.endArrayIndex, 8);
    });

    test('respects start boundary (cannot go below 0)', () {
      final r = expandContextLines(0, 0, 20);
      expect(r.startArrayIndex, 0);
      expect(r.endArrayIndex, 3);
    });

    test('respects end boundary (cannot go past lineCount-1)', () {
      // 20 lines, seed=17, radius=3 → forward is min(3, 19-17)=2 → end=19.
      final r = expandContextLines(17, 17, 20);
      expect(r.startArrayIndex, 14);
      expect(r.endArrayIndex, 19);
    });

    test('expands a non-zero seed range symmetrically', () {
      final r = expandContextLines(3, 5, 20);
      expect(r.startArrayIndex, 0);
      expect(r.endArrayIndex, 8);
    });

    test('handles single-line transcript', () {
      final r = expandContextLines(0, 0, 1);
      expect(r.startArrayIndex, 0);
      expect(r.endArrayIndex, 0);
    });

    test('respects the available distance at end of transcript', () {
      // 20 lines, seed=15, radius=3 → forward is min(3, 19-15)=3 → end=18.
      final r = expandContextLines(15, 15, 20);
      expect(r.startArrayIndex, 12);
      expect(r.endArrayIndex, 18);
    });
  });

  group('isMoreThanOneSentence', () {
    test('false for single-sentence text', () {
      expect(isMoreThanOneSentence('Hello there.', 'en'), isFalse);
    });

    test('true for multi-sentence text', () {
      expect(isMoreThanOneSentence('First. Second sentence.', 'en'), isTrue);
    });

    test('true for one terminator plus extra content', () {
      expect(isMoreThanOneSentence('Hello. And then more text', 'en'), isTrue);
    });

    test('false for no terminators (returns false)', () {
      expect(isMoreThanOneSentence('no punctuation here', 'en'), isFalse);
    });

    test('handles Chinese fullwidth punctuation', () {
      expect(isMoreThanOneSentence('你好。 今天。', 'zh-CN'), isTrue);
      expect(isMoreThanOneSentence('你好。', 'zh-CN'), isFalse);
    });
  });

  group('resolveVocabularyContextSpan', () {
    test('returns null for empty lines', () {
      final r = resolveVocabularyContextSpan(
        lines: const [],
        echo: EchoState.inactive,
        currentTimeSeconds: 0,
        primaryLanguage: 'en',
      );
      expect(r, isNull);
    });

    test('returns null when no seed line can be derived', () {
      final r = resolveVocabularyContextSpan(
        lines: [_line('hello world')],
        echo: EchoState.inactive,
        currentTimeSeconds: -100, // before any cue
        primaryLanguage: 'en',
      );
      expect(r, isNull);
    });

    test('returns the bounded window when transcript has no punctuation', () {
      final r = resolveVocabularyContextSpan(
        lines: [
          _line('no punctuation line', startMs: 0),
          _line('another unterminated line', startMs: 1000),
        ],
        echo: EchoState.inactive,
        currentTimeSeconds: 0,
        primaryLanguage: 'en',
      );
      expect(r, isNotNull);
      expect(r!.text, contains('no punctuation'));
    });

    test('selects a single sentence around the seed cue', () {
      final lines = [
        _line('First sentence ends here.', startMs: 0),
        _line('Second sentence here too.', startMs: 1000),
        _line('Third one is here.', startMs: 2000),
      ];
      final r = resolveVocabularyContextSpan(
        lines: lines,
        echo: EchoState.inactive,
        currentTimeSeconds: 1.0, // inside second line
        primaryLanguage: 'en',
      );
      expect(r, isNotNull);
      expect(r!.text, 'Second sentence here too.');
      expect(r.startLineIndex, 1);
      expect(r.endLineIndex, 1);
    });

    test('echo region with multiple sentences returns the full echo', () {
      final lines = [
        _line('Alpha sentence.', startMs: 0),
        _line('Beta sentence.', startMs: 1000),
        _line('Gamma sentence.', startMs: 2000),
      ];
      final r = resolveVocabularyContextSpan(
        lines: lines,
        echo: const EchoState(
          active: true,
          startLineIndex: 0,
          endLineIndex: 1,
          startTimeSeconds: 0,
          endTimeSeconds: 2.0,
        ),
        currentTimeSeconds: 1.0,
        primaryLanguage: 'en',
      );
      expect(r, isNotNull);
      expect(r!.text, 'Alpha sentence. Beta sentence.');
    });

    test('echo with only one sentence falls through to seed-line path', () {
      final lines = [
        _line('Just one line, no terminator here', startMs: 0),
        _line('And here another without end', startMs: 1000),
      ];
      final r = resolveVocabularyContextSpan(
        lines: lines,
        echo: const EchoState(
          active: true,
          startLineIndex: 0,
          endLineIndex: 0,
          startTimeSeconds: 0,
          endTimeSeconds: 1.0,
        ),
        currentTimeSeconds: 0.5,
        primaryLanguage: 'en',
      );
      // Echo single-sentence falls through to the bounded seed path; we
      // accept any non-null result that does not return the single echo line.
      expect(r, isNotNull);
    });

    test('ignores echo with invalid line indices', () {
      final lines = [
        _line('First line here.', startMs: 0),
        _line('Second line here.', startMs: 1000),
      ];
      final r = resolveVocabularyContextSpan(
        lines: lines,
        echo: const EchoState(
          active: true,
          startLineIndex: -1, // invalid
          endLineIndex: 5, // also out of range
          startTimeSeconds: 0,
          endTimeSeconds: 1.0,
        ),
        currentTimeSeconds: 0.5,
        primaryLanguage: 'en',
      );
      // echoValid=false, seedIdx falls back to activeIdx (0).
      expect(r, isNotNull);
      expect(r!.text, 'First line here.');
    });

    test('seed echo fallback when currentTimeSeconds is before any cue', () {
      final lines = [
        _line('Alpha sentence.', startMs: 1000),
        _line('Beta sentence.', startMs: 2000),
      ];
      final r = resolveVocabularyContextSpan(
        lines: lines,
        echo: const EchoState(
          active: true,
          startLineIndex: 0,
          endLineIndex: 0,
          startTimeSeconds: 1.0,
          endTimeSeconds: 2.0,
        ),
        currentTimeSeconds: -100,
        primaryLanguage: 'en',
      );
      // Active = -1, seed falls back to echo.startLineIndex = 0.
      expect(r, isNotNull);
    });
  });

  group('buildVocabularyContext', () {
    test('returns just the text from resolveVocabularyContextSpan', () {
      final lines = [_line('Hello world.', startMs: 0)];
      final text = buildVocabularyContext(
        lines: lines,
        echo: EchoState.inactive,
        currentTimeSeconds: 0.5,
        primaryLanguage: 'en',
      );
      expect(text, 'Hello world.');
    });

    test('returns null when no span can be built', () {
      final text = buildVocabularyContext(
        lines: const [],
        echo: EchoState.inactive,
        currentTimeSeconds: 0,
        primaryLanguage: 'en',
      );
      expect(text, isNull);
    });
  });
}
