import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/language_map.dart';
import 'package:forced_alignment/src/synth/espeak_synth_host.dart';
import 'package:forced_alignment/src/synth/native_paths.dart';

void main() {
  test('vendored data includes a lang file for every mapped voice', () {
    final data = resolveEspeakDataPath();
    if (data == null) {
      return;
    }
    final lang = Directory('$data${Platform.pathSeparator}lang');
    expect(lang.existsSync(), isTrue);
    for (final voice in kEspeakVoiceByLanguageTag.values) {
      final file = File('${lang.path}${Platform.pathSeparator}$voice');
      expect(file.existsSync(), isTrue, reason: 'missing lang/$voice');
    }
  });

  test(
    'fr-CA spoken reference can be built',
    () async {
      final ref = await EspeakSynthHost.synthesize(
        text: 'bonjour',
        language: 'fr-CA',
      );
      expect(ref.pcm, isNotEmpty);
      expect(ref.words, isNotEmpty);
    },
    skip: espeakFfiIsAvailable()
        ? false
        : 'eSpeak-NG FFI not loaded on this runner',
  );
}
