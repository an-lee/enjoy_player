import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/ai/domain/models/asr_result.dart';

void main() {
  test(
    'AsrResult.fromJson parses transcriptionInfo when nested map is Map<dynamic, dynamic>',
    () {
      final nested = <dynamic, dynamic>{'language': 'en', 'duration': 1.25};
      final json = <String, dynamic>{
        'text': 'hello',
        'transcriptionInfo': nested,
      };
      final r = AsrResult.fromJson(json);
      expect(r.text, 'hello');
      expect(r.language, 'en');
      expect(r.duration, 1.25);
    },
  );

  test(
    'AsrResult.fromJson parses transcriptionInfo from jsonDecode nested maps',
    () {
      final decoded = jsonDecode(
        '{"text":"hello","transcriptionInfo":{"language":"en","duration":1.25}}',
      );
      final top = Map<String, dynamic>.from(decoded as Map);
      final r = AsrResult.fromJson(top);
      expect(r.text, 'hello');
      expect(r.language, 'en');
      expect(r.duration, 1.25);
    },
  );

  test('AsrResult.fromJson parses segments with words', () {
    final json = <String, dynamic>{
      'text': 'hello world',
      'segments': [
        {
          'start': 0.0,
          'end': 1.5,
          'text': 'hello',
          'words': [
            {'word': 'hello', 'start': 0.0, 'end': 0.8},
          ],
        },
        {'start': 1.5, 'end': 3.0, 'text': 'world'},
      ],
    };
    final r = AsrResult.fromJson(json);
    expect(r.segments, isNotNull);
    expect(r.segments!.length, 2);
    final seg0 = r.segments![0];
    expect(seg0.start, 0.0);
    expect(seg0.end, 1.5);
    expect(seg0.text, 'hello');
    expect(seg0.words, isNotNull);
    expect(seg0.words!.length, 1);
    expect(seg0.words![0].word, 'hello');
    expect(seg0.words![0].start, 0.0);
    expect(seg0.words![0].end, 0.8);
    final seg1 = r.segments![1];
    expect(seg1.words, isNull);
  });

  test('AsrSegment.fromJson handles missing fields gracefully', () {
    final seg = AsrSegment.fromJson(const {});
    expect(seg.start, 0);
    expect(seg.end, 0);
    expect(seg.text, '');
    expect(seg.words, isNull);
  });

  test('AsrWord.fromJson handles missing fields gracefully', () {
    final word = AsrWord.fromJson(const {});
    expect(word.word, '');
    expect(word.start, 0);
    expect(word.end, 0);
  });

  test('AsrResult.fromJson parses wordCount from snake_case', () {
    final json = <String, dynamic>{'text': 'test', 'word_count': 42};
    final r = AsrResult.fromJson(json);
    expect(r.wordCount, 42);
  });

  test('AsrResult.fromJson language falls back to top-level', () {
    final json = <String, dynamic>{'text': 'test', 'language': 'fr'};
    final r = AsrResult.fromJson(json);
    expect(r.language, 'fr');
  });
}
