import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/synth/espeak_synth_host.dart';

void main() {
  test('source tree has every mapped voice for SetVoiceByName', () {
    final data = resolveEspeakDataPath();
    expect(data, isNotNull, reason: 'vendored espeak-ng-data must resolve');
    expect(
      missingEspeakRequiredDataFiles(data!),
      isEmpty,
      reason: 'source espeak-ng-data incomplete',
    );
  });

  test(
    'iOS and macOS bundle layouts keep lang voices for SetVoiceByName',
    () async {
      final src = resolveEspeakDataPath();
      final lib = resolveEspeakLibraryPath();
      expect(src, isNotNull);
      expect(lib, isNotNull);

      final tmp = Directory.systemTemp.createTempSync('espeak-apple-layout-');
      addTearDown(() => tmp.deleteSync(recursive: true));
      final iosData =
          '${tmp.path}${Platform.pathSeparator}Runner.app'
          '${Platform.pathSeparator}espeak-ng-data';
      final macData =
          '${tmp.path}${Platform.pathSeparator}Enjoy Player.app'
          '${Platform.pathSeparator}Contents'
          '${Platform.pathSeparator}Resources'
          '${Platform.pathSeparator}espeak-ng-data';
      _copyDataTree(src!, iosData);
      _copyDataTree(src, macData);

      expect(
        missingEspeakRequiredDataFiles(iosData),
        isEmpty,
        reason: 'iOS Runner.app/espeak-ng-data',
      );
      expect(
        missingEspeakRequiredDataFiles(macData),
        isEmpty,
        reason: 'macOS Contents/Resources/espeak-ng-data',
      );

      setEspeakNativePathOverrides(libraryPath: lib, dataPath: iosData);
      addTearDown(setEspeakNativePathOverrides);

      final ref = await EspeakSynthHost.synthesize(
        text: 'hello',
        language: 'en-US',
        phonemesOnly: true,
      );
      expect(ref.words, isNotEmpty);
      expect(ref.words.first.phones, isNotEmpty);
    },
  );

  test('bundle_into_app.sh copies iOS and macOS voice files', () {
    if (Platform.isWindows) {
      return;
    }
    final src = resolveEspeakDataPath();
    expect(src, isNotNull);
    final script = File('${Directory(src!).parent.path}/bundle_into_app.sh');
    expect(script.existsSync(), isTrue, reason: script.path);

    final tmp = Directory.systemTemp.createTempSync('espeak-bundle-script-');
    addTearDown(() => tmp.deleteSync(recursive: true));

    final macApp = Directory('${tmp.path}/Enjoy Player.app')
      ..createSync(recursive: true);
    Directory('${macApp.path}/Contents/MacOS').createSync(recursive: true);
    _runBundleScript(script.path, macApp.path, platformName: 'macosx');
    expect(
      missingEspeakRequiredDataFiles(
        '${macApp.path}/Contents/Resources/espeak-ng-data',
      ),
      isEmpty,
    );

    final iosApp = Directory('${tmp.path}/Runner.app')..createSync();
    _runBundleScript(script.path, iosApp.path, platformName: 'iphoneos');
    expect(
      missingEspeakRequiredDataFiles('${iosApp.path}/espeak-ng-data'),
      isEmpty,
    );
  });

  test('macOS app-bundle dylib still synthesizes a spoken reference', () async {
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
    _runBundleScript(script.path, app.path, platformName: 'macosx');

    final bundledLib = File(
      '${app.path}/Contents/Frameworks/libespeak-ng.dylib',
    );
    final bundledData = Directory(
      '${app.path}/Contents/Resources/espeak-ng-data',
    );
    expect(bundledLib.existsSync(), isTrue);
    expect(bundledData.existsSync(), isTrue);
    expect(missingEspeakRequiredDataFiles(bundledData.path), isEmpty);

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

void _runBundleScript(
  String script,
  String appPath, {
  required String platformName,
}) {
  final result = Process.runSync(
    script,
    [appPath],
    environment: {'PLATFORM_NAME': platformName, 'CODE_SIGNING_ALLOWED': 'NO'},
  );
  expect(result.exitCode, 0, reason: '${result.stdout}\n${result.stderr}');
}

void _copyDataTree(String src, String dest) {
  final srcDir = Directory(src);
  for (final entity in srcDir.listSync(recursive: true, followLinks: false)) {
    if (entity is! File) continue;
    final name = entity.uri.pathSegments.last;
    if (name == '.gitkeep') continue;
    final destPath = dest + entity.path.substring(src.length);
    File(destPath).parent.createSync(recursive: true);
    entity.copySync(destPath);
  }
}
