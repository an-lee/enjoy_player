import 'package:enjoy_player/core/application/cjk_language.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isCjkLanguage', () {
    test('returns true for Chinese, Japanese, Korean region tags', () {
      expect(isCjkLanguage('zh-CN'), isTrue);
      expect(isCjkLanguage('zh-TW'), isTrue);
      expect(isCjkLanguage('zh-HK'), isTrue);
      expect(isCjkLanguage('ja-JP'), isTrue);
      expect(isCjkLanguage('ko-KR'), isTrue);
    });

    test('returns true for lowercase and underscore variants', () {
      expect(isCjkLanguage('zh-cn'), isTrue);
      expect(isCjkLanguage('ja_jp'), isTrue);
      expect(isCjkLanguage('KO-KR'), isTrue);
    });

    test('returns true for ISO 639-3 aliases', () {
      expect(isCjkLanguage('zho-CN'), isTrue);
      expect(isCjkLanguage('jpn-JP'), isTrue);
      expect(isCjkLanguage('kor-KR'), isTrue);
    });

    test('returns true for bare primary subtags', () {
      expect(isCjkLanguage('zh'), isTrue);
      expect(isCjkLanguage('ja'), isTrue);
      expect(isCjkLanguage('ko'), isTrue);
    });

    test('returns false for non-CJK languages', () {
      expect(isCjkLanguage('en-US'), isFalse);
      expect(isCjkLanguage('fr-FR'), isFalse);
      expect(isCjkLanguage('de-DE'), isFalse);
      expect(isCjkLanguage('es-ES'), isFalse);
      expect(isCjkLanguage('pt-BR'), isFalse);
      expect(isCjkLanguage('ru-RU'), isFalse);
    });

    test('returns false for empty or malformed input', () {
      expect(isCjkLanguage(''), isFalse);
      expect(isCjkLanguage('-'), isFalse);
      expect(isCjkLanguage('--'), isFalse);
    });
  });
}
