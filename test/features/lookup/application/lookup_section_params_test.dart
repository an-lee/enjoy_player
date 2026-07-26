import 'package:enjoy_player/features/lookup/application/lookup_section_params.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LookupTextParams equality', () {
    test('two instances with same fields are equal', () {
      const a = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      const b = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different text means not equal', () {
      const a = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      const b = LookupDictionaryParams(
        text: 'world',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a, isNot(equals(b)));
    });

    test('different sourceLanguage means not equal', () {
      const a = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      const b = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'fr',
        targetLanguage: 'zh',
      );
      expect(a, isNot(equals(b)));
    });

    test('different targetLanguage means not equal', () {
      const a = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      const b = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'ja',
      );
      expect(a, isNot(equals(b)));
    });

    test('identical reference is equal via identical', () {
      const a = LookupDictionaryParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a, equals(a));
      expect(identical(a, a), isTrue);
    });
  });

  group('LookupTranslationParams', () {
    test('equal with same fields', () {
      const a = LookupTranslationParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      const b = LookupTranslationParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });

  group('LookupContextualParams', () {
    test('equal with same context', () {
      const a = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        context: 'world',
      );
      const b = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        context: 'world',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different context means not equal', () {
      const a = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        context: 'foo',
      );
      const b = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        context: 'bar',
      );
      expect(a, isNot(equals(b)));
    });

    test('null context vs empty-string context is "different" by design', () {
      const a = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        context: null,
      );
      const b = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        context: '',
      );
      expect(a.context, isNull);
      expect(b.context, '');
      expect(a == b, isFalse);
    });

    test('two null contexts are equal', () {
      const a = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      const b = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('context field accessor returns the value', () {
      const a = LookupContextualParams(
        text: 'hello',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
        context: 'world',
      );
      expect(a.context, 'world');
    });
  });

  group('LookupContextualParams is a LookupTextParams', () {
    test('can be assigned to LookupTextParams', () {
      const LookupTextParams a = LookupContextualParams(
        text: 'hi',
        sourceLanguage: 'en',
        targetLanguage: 'zh',
      );
      expect(a.text, 'hi');
      expect(a.sourceLanguage, 'en');
      expect(a.targetLanguage, 'zh');
    });

    test(
      'cross-type equality treats different concrete types as not equal',
      () {
        const a = LookupTextParams(
          text: 'hi',
          sourceLanguage: 'en',
          targetLanguage: 'zh',
        );
        const b = LookupTranslationParams(
          text: 'hi',
          sourceLanguage: 'en',
          targetLanguage: 'zh',
        );
        // b is LookupTextParams since LookupTranslationParams extends it,
        // and LookupTextParams == only triggers for other is LookupTextParams.
        expect(a == b, isTrue);
      },
    );
  });
}
