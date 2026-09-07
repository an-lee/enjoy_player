import 'package:enjoy_player/core/utils/avatar_url.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('rasterAvatarUrl', () {
    test('returns null for null input', () {
      expect(rasterAvatarUrl(null), isNull);
    });

    test('returns null for empty string', () {
      expect(rasterAvatarUrl(''), isNull);
    });

    test('rewrites dicebear svg to png', () {
      expect(
        rasterAvatarUrl('https://api.dicebear.com/7.x/thumbs/svg?seed=abc'),
        'https://api.dicebear.com/7.x/thumbs/png?seed=abc',
      );
    });

    test('leaves non-dicebear urls unchanged', () {
      const url = 'https://example.com/avatar.png';
      expect(rasterAvatarUrl(url), url);
    });

    test('leaves dicebear non-svg paths unchanged', () {
      const url = 'https://api.dicebear.com/7.x/thumbs/png?seed=abc';
      expect(rasterAvatarUrl(url), url);
    });

    test('returns original for unparseable url', () {
      const url = 'not a url :: invalid';
      expect(rasterAvatarUrl(url), url);
    });
  });
}
