import 'package:azure_speech/azure_speech.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/shadow_reading/domain/assessment_word_timing.dart';

AzureWordAssessment _word({
  required String text,
  required int offset,
  required int duration,
  String errorType = 'None',
  double accuracy = 90,
}) {
  return AzureWordAssessment(
    word: text,
    offset: offset,
    duration: duration,
    pronunciationAssessment: AzureWordPronunciationAssessment(
      accuracyScore: accuracy,
      errorType: errorType,
    ),
  );
}

void main() {
  group('azureTicksToMs', () {
    test('10000000 ticks is 1000 ms', () {
      expect(azureTicksToMs(10000000), 1000);
    });

    test('zero and negative return 0', () {
      expect(azureTicksToMs(0), 0);
      expect(azureTicksToMs(-1), 0);
    });
  });

  group('isWordClipUsable', () {
    test('usable when duration > 0 and not omission', () {
      expect(
        isWordClipUsable(_word(text: 'hi', offset: 0, duration: 10000000)),
        isTrue,
      );
    });

    test('unusable for omission or zero duration', () {
      expect(
        isWordClipUsable(
          _word(
            text: 'hi',
            offset: 0,
            duration: 10000000,
            errorType: 'Omission',
          ),
        ),
        isFalse,
      );
      expect(
        isWordClipUsable(_word(text: 'hi', offset: 0, duration: 0)),
        isFalse,
      );
    });
  });

  group('activeWordIndex', () {
    final words = [
      _word(text: 'hi', offset: 0, duration: 10000000),
      _word(text: 'skip', offset: 10000000, duration: 0, errorType: 'Omission'),
      _word(text: 'there', offset: 20000000, duration: 10000000),
    ];

    test('maps position into first word', () {
      expect(activeWordIndex(words, 0), 0);
      expect(activeWordIndex(words, 999), 0);
    });

    test('gap and omission produce null current', () {
      expect(activeWordIndex(words, 1000), isNull);
      expect(activeWordIndex(words, 1500), isNull);
    });

    test('maps into later timed word', () {
      expect(activeWordIndex(words, 2000), 2);
      expect(activeWordIndex(words, 2999), 2);
      expect(activeWordIndex(words, 3000), isNull);
    });
  });

  group('wordClipBounds', () {
    test('returns start/end durations', () {
      final bounds = wordClipBounds(
        _word(text: 'hi', offset: 10000000, duration: 5000000),
      );
      expect(bounds, isNotNull);
      expect(bounds!.start, const Duration(milliseconds: 1000));
      expect(bounds.end, const Duration(milliseconds: 1500));
    });

    test('null when unusable', () {
      expect(wordClipBounds(_word(text: 'x', offset: 0, duration: 0)), isNull);
    });
  });
}
