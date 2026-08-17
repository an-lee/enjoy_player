import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/subtitle/ipa_mapping.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/data/subtitle/transcript_word_ipa.dart';

void main() {
  group('convertIpaToNormal', () {
    test('maps uncommon phonemes to familiar forms', () {
      expect(convertIpaToNormal('ɹ'), 'r');
      expect(convertIpaToNormal('əʊ'), 'oʊ');
      expect(convertIpaToNormal('ɛ'), 'e');
      expect(convertIpaToNormal('a'), 'ɑ');
      expect(convertIpaToNormal('ɡ'), 'g');
    });

    test('drops phonemes mapped to empty string', () {
      expect(convertIpaToNormal('ç'), '');
      expect(convertIpaToNormal('ʕ'), '');
    });

    test('passes through unmapped phonemes', () {
      expect(convertIpaToNormal('ə'), 'ə');
      expect(convertIpaToNormal('ʃ'), 'ʃ');
    });

    test('optionally re-attaches stress marks', () {
      expect(convertIpaToNormal('ˈɹ', marked: true), 'ˈr');
      expect(convertIpaToNormal('ˈɹ', marked: false), 'r');
    });
  });

  group('tokenizeIpaPhonemes', () {
    test('splits concatenated eSpeak word IPA into phonemes', () {
      expect(tokenizeIpaPhonemes('pɹɪri'), ['p', 'ɹ', 'ɪ', 'r', 'i']);
      expect(tokenizeIpaPhonemes('slɛpt'), ['s', 'l', 'ɛ', 'p', 't']);
      expect(tokenizeIpaPhonemes('naɪt'), ['n', 'aɪ', 't']);
    });

    test('keeps stress attached to the following phoneme', () {
      expect(tokenizeIpaPhonemes('həˈloʊ'), ['h', 'ə', 'ˈl', 'oʊ']);
    });
  });

  group('convertWordIpaToNormal', () {
    test('converts each phoneme in a word', () {
      expect(convertWordIpaToNormal(['h', 'ə', 'ˈl', 'oʊ']), [
        'h',
        'ə',
        'l',
        'oʊ',
      ]);
      expect(convertWordIpaToNormal(['h', 'ə', 'l', 'ˈoʊ']), [
        'h',
        'ə',
        'ˈl',
        'oʊ',
      ]);
    });

    test('maps ɹ → r and əʊ → oʊ across a word', () {
      expect(convertWordIpaToNormal(['ɹ', 'əʊ', 'd']), ['r', 'oʊ', 'd']);
    });
  });

  group('formatPhonesAsFamiliarIpa', () {
    test('joins converted phones and skips placeholders', () {
      expect(formatPhonesAsFamiliarIpa(['h', 'ə', 'ɹ', 'oʊ']), 'həroʊ');
      expect(formatPhonesAsFamiliarIpa(['h', '?', '', 'ə']), 'hə');
    });

    test('returns empty string when nothing remains', () {
      expect(formatPhonesAsFamiliarIpa(['?', '']), '');
    });

    test('remaps concatenated eSpeak chunks', () {
      expect(formatPhonesAsFamiliarIpa(['pɹɪri']), 'prɪri');
      expect(formatPhonesAsFamiliarIpa(['slɛpt']), 'slept');
      expect(formatPhonesAsFamiliarIpa(['wɛl']), 'wel');
      expect(formatPhonesAsFamiliarIpa(['naɪt']), 'naɪt');
    });
  });

  group('wordIpaSpelling', () {
    test('returns familiar-form join of stored phones', () {
      const word = TranscriptWord(
        text: 'pretty',
        phones: [
          TranscriptPhone(
            phone: 'pɹɪri',
            text: 'pɹɪri',
            startTime: 0,
            endTime: 0.2,
          ),
        ],
      );
      expect(wordIpaSpelling(word), 'prɪri');
    });

    test('returns null when there are no stored phones', () {
      expect(wordIpaSpelling(const TranscriptWord(text: 'Hello')), isNull);
    });
  });
}
