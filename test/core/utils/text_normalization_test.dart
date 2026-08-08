import 'package:enjoy_player/core/utils/text_normalization.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('collapseWhitespace', () {
    test('collapses spaces, tabs, and newlines', () {
      expect(
        collapseWhitespace('  hello\t  world\nagain  '),
        'hello world again',
      );
    });

    test('returns an empty string for whitespace-only input', () {
      expect(collapseWhitespace(' \t\n '), isEmpty);
    });

    test('preserves ordinary text', () {
      expect(collapseWhitespace('hello world'), 'hello world');
    });

    test('trims the collapsed result', () {
      expect(collapseWhitespace('\n  hello  world  \n'), 'hello world');
    });
  });
}
