import 'package:enjoy_player/features/ai/domain/prompts/contextual_translation_prompt.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('getContextualTranslationSystemPrompt', () {
    test('returns Chinese prompt for "zh" target', () {
      final p = getContextualTranslationSystemPrompt('zh');
      expect(p, contains('语言学习助手'));
      expect(p, contains('## 翻译'));
    });

    test('returns Chinese prompt for "zh-CN" BCP-47 tag', () {
      final p = getContextualTranslationSystemPrompt('zh-CN');
      expect(p, contains('语言学习助手'));
    });

    test('returns Chinese prompt for "zh-Hans" (lowercased)', () {
      final p = getContextualTranslationSystemPrompt('zh-Hans');
      expect(p, contains('语言学习助手'));
    });

    test('returns English prompt for unknown tags', () {
      final p = getContextualTranslationSystemPrompt('fr');
      expect(p, contains('expert language learning assistant'));
      expect(p, contains('## Translation'));
    });

    test('returns English prompt for "en"', () {
      final p = getContextualTranslationSystemPrompt('en-US');
      expect(p, contains('expert language learning assistant'));
    });
  });

  group('buildContextualTranslationUserPrompt', () {
    test('formats with context when provided', () {
      final p = buildContextualTranslationUserPrompt(
        text: 'bonjour',
        context: 'un matin à Paris',
      );
      expect(p, 'Context: un matin à Paris\n\nText to translate: bonjour');
    });

    test('trims trailing/leading whitespace in context', () {
      final p = buildContextualTranslationUserPrompt(
        text: 'merci',
        context: '   thank you scene   ',
      );
      expect(p, 'Context: thank you scene\n\nText to translate: merci');
    });

    test('omits context line when context is null', () {
      final p = buildContextualTranslationUserPrompt(text: 'hola');
      expect(p, 'Text to translate: hola');
    });

    test('omits context line when context is empty', () {
      final p = buildContextualTranslationUserPrompt(text: 'hola', context: '');
      expect(p, 'Text to translate: hola');
    });

    test('omits context line when context is whitespace-only', () {
      final p = buildContextualTranslationUserPrompt(
        text: 'hola',
        context: '   \n  ',
      );
      expect(p, 'Text to translate: hola');
    });
  });
}
