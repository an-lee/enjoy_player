import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/src/synth/native_paths.dart';

void main() {
  tearDown(() {
    debugSetEspeakResolvedExecutable(null);
    setEspeakNativePathOverrides();
  });

  test('iOS ships eSpeakNG.xcframework for App Store embedding', () {
    final src = resolveEspeakDataPath();
    expect(src, isNotNull);
    final native = Directory(src!).parent.path;
    final plist = File('$native/ios/eSpeakNG.xcframework/Info.plist');
    final device = File(
      '$native/ios/eSpeakNG.xcframework/ios-arm64/eSpeakNG.framework/eSpeakNG',
    );
    expect(plist.existsSync(), isTrue, reason: plist.path);
    expect(device.existsSync(), isTrue, reason: device.path);
  });

  test('cwd search finds the vendored host library and data', () {
    expect(resolveEspeakLibraryPath(), isNotNull);
    expect(resolveEspeakDataPath(), isNotNull);
    expect(File(resolveEspeakLibraryPath()!).existsSync(), isTrue);
    expect(Directory(resolveEspeakDataPath()!).existsSync(), isTrue);
  });

  test('macOS bundle candidates sit in Contents/Frameworks and Resources', () {
    const exe = '/tmp/Enjoy Player.app/Contents/MacOS/Enjoy Player';
    expect(
      espeakBundleLibraryCandidates(resolvedExecutable: exe, osFolder: 'macos'),
      contains('/tmp/Enjoy Player.app/Contents/Frameworks/libespeak-ng.dylib'),
    );
    expect(
      espeakBundleDataCandidates(resolvedExecutable: exe, osFolder: 'macos'),
      contains('/tmp/Enjoy Player.app/Contents/Resources/espeak-ng-data'),
    );
  });

  test('iOS bundle candidates prefer eSpeakNG.framework', () {
    const exe = '/tmp/Runner.app/Runner';
    expect(
      espeakBundleLibraryCandidates(resolvedExecutable: exe, osFolder: 'ios'),
      contains('/tmp/Runner.app/Frameworks/eSpeakNG.framework/eSpeakNG'),
    );
    expect(
      espeakBundleDataCandidates(resolvedExecutable: exe, osFolder: 'ios'),
      contains('/tmp/Runner.app/espeak-ng-data'),
    );
  });

  test('non-Apple hosts have no executable-derived bundle candidates', () {
    for (final os in const ['android', 'windows', 'linux']) {
      expect(
        espeakBundleLibraryCandidates(
          resolvedExecutable: '/tmp/fake/app',
          osFolder: os,
        ),
        isEmpty,
        reason: '$os path delivery is override-driven, not bundle-derived',
      );
      expect(
        espeakBundleDataCandidates(
          resolvedExecutable: '/tmp/fake/app',
          osFolder: os,
        ),
        isEmpty,
      );
    }
  });

  test('bare Android soname override resolves without a file on disk', () {
    setEspeakNativePathOverrides(libraryPath: kEspeakAndroidSoname);
    expect(resolveEspeakLibraryPath(), kEspeakAndroidSoname);
  });

  test('debug executable override finds a fake macOS app bundle', () {
    if (!Platform.isMacOS) return;
    final tmp = Directory.systemTemp.createTempSync('espeak-app-');
    addTearDown(() => tmp.deleteSync(recursive: true));
    final contents = Directory('${tmp.path}/App.app/Contents')
      ..createSync(recursive: true);
    Directory('${contents.path}/MacOS').createSync();
    Directory('${contents.path}/Frameworks').createSync();
    Directory(
      '${contents.path}/Resources/espeak-ng-data',
    ).createSync(recursive: true);
    File('${contents.path}/MacOS/App').writeAsBytesSync([]);
    File('${contents.path}/Frameworks/libespeak-ng.dylib').writeAsBytesSync([]);
    File(
      '${contents.path}/Resources/espeak-ng-data/phontab',
    ).writeAsBytesSync([]);

    debugSetEspeakResolvedExecutable('${contents.path}/MacOS/App');
    final libs = espeakBundleLibraryCandidates();
    final data = espeakBundleDataCandidates();
    expect(File(libs.first).existsSync(), isTrue);
    expect(Directory(data.first).existsSync(), isTrue);
    expect(
      Directory(data.first).listSync().any((e) => e.path.endsWith('phontab')),
      isTrue,
    );
  });
}
