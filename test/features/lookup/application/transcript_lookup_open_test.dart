import 'package:enjoy_player/features/lookup/application/transcript_lookup_open.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('resolveLookupSourceLanguage', () {
    test('prefers chromeLanguage when set and non-und', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: 'ja-JP',
          activeTrackLanguage: 'en-US',
        ),
        'ja-JP',
      );
    });

    test('trims whitespace on chromeLanguage', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: '  ko-KR  ',
          activeTrackLanguage: 'en-US',
        ),
        'ko-KR',
      );
    });

    test('falls back to activeTrackLanguage when chromeLanguage is und', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: 'und',
          activeTrackLanguage: 'de-DE',
        ),
        'de-DE',
      );
    });

    test('falls back when chromeLanguage is empty', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: '',
          activeTrackLanguage: 'fr-FR',
        ),
        'fr-FR',
      );
    });

    test('falls back when chromeLanguage is whitespace', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: '   ',
          activeTrackLanguage: 'fr-FR',
        ),
        'fr-FR',
      );
    });

    test('falls back when chromeLanguage is null', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: null,
          activeTrackLanguage: 'es-ES',
        ),
        'es-ES',
      );
    });

    test('returns null when both are und', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: 'und',
          activeTrackLanguage: 'und',
        ),
        isNull,
      );
    });

    test('returns null when chromeLanguage und and activeTrack null', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: 'und',
          activeTrackLanguage: null,
        ),
        isNull,
      );
    });

    test('returns null when chromeLanguage empty and activeTrack und', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: '',
          activeTrackLanguage: 'und',
        ),
        isNull,
      );
    });

    test('trims activeTrackLanguage whitespace', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: 'und',
          activeTrackLanguage: '  ja-JP  ',
        ),
        'ja-JP',
      );
    });

    test('returns null when both are null', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: null,
          activeTrackLanguage: null,
        ),
        isNull,
      );
    });

    test('precedence: chrome wins even if activeTrack is also valid', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: 'en-US',
          activeTrackLanguage: 'ja-JP',
        ),
        'en-US',
      );
    });

    test('precedence: chrome und does not win over activeTrack', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: 'und',
          activeTrackLanguage: 'ja-JP',
        ),
        'ja-JP',
      );
    });

    test('chrome "und" with whitespace still falls back', () {
      expect(
        resolveLookupSourceLanguage(
          chromeLanguage: '  und  ',
          activeTrackLanguage: 'ko-KR',
        ),
        'ko-KR',
      );
    });
  });
}
