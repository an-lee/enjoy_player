import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/src/synth/espeak_synth_host.dart';
import 'package:forced_alignment/src/synth/native_paths.dart';

void main() {
  test('macOS app-bundle copy still synthesizes a spoken reference', () async {
    if (!Platform.isMacOS) return;
    final repoNative = resolveEspeakLibraryPath();
    final repoData = resolveEspeakDataPath();
    expect(repoNative, isNotNull);
    expect(repoData, isNotNull);

    final tmp = Directory.systemTemp.createTempSync('espeak-bundle-synth-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final app = Directory('${tmp.path}/Enjoy Player.app');
    Directory('${app.path}/Contents/MacOS').createSync(recursive: true);
    final script = File(
      '${Directory(repoData!).parent.path}/bundle_into_app.sh',
    );
    expect(script.existsSync(), isTrue, reason: script.path);
    final result = Process.runSync(
      script.path,
      [app.path],
      environment: {'PLATFORM_NAME': 'macosx', 'CODE_SIGNING_ALLOWED': 'NO'},
    );
    expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');

    final bundledLib = File(
      '${app.path}/Contents/Frameworks/libespeak-ng.dylib',
    );
    final bundledData = Directory(
      '${app.path}/Contents/Resources/espeak-ng-data',
    );
    expect(bundledLib.existsSync(), isTrue);
    expect(bundledData.existsSync(), isTrue);

    setEspeakNativePathOverrides(
      libraryPath: bundledLib.path,
      dataPath: bundledData.path,
    );
    addTearDown(setEspeakNativePathOverrides);

    final ref = await EspeakSynthHost.synthesize(
      text: 'hello',
      language: 'en-US',
    );
    expect(ref.pcm, isNotEmpty);
    expect(ref.words, isNotEmpty);
  });
}
