// Coverage: lib/features/ai/domain/prompts/dictionary_prompt.dart
import 'package:enjoy_player/features/ai/domain/prompts/dictionary_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('buildDictionarySystemPrompt', () {
    test('mentions source/target languages', () {
      final prompt = buildDictionarySystemPrompt(
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(prompt, contains('en'));
      expect(prompt, contains('zh'));
    });

    test('requires JSON-only output schema', () {
      final prompt = buildDictionarySystemPrompt(
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(prompt, contains('JSON'));
      expect(prompt, contains('"word"'));
      expect(prompt, contains('"senses"'));
      expect(prompt, contains('"definition"'));
      expect(prompt, contains('"translation"'));
    });

    test('handles unknown language tags without crashing', () {
      final prompt = buildDictionarySystemPrompt(
        sourceLanguage: 'xx',
        targetLanguage: 'yy',
      );
      expect(prompt, isNotEmpty);
      expect(prompt, contains('dictionary'));
    });

    test('handles BCP-47 language tags', () {
      final prompt = buildDictionarySystemPrompt(
        sourceLanguage: 'zh-CN',
        targetLanguage: 'en-US',
      );
      // workerLanguageBase should extract the base 'zh' / 'en'
      expect(prompt, contains('zh'));
      expect(prompt, contains('en'));
    });

    test('returns consistent structure across calls', () {
      final a = buildDictionarySystemPrompt(
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      final b = buildDictionarySystemPrompt(
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a, b);
    });
  });

  group('buildDictionaryUserPrompt', () {
    test('returns the requested word', () {
      expect(buildDictionaryUserPrompt('bonjour'), contains('bonjour'));
    });

    test('preserves the word verbatim', () {
      expect(
        buildDictionaryUserPrompt('hola mundo'),
        'Look up the word or phrase: hola mundo',
      );
    });

    test('handles empty word', () {
      expect(buildDictionaryUserPrompt(''), contains('Look up'));
    });

    test('handles unicode word', () {
      final p = buildDictionaryUserPrompt('你好');
      expect(p, contains('你好'));
    });
  });
}
