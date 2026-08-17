import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/subtitle/attach_phonemes_to_lines.dart';
import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';

void main() {
  test(
    'attaches untimed words and IPA labels without changing line identity',
    () {
      const lines = [
        TranscriptLine(text: 'Hello world', startMs: 1200, durationMs: 800),
      ];
      final attached = attachPhonemesToLines(lines, const [
        PhonemizeLineResult(
          words: [
            PhonemeWord(text: 'Hello', phones: ['h', 'ə']),
            PhonemeWord(text: 'world', phones: ['w']),
          ],
        ),
      ]);

      expect(attached, hasLength(1));
      expect(attached.single.text, 'Hello world');
      expect(attached.single.startMs, 1200);
      expect(attached.single.durationMs, 800);
      expect(attached.single.timeline, hasLength(2));
      expect(
        attached.single.timeline!.first.toJson().containsKey('start'),
        isFalse,
      );
      expect(
        attached.single.timeline!.first.toJson().containsKey('duration'),
        isFalse,
      );
      expect(attached.single.timeline!.first.phones!.first.phone, 'h');
      expect(attached.single.timeline!.first.phones!.first.startTime, isNull);
      expect(wordMediaWindowMs(attached.single, 0), isNull);
    },
  );

  test('empty phoneme result leaves that cue line-only', () {
    const lines = [
      TranscriptLine(text: 'Hello', startMs: 0, durationMs: 500),
      TranscriptLine(text: '...', startMs: 500, durationMs: 200),
    ];
    final attached = attachPhonemesToLines(lines, const [
      PhonemizeLineResult(
        words: [
          PhonemeWord(text: 'Hello', phones: ['h']),
        ],
      ),
      PhonemizeLineResult(words: []),
    ]);
    expect(attached.first.timeline, isNotNull);
    expect(attached.last.timeline, isNull);
    expect(attached.last.text, '...');
  });
}
