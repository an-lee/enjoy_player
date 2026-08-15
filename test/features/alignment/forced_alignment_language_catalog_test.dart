import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

void main() {
  test('alignment languages match the focus catalog', () {
    expect(kSupportedAlignmentLanguageTags, kSupportedFocusLanguageTags);
  });
}
