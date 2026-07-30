import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/pronounce/domain/pronounce_locale.dart';

void main() {
  group('resolvePronounceLocale', () {
    test('maps en-UK to en-GB', () {
      expect(resolvePronounceLocale('en-UK'), 'en-GB');
      expect(resolvePronounceLocale('en-GB'), 'en-GB');
    });

    test('maps other English tags to en-US', () {
      expect(resolvePronounceLocale('en-US'), 'en-US');
      expect(resolvePronounceLocale('en'), 'en-US');
      expect(resolvePronounceLocale('en-AU'), 'en-US');
    });

    test('exact-matches learning/lookup allowlist', () {
      expect(resolvePronounceLocale('zh-CN'), 'zh-CN');
      expect(resolvePronounceLocale('ja-JP'), 'ja-JP');
      expect(resolvePronounceLocale('ko-KR'), 'ko-KR');
      expect(resolvePronounceLocale('es-ES'), 'es-ES');
      expect(resolvePronounceLocale('es-MX'), 'es-MX');
      expect(resolvePronounceLocale('fr-FR'), 'fr-FR');
      expect(resolvePronounceLocale('fr-CA'), 'fr-CA');
      expect(resolvePronounceLocale('de-DE'), 'de-DE');
      expect(resolvePronounceLocale('it-IT'), 'it-IT');
      expect(resolvePronounceLocale('pt-BR'), 'pt-BR');
      expect(resolvePronounceLocale('pt-PT'), 'pt-PT');
      expect(resolvePronounceLocale('ru-RU'), 'ru-RU');
    });

    test('maps bare primaries to regional defaults', () {
      expect(resolvePronounceLocale('ja'), 'ja-JP');
      expect(resolvePronounceLocale('zh'), 'zh-CN');
      expect(resolvePronounceLocale('ko'), 'ko-KR');
      expect(resolvePronounceLocale('es'), 'es-ES');
      expect(resolvePronounceLocale('fr'), 'fr-FR');
      expect(resolvePronounceLocale('de'), 'de-DE');
      expect(resolvePronounceLocale('it'), 'it-IT');
      expect(resolvePronounceLocale('pt'), 'pt-BR');
      expect(resolvePronounceLocale('ru'), 'ru-RU');
    });

    test('maps unknown regions of known primaries to defaults', () {
      expect(resolvePronounceLocale('ja-JP'), 'ja-JP');
      expect(resolvePronounceLocale('es-AR'), 'es-ES');
      expect(resolvePronounceLocale('pt-AO'), 'pt-BR');
    });

    test('returns null for unsupported or empty', () {
      expect(resolvePronounceLocale(null), isNull);
      expect(resolvePronounceLocale(''), isNull);
      expect(resolvePronounceLocale('   '), isNull);
      expect(resolvePronounceLocale('ar-SA'), isNull);
      expect(resolvePronounceLocale('und'), isNull);
    });
  });

  group('isPronounceTextEligible', () {
    test('rejects empty and over-length', () {
      expect(isPronounceTextEligible(''), isFalse);
      expect(isPronounceTextEligible('   '), isFalse);
      expect(isPronounceTextEligible('a' * (kPronounceMaxChars + 1)), isFalse);
    });

    test('accepts trimmed text within limit', () {
      expect(isPronounceTextEligible(' hello '), isTrue);
      expect(isPronounceTextEligible('a' * kPronounceMaxChars), isTrue);
    });
  });
}
