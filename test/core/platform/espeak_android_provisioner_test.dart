import 'dart:io';

import 'package:enjoy_player/core/platform/espeak_android_provisioner.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/test_path_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('ai.enjoy.player/espeak');

  late Directory tempRoot;
  late Directory nativeLibDir;
  late String supportPath;
  late int loadCalls;

  Map<String, Uint8List> fakeData() => {
    'phontab': Uint8List.fromList([1, 2, 3]),
    'en_dict': Uint8List.fromList([4, 5]),
    'lang/en': Uint8List.fromList([6]),
  };

  Future<Map<String, Uint8List>> countingLoader() async {
    loadCalls += 1;
    return fakeData();
  }

  void mockNativeLibraryDir(String? dir) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, (call) async {
          if (call.method == 'getNativeLibraryDir') return dir;
          throw MissingPluginException();
        });
  }

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('espeak_provision_test.');
    nativeLibDir = Directory(p.join(tempRoot.path, 'native_lib'))
      ..createSync(recursive: true);
    File(p.join(nativeLibDir.path, 'libespeak-ng.so')).writeAsBytesSync([0]);
    supportPath = p.join(tempRoot.path, 'support');
    Directory(supportPath).createSync(recursive: true);
    PathProviderPlatform.instance = TestPathProvider(
      p.join(tempRoot.path, 'docs'),
      supportPath: supportPath,
    );
    loadCalls = 0;
  });

  tearDown(() {
    setEspeakNativePathOverrides();
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(channel, null);
    tempRoot.deleteSync(recursive: true);
  });

  String expectedDataPath() =>
      p.join(supportPath, 'espeak-ng', kEspeakDataRevision, 'espeak-ng-data');

  test('fresh run extracts data and pins resolved paths', () async {
    mockNativeLibraryDir(nativeLibDir.path);

    final ok = await ensureAndroidEspeakRuntime(loadData: countingLoader);

    expect(ok, isTrue);
    expect(loadCalls, 1);
    final libPath = p.join(nativeLibDir.path, 'libespeak-ng.so');
    expect(resolveEspeakLibraryPath(), libPath);
    expect(resolveEspeakDataPath(), expectedDataPath());
    expect(File(p.join(expectedDataPath(), 'phontab')).existsSync(), isTrue);
    expect(File(p.join(expectedDataPath(), 'lang', 'en')).existsSync(), isTrue);
    expect(
      File(
        p.join(supportPath, 'espeak-ng', kEspeakDataRevision, '.provisioned'),
      ).existsSync(),
      isTrue,
    );
  });

  test('warm launch skips asset loading', () async {
    mockNativeLibraryDir(nativeLibDir.path);

    await ensureAndroidEspeakRuntime(loadData: countingLoader);
    final ok = await ensureAndroidEspeakRuntime(loadData: countingLoader);

    expect(ok, isTrue);
    expect(loadCalls, 1);
    expect(resolveEspeakDataPath(), expectedDataPath());
  });

  test('stale revisions are pruned on re-extraction', () async {
    mockNativeLibraryDir(nativeLibDir.path);
    final stale = Directory(p.join(supportPath, 'espeak-ng', '0.0.0-stale'))
      ..createSync(recursive: true);
    File(p.join(stale.path, 'junk')).writeAsBytesSync([9]);

    final ok = await ensureAndroidEspeakRuntime(loadData: countingLoader);

    expect(ok, isTrue);
    expect(stale.existsSync(), isFalse);
    expect(resolveEspeakDataPath(), expectedDataPath());
  });

  test('missing vendored library fails closed without pinning', () async {
    mockNativeLibraryDir(p.join(tempRoot.path, 'no_such_dir'));

    final ok = await ensureAndroidEspeakRuntime(loadData: countingLoader);

    expect(ok, isFalse);
    expect(loadCalls, 0);
    expect(
      resolveEspeakLibraryPath(),
      isNot(p.join(tempRoot.path, 'no_such_dir', 'libespeak-ng.so')),
    );
  });

  test('channel failure fails closed', () async {
    mockNativeLibraryDir(null);

    final ok = await ensureAndroidEspeakRuntime(loadData: countingLoader);

    expect(ok, isFalse);
    expect(loadCalls, 0);
  });

  test('asset bundle without phontab fails closed', () async {
    mockNativeLibraryDir(nativeLibDir.path);

    final ok = await ensureAndroidEspeakRuntime(
      loadData: () async => {
        'lang/en': Uint8List.fromList([6]),
      },
    );

    expect(ok, isFalse);
    expect(Directory(expectedDataPath()).existsSync(), isFalse);
  });
}
