import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_synth_host.dart';

void main() {
  test('vendored data includes a lang file for every mapped voice', () {
    final data = resolveEspeakDataPath();
    expect(data, isNotNull);
    expect(missingEspeakRequiredDataFiles(data!), isEmpty);
  });

  test('fr-CA spoken reference can be built', () async {
    final ref = await EspeakSynthHost.synthesize(
      text: 'bonjour',
      language: 'fr-CA',
    );
    expect(ref.pcm, isNotEmpty);
    expect(ref.words, isNotEmpty);
  });
}
