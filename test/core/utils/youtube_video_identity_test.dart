import 'package:enjoy_player/core/utils/youtube_video_identity.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('youtubeImportPlaceholderTitle', () {
    test('formats fallback title', () {
      expect(
        youtubeImportPlaceholderTitle('dQw4w9WgXcQ'),
        'YouTube video dQw4w9WgXcQ',
      );
    });
  });

  group('isYoutubeImportPlaceholderTitle', () {
    const vid = 'dQw4w9WgXcQ';

    test('true for fallback title', () {
      expect(
        isYoutubeImportPlaceholderTitle('YouTube video $vid', vid),
        isTrue,
      );
    });

    test('true for bare video id', () {
      expect(isYoutubeImportPlaceholderTitle(vid, vid), isTrue);
    });

    test('true for empty title', () {
      expect(isYoutubeImportPlaceholderTitle('', vid), isTrue);
    });

    test('false for real title', () {
      expect(
        isYoutubeImportPlaceholderTitle('Never Gonna Give You Up', vid),
        isFalse,
      );
    });
  });

  group('bareYoutubeIdRegExp', () {
    test('matches canonical 11-char id', () {
      expect(bareYoutubeIdRegExp.hasMatch('dQw4w9WgXcQ'), isTrue);
    });

    test('matches ids that include underscore and dash', () {
      expect(bareYoutubeIdRegExp.hasMatch('a_b-c12345'), isTrue);
    });

    test('rejects too-short input', () {
      expect(bareYoutubeIdRegExp.hasMatch('short'), isFalse);
    });

    test('rejects too-long input', () {
      expect(
        bareYoutubeIdRegExp.hasMatch('dQw4w9WgXcQextra'),
        isFalse,
      );
    });

    test('rejects embedded ids (anchor required)', () {
      expect(
        bareYoutubeIdRegExp.hasMatch('https://youtu.be/dQw4w9WgXcQ'),
        isFalse,
      );
    });

    test('rejects empty input', () {
      expect(bareYoutubeIdRegExp.hasMatch(''), isFalse);
    });

    test('rejects ids containing forbidden chars', () {
      expect(bareYoutubeIdRegExp.hasMatch('dQw4w9WgXc!'), isFalse);
    });
  });
}
