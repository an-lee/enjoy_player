import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/features/lookup/application/lookup_target_languages.dart';
import 'package:enjoy_player/features/lookup/application/sentence_boundaries.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('canonicalLookupTag', () {
    test('maps en/zh primaries to their canonical native tags', () {
      expect(canonicalLookupTag('en'), 'en-US');
      expect(canonicalLookupTag('en-us'), 'en-US');
      expect(canonicalLookupTag('zh-CN'), 'zh-CN');
      expect(canonicalLookupTag('zh'), 'zh-CN');
    });

    test('returns null for unknown or invalid tags', () {
      expect(canonicalLookupTag(null), isNull);
      expect(canonicalLookupTag(''), isNull);
      expect(canonicalLookupTag('und'), isNull);
      expect(canonicalLookupTag('klingon'), isNull);
    });

    test(
      'returns null for non-en/zh primary subtags (native catalog is 2)',
      () {
        expect(canonicalLookupTag('ja-JP'), isNull);
        expect(canonicalLookupTag('ko'), isNull);
      },
    );
  });

  group('canonicalFocusLanguageTag', () {
    test('returns exact match from kSupportedFocusLanguageTags', () {
      expect(canonicalFocusLanguageTag('en-US'), 'en-US');
      expect(canonicalFocusLanguageTag('ja-JP'), 'ja-JP');
      expect(canonicalFocusLanguageTag('fr-CA'), 'fr-CA');
    });

    test('falls back to primary-subtag match (e.g. ja → ja-JP)', () {
      expect(canonicalFocusLanguageTag('ja'), 'ja-JP');
      expect(canonicalFocusLanguageTag('KO'), 'ko-KR');
    });

    test('returns default for empty / unknown tags', () {
      expect(canonicalFocusLanguageTag(null), kDefaultLearningLanguageTag);
      expect(canonicalFocusLanguageTag(''), kDefaultLearningLanguageTag);
      expect(canonicalFocusLanguageTag('klingon'), kDefaultLearningLanguageTag);
    });
  });

  group('canonicalMediaLanguageTag', () {
    test('preserves kUnknownMediaLanguageTag', () {
      expect(canonicalMediaLanguageTag(null), kUnknownMediaLanguageTag);
      expect(canonicalMediaLanguageTag(''), kUnknownMediaLanguageTag);
      expect(canonicalMediaLanguageTag('und'), kUnknownMediaLanguageTag);
    });

    test('returns exact match when supported', () {
      expect(canonicalMediaLanguageTag('en-US'), 'en-US');
      expect(canonicalMediaLanguageTag('ja-JP'), 'ja-JP');
    });

    test('falls back to primary-subtag match', () {
      expect(canonicalMediaLanguageTag('ja'), 'ja-JP');
    });

    test('keeps unknown but valid tag verbatim as a last resort', () {
      // "klingon" is not unknown (not in kInvalidLanguageTags) so we keep it.
      expect(canonicalMediaLanguageTag('klingon'), 'klingon');
    });
  });

  group('matchesLanguageBroad', () {
    test('exact match returns true', () {
      expect(matchesLanguageBroad('en-US', 'en-US'), isTrue);
      expect(matchesLanguageBroad('ja-JP', 'ja-JP'), isTrue);
    });

    test('primary-subtag match returns true', () {
      expect(matchesLanguageBroad('en-US', 'en-GB'), isTrue);
      expect(matchesLanguageBroad('zh-CN', 'zh-TW'), isTrue);
    });

    test('different primaries return false', () {
      expect(matchesLanguageBroad('en-US', 'ja-JP'), isFalse);
    });

    test('null inputs return false', () {
      expect(matchesLanguageBroad(null, 'en-US'), isFalse);
      expect(matchesLanguageBroad('en-US', null), isFalse);
      expect(matchesLanguageBroad(null, null), isFalse);
    });
  });

  group('normalizeBcp47Tag + tagsEqual', () {
    test('lowercases primary + uppercases region', () {
      expect(normalizeBcp47Tag('EN-us'), 'en-US');
      expect(normalizeBcp47Tag('JA-jp'), 'ja-JP');
    });

    test('keeps single-subtag tags lowercased', () {
      expect(normalizeBcp47Tag('EN'), 'en');
      expect(normalizeBcp47Tag('ja'), 'ja');
    });

    test('tagsEqual normalizes both sides', () {
      expect(tagsEqual('en-us', 'EN-US'), isTrue);
      expect(tagsEqual('ja-jp', 'ja-JP'), isTrue);
      expect(tagsEqual('en-US', 'en-GB'), isFalse);
    });
  });

  group('primaryLanguageSubtag + normalizeLanguageAlias', () {
    test('returns first subtag lowercased', () {
      expect(primaryLanguageSubtag('en-US'), 'en');
      expect(primaryLanguageSubtag('JA-jp'), 'ja');
    });

    test('resolves legacy aliases (kor → ko, eng → en)', () {
      expect(normalizeLanguageAlias('kor'), 'ko');
      expect(normalizeLanguageAlias('ENG'), 'en');
      expect(normalizeLanguageAlias('kor-KR'), 'ko-KR');
      expect(normalizeLanguageAlias('chi'), 'zh');
    });

    test('returns input untouched when no alias matches', () {
      expect(normalizeLanguageAlias('xyz'), 'xyz');
    });

    test('handles empty / whitespace input', () {
      expect(normalizeLanguageAlias(''), '');
      expect(primaryLanguageSubtag(''), '');
      // whitespace is not aliased, so it stays as whitespace
      // (no language subtag to extract).
    });
  });

  group('workerLanguageBase', () {
    test('returns first subtag lowercased', () {
      expect(workerLanguageBase('en-US'), 'en');
      expect(workerLanguageBase('JA-jp'), 'ja');
    });

    test('falls back to "en" for empty input', () {
      expect(workerLanguageBase(''), 'en');
      expect(workerLanguageBase('   '), 'en');
    });
  });

  group('isValidLanguageTag', () {
    test('true for valid tags', () {
      expect(isValidLanguageTag('en-US'), isTrue);
      expect(isValidLanguageTag('ja'), isTrue);
    });

    test('false for null / empty / denylisted primaries', () {
      expect(isValidLanguageTag(null), isFalse);
      expect(isValidLanguageTag(''), isFalse);
      expect(isValidLanguageTag('und'), isFalse);
      expect(isValidLanguageTag('zxx'), isFalse);
    });
  });

  group('isUnknownMediaLanguageTag', () {
    test('true for null / empty / denylisted primaries', () {
      expect(isUnknownMediaLanguageTag(null), isTrue);
      expect(isUnknownMediaLanguageTag(''), isTrue);
      expect(isUnknownMediaLanguageTag('und'), isTrue);
      expect(isUnknownMediaLanguageTag('mul'), isTrue);
    });

    test('false for real language tags', () {
      expect(isUnknownMediaLanguageTag('en-US'), isFalse);
      expect(isUnknownMediaLanguageTag('ja'), isFalse);
    });
  });

  group('resolveAzureAssessmentLocale', () {
    test('returns canonical tag for direct Azure locale', () {
      expect(resolveAzureAssessmentLocale('en-US'), 'en-US');
      expect(resolveAzureAssessmentLocale('ja-JP'), 'ja-JP');
    });

    test('returns preferred default for primary only', () {
      expect(resolveAzureAssessmentLocale('en'), 'en-US');
      expect(resolveAzureAssessmentLocale('ja'), 'ja-JP');
      expect(resolveAzureAssessmentLocale('fr'), 'fr-FR');
    });

    test('returns null for unsupported tags', () {
      expect(resolveAzureAssessmentLocale(null), isNull);
      expect(resolveAzureAssessmentLocale(''), isNull);
      expect(resolveAzureAssessmentLocale('klingon'), isNull);
      expect(resolveAzureAssessmentLocale('und'), isNull);
    });
  });

  group('resolveAzureAssessmentLocaleForPractice', () {
    test('returns direct locale when supported', () {
      expect(resolveAzureAssessmentLocaleForPractice('en-US'), 'en-US');
    });

    test('falls back to learning language for unknown media', () {
      expect(
        resolveAzureAssessmentLocaleForPractice(
          'und',
          learningLanguage: 'ja-JP',
        ),
        'ja-JP',
      );
    });

    test('returns null for unsupported language (not unknown)', () {
      // "klingon" is not unknown and not supported → null
      expect(
        resolveAzureAssessmentLocaleForPractice(
          'klingon',
          learningLanguage: 'en-US',
        ),
        isNull,
      );
    });

    test('falls back to default learning tag when nothing else matches', () {
      expect(
        resolveAzureAssessmentLocaleForPractice('und'),
        kDefaultLearningLanguageTag,
      );
    });
  });

  group('allowedNativeTags', () {
    test('returns both natives when learning is unsupported', () {
      expect(allowedNativeTags('klingon'), ['en-US', 'zh-CN']);
    });

    test('excludes learning when learning is in native list', () {
      expect(allowedNativeTags('en-US'), ['zh-CN']);
      expect(allowedNativeTags('zh-CN'), ['en-US']);
    });
  });

  group('coerceNativeIfEqualsLearning', () {
    test('returns null input as first allowed native', () {
      expect(coerceNativeIfEqualsLearning(null, 'en-US'), 'zh-CN');
      expect(coerceNativeIfEqualsLearning(null, 'zh-CN'), 'en-US');
    });

    test('returns empty input as first allowed native', () {
      expect(coerceNativeIfEqualsLearning('', 'en-US'), 'zh-CN');
    });

    test('coerces native==learning to the other allowed', () {
      expect(coerceNativeIfEqualsLearning('en-US', 'en-US'), 'zh-CN');
    });

    test('coerces unsupported native to first allowed', () {
      expect(coerceNativeIfEqualsLearning('klingon', 'en-US'), 'zh-CN');
    });

    test('returns supported native as-is', () {
      expect(coerceNativeIfEqualsLearning('zh-CN', 'en-US'), 'zh-CN');
    });
  });

  group('displayLocaleFromRawOrDefault', () {
    test('returns default for null / empty', () {
      expect(displayLocaleFromRawOrDefault(null), kAppDefaultDisplayLocale);
      expect(displayLocaleFromRawOrDefault(''), kAppDefaultDisplayLocale);
    });

    test('returns canonical Locale for supported exact match', () {
      expect(displayLocaleFromRawOrDefault('en-US'), const Locale('en', 'US'));
      expect(displayLocaleFromRawOrDefault('zh-CN'), const Locale('zh', 'CN'));
    });

    test('returns default for unsupported raw tag', () {
      expect(
        displayLocaleFromRawOrDefault('klingon'),
        kAppDefaultDisplayLocale,
      );
    });
  });

  group('localeToBcp47', () {
    test('maps Locale to its BCP-47 string', () {
      expect(localeToBcp47(const Locale('en', 'US')), 'en-US');
      expect(localeToBcp47(const Locale('zh', 'CN')), 'zh-CN');
    });
  });

  group('sortLookupLanguages', () {
    test('groups by primary subtag, with learning primary first', () {
      final input = ['en-GB', 'en-US', 'ja-JP', 'ko-KR'];
      final sorted = sortLookupLanguages(input, learningTag: 'en-US');
      // en-* all share the learning primary → they sort by region (GB < US).
      expect(sorted, ['en-GB', 'en-US', 'ja-JP', 'ko-KR']);
    });

    test('puts learning language first when its primary is unique', () {
      // learning=ja-JP, so ja-JP comes first, then the rest by primary + region.
      final sorted = sortLookupLanguages([
        'en-US',
        'ja-JP',
        'ko-KR',
      ], learningTag: 'ja-JP');
      expect(sorted.first, 'ja-JP');
    });

    test('returns a new list (does not mutate input)', () {
      final input = ['ja-JP', 'en-US'];
      final sorted = sortLookupLanguages(input, learningTag: 'en-US');
      expect(sorted, isNot(same(input)));
      expect(input, ['ja-JP', 'en-US']); // original preserved
    });

    test('preserves stable order for ties by index', () {
      final input = ['en-GB', 'en-US'];
      final sorted = sortLookupLanguages(input, learningTag: 'klingon');
      expect(sorted, ['en-GB', 'en-US']);
    });
  });

  // ── sentence_boundaries ───────────────────────────────────────────────
  group('getSentenceBoundaries', () {
    test('returns empty list for empty input', () {
      expect(getSentenceBoundaries('', 'en'), isEmpty);
    });

    test('finds ASCII sentence terminators in English', () {
      // '. ' terminates at position 10 (after the period AND its trailing space).
      final b = getSentenceBoundaries('Hi there. How are you?', 'en');
      expect(b, isNotEmpty);
      expect(b.first, 'Hi there. '.length);
    });

    test('matches fullwidth punctuation in Chinese', () {
      final text = '你好。今天天气真好。';
      final b = getSentenceBoundaries(text, 'zh-CN');
      expect(b, isNotEmpty);
    });

    test('returns multiple boundaries for multi-sentence input', () {
      final b = getSentenceBoundaries('A. B. C.', 'en');
      expect(b.length, 3);
    });
  });

  // ── lookup_target_languages ───────────────────────────────────────────
  group('resolveLookupSource', () {
    test('returns canonical lookup tag for direct en/zh match', () {
      expect(resolveLookupSource('en-GB', learningTag: 'zh-CN'), 'en-US');
      expect(resolveLookupSource('zh-TW', learningTag: 'en-US'), 'zh-CN');
    });

    test('falls back to lookup catalog via primary-subtag match', () {
      expect(resolveLookupSource('ja', learningTag: 'en-US'), 'ja-JP');
      expect(resolveLookupSource('ko-KR', learningTag: 'en-US'), 'ko-KR');
    });

    test('returns learningTag for unknown / und / empty input', () {
      expect(resolveLookupSource(null, learningTag: 'en-US'), 'en-US');
      expect(resolveLookupSource('und', learningTag: 'en-US'), 'en-US');
      expect(resolveLookupSource('klingon', learningTag: 'en-US'), 'en-US');
    });
  });

  group('resolveLookupSourceOverride', () {
    test('returns null for null / empty / invalid', () {
      expect(resolveLookupSourceOverride(null), isNull);
      expect(resolveLookupSourceOverride(''), isNull);
      expect(resolveLookupSourceOverride('   '), isNull);
      expect(resolveLookupSourceOverride('und'), isNull);
      expect(resolveLookupSourceOverride('klingon'), isNull);
    });

    test('returns canonical tag for direct match', () {
      expect(resolveLookupSourceOverride('ja-JP'), 'ja-JP');
      expect(resolveLookupSourceOverride('en-US'), 'en-US');
    });

    test('resolves primary subtag and legacy aliases', () {
      expect(resolveLookupSourceOverride('ja'), 'ja-JP');
      expect(resolveLookupSourceOverride('kor'), 'ko-KR');
    });
  });

  group('resolveLookupTarget', () {
    test('returns native directly when supported and ≠ learning', () {
      expect(
        resolveLookupTarget(
          'ja-JP',
          learningTag: 'en-US',
          sourceLanguage: 'ko-KR',
        ),
        'ja-JP',
      );
    });

    test(
      'falls back to coerceNativeIfEqualsLearning when native==learning',
      () {
        expect(resolveLookupTarget('en-US', learningTag: 'en-US'), 'zh-CN');
      },
    );

    test('returns null/empty native as first allowed', () {
      expect(resolveLookupTarget(null, learningTag: 'en-US'), 'zh-CN');
      expect(resolveLookupTarget('', learningTag: 'en-US'), 'zh-CN');
    });

    test('primary-subtag fallback skips source and learning', () {
      // de-AT → de-DE (only de-DE is in catalog)
      expect(
        resolveLookupTarget(
          'de-AT',
          learningTag: 'en-US',
          sourceLanguage: 'ja-JP',
        ),
        'de-DE',
      );
    });
  });
}
