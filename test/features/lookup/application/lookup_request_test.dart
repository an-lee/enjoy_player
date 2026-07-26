import 'package:enjoy_player/features/lookup/application/lookup_section_params.dart';
import 'package:enjoy_player/features/lookup/domain/lookup_request.dart';
import 'package:enjoy_player/features/vocabulary/application/media_vocabulary_context_builder.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('LookupRequest', () {
    test('constructs with required fields and null optionals', () {
      const r = LookupRequest(
        selectedText: 'hello',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      expect(r.selectedText, 'hello');
      expect(r.sourceLanguage, 'en-US');
      expect(r.targetLanguage, 'zh-CN');
      expect(r.contextualContext, isNull);
      expect(r.mediaVocabularyContext, isNull);
    });

    test('copyWith preserves unmodified fields', () {
      const ctx = MediaVocabularyContext(
        text: 'hello',
        sourceType: VocabularySourceType.video,
        sourceId: 'm-1',
        locator: MediaLocator(start: 0, duration: 1000),
      );
      const r = LookupRequest(
        selectedText: 'hello',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
        contextualContext: 'surrounding',
        mediaVocabularyContext: ctx,
      );
      final copy = r.copyWith(targetLanguage: 'ja-JP');
      expect(copy.selectedText, 'hello');
      expect(copy.targetLanguage, 'ja-JP');
      expect(copy.contextualContext, 'surrounding');
      expect(copy.mediaVocabularyContext, ctx);
    });

    test('copyWith sets optional fields when provided', () {
      const r = LookupRequest(
        selectedText: 'hello',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      final copy = r.copyWith(contextualContext: 'around');
      expect(copy.contextualContext, 'around');
    });
  });

  group('LookupTextParams equality', () {
    test('translation params equal when text + pair matches', () {
      const a = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      const b = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('translation params differ when text differs', () {
      const a = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      const b = LookupTranslationParams(
        text: 'bye',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      expect(a, isNot(equals(b)));
    });

    test('translation params differ when languages differ', () {
      const a = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      const b = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'ja-JP',
        targetLanguage: 'zh-CN',
      );
      expect(a, isNot(equals(b)));
    });

    test('translation params with same fields hash to the same value', () {
      const a = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      const b = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      expect(a.hashCode, b.hashCode);
    });

    test('translation params with different text hash differently', () {
      const a = LookupTranslationParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      const b = LookupTranslationParams(
        text: 'bye',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      expect(a.hashCode, isNot(b.hashCode));
    });

    test('contextual params equal when context matches', () {
      const a = LookupContextualParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
        context: 'surrounding',
      );
      const b = LookupContextualParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
        context: 'surrounding',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('contextual params differ when context differs', () {
      const a = LookupContextualParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
        context: 'one',
      );
      const b = LookupContextualParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
        context: 'two',
      );
      expect(a, isNot(equals(b)));
    });

    test('contextual params with null context equal each other', () {
      const a = LookupContextualParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      const b = LookupContextualParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('dictionary params equal when all fields match', () {
      const a = LookupDictionaryParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      const b = LookupDictionaryParams(
        text: 'hi',
        sourceLanguage: 'en-US',
        targetLanguage: 'zh-CN',
      );
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });
  });
}
