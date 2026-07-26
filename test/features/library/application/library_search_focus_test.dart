import 'package:enjoy_player/features/library/application/library_search_focus.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('librarySearchHotkeyEnabledForPath', () {
    test('returns false on /player/* routes', () {
      expect(librarySearchHotkeyEnabledForPath('/player/abc'), isFalse);
      expect(librarySearchHotkeyEnabledForPath('/player/abc?'), isFalse);
    });

    test('returns false on auth-only routes', () {
      expect(librarySearchHotkeyEnabledForPath('/sign-in'), isFalse);
      expect(librarySearchHotkeyEnabledForPath('/youtube/login'), isFalse);
    });

    test('returns true on shell routes', () {
      expect(librarySearchHotkeyEnabledForPath('/'), isTrue);
      expect(librarySearchHotkeyEnabledForPath('/discover'), isTrue);
      expect(librarySearchHotkeyEnabledForPath('/library'), isTrue);
      expect(librarySearchHotkeyEnabledForPath('/profile'), isTrue);
      expect(librarySearchHotkeyEnabledForPath('/craft'), isTrue);
    });
  });
}
