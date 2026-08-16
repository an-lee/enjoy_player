import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/data/subtitle/transcript_word_ipa.dart';

void main() {
  group('wordIpaPieces', () {
    test('concatenates ordered non-empty phone labels', () {
      const word = TranscriptWord(
        text: 'an',
        phones: [
          TranscriptPhone(phone: 'æ', text: 'æ', startTime: 0, endTime: 0.05),
          TranscriptPhone(phone: 'n', text: 'n', startTime: 0.05, endTime: 0.1),
        ],
      );
      expect(wordIpaPieces(word), ['æ', 'n']);
    });

    test('skips empty and whitespace-only pieces', () {
      const word = TranscriptWord(
        text: 'an',
        phones: [
          TranscriptPhone(phone: 'æ', text: 'æ', startTime: 0, endTime: 0.05),
          TranscriptPhone(
            phone: '  ',
            text: '',
            startTime: 0.05,
            endTime: 0.08,
          ),
          TranscriptPhone(phone: '', text: '', startTime: 0.08, endTime: 0.1),
          TranscriptPhone(phone: 'n', text: 'n', startTime: 0.1, endTime: 0.15),
        ],
      );
      expect(wordIpaPieces(word), ['æ', 'n']);
    });

    test('returns empty when phones are missing', () {
      const word = TranscriptWord(text: 'Hello');
      expect(wordIpaPieces(word), isEmpty);
    });
  });

  group('wordIpaSpelling', () {
    test('joins pieces without inventing labels', () {
      const word = TranscriptWord(
        text: 'an',
        phones: [
          TranscriptPhone(phone: 'æ', text: 'æ', startTime: 0, endTime: 0.05),
          TranscriptPhone(phone: 'n', text: 'n', startTime: 0.05, endTime: 0.1),
        ],
      );
      expect(wordIpaSpelling(word), 'æn');
    });

    test('returns null when there are no stored phones', () {
      expect(wordIpaSpelling(const TranscriptWord(text: 'Hello')), isNull);
      expect(
        wordIpaSpelling(
          const TranscriptWord(
            text: 'Hello',
            phones: [
              TranscriptPhone(
                phone: '   ',
                text: '',
                startTime: 0,
                endTime: 0.1,
              ),
            ],
          ),
        ),
        isNull,
      );
    });
  });
}
