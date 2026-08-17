import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

void main() {
  test('decodes multi-byte IPA UTF-8 from eSpeak id.string bytes', () {
    // ɡ æ ː (common IPA; UTF-8 C9 A1 / C3 A6 / CB 90)
    expect(decodeEspeakPhonemeIdBytes([0xC9, 0xA1]), 'ɡ');
    expect(decodeEspeakPhonemeIdBytes([0xC3, 0xA6]), 'æ');
    expect(decodeEspeakPhonemeIdBytes([0xCB, 0x90]), 'ː');
    expect(decodeEspeakPhonemeIdBytes(utf8.encode('hæv')), 'hæv');
  });

  test('does not Latin-1-mojibake UTF-8 phoneme bytes', () {
    final bytes = utf8.encode('ɡɹændmɑː');
    final decoded = decodeEspeakPhonemeIdBytes(bytes);
    expect(decoded, 'ɡɹændmɑː');
    expect(decoded, isNot(contains('É')));
    expect(decoded, isNot(contains('Ã')));
  });

  test('empty buffer yields empty string', () {
    expect(decodeEspeakPhonemeIdBytes(const []), '');
  });
}
