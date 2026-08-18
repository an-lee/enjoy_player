import 'dart:io';

import 'package:flutter/services.dart';
import 'package:forced_alignment/forced_alignment.dart'
    show setEspeakNativePathOverrides;
import 'package:path_provider/path_provider.dart';

import '../logging/log.dart';

final _log = logNamed('espeak.provision');

/// Bump when the vendored `espeak-ng-data` tree changes so installed apps
/// re-extract on next launch.
const kEspeakDataRevision = '1.52.0-1';

const _channelName = 'ai.enjoy.player/espeak';
const _assetPrefix = 'packages/forced_alignment/native/espeak-ng-data/';

/// Vendored data files keyed by path relative to `espeak-ng-data/`.
typedef EspeakDataLoader = Future<Map<String, Uint8List>> Function();

/// Loads every `espeak-ng-data` asset from [bundle].
Future<Map<String, Uint8List>> loadEspeakDataAssets([
  AssetBundle? bundle,
]) async {
  final source = bundle ?? rootBundle;
  final manifest = await AssetManifest.loadFromAssetBundle(source);
  final files = <String, Uint8List>{};
  for (final key in manifest.listAssets()) {
    if (!key.startsWith(_assetPrefix)) continue;
    final bytes = await source.load(key);
    files[key.substring(_assetPrefix.length)] = bytes.buffer.asUint8List(
      bytes.offsetInBytes,
      bytes.lengthInBytes,
    );
  }
  return files;
}

/// Provisions the eSpeak-NG runtime on Android.
///
/// Locates the vendored `libespeak-ng.so` shipped via jniLibs (through the
/// `ai.enjoy.player/espeak` channel) and extracts the `espeak-ng-data`
/// Flutter assets into app-support storage, then pins both paths into
/// `package:forced_alignment`. Returns `true` when alignment can now load
/// eSpeak; on any failure returns `false` and leaves the package fail-closed
/// (`spokenReferenceUnavailable`). Never throws.
Future<bool> ensureAndroidEspeakRuntime({
  MethodChannel? channel,
  EspeakDataLoader? loadData,
}) async {
  try {
    final messenger = channel ?? const MethodChannel(_channelName);
    final nativeLibDir = await messenger.invokeMethod<String>(
      'getNativeLibraryDir',
    );
    if (nativeLibDir == null || nativeLibDir.isEmpty) {
      _log.warning('native library dir unavailable; eSpeak stays disabled');
      return false;
    }
    final libPath = '$nativeLibDir${Platform.pathSeparator}libespeak-ng.so';
    if (!File(libPath).existsSync()) {
      _log.warning('vendored libespeak-ng.so missing at $libPath');
      return false;
    }

    final sep = Platform.pathSeparator;
    final support = await getApplicationSupportDirectory();
    final revisionsRoot = Directory('${support.path}${sep}espeak-ng');
    final revisionDir = Directory(
      '${revisionsRoot.path}$sep$kEspeakDataRevision',
    );
    final dataDir = Directory('${revisionDir.path}${sep}espeak-ng-data');

    if (!_isProvisioned(revisionDir)) {
      final files = await (loadData ?? loadEspeakDataAssets)();
      if (!files.containsKey('phontab')) {
        _log.warning('espeak-ng-data assets missing from the bundle');
        return false;
      }
      if (revisionsRoot.existsSync()) {
        for (final entry in revisionsRoot.listSync()) {
          if (entry is Directory) entry.deleteSync(recursive: true);
        }
      }
      for (final entry in files.entries) {
        final file = File('${dataDir.path}$sep${entry.key}');
        file.parent.createSync(recursive: true);
        file.writeAsBytesSync(entry.value);
      }
      File(
        '${revisionDir.path}$sep.provisioned',
      ).writeAsStringSync('${files.length}');
    }

    setEspeakNativePathOverrides(libraryPath: libPath, dataPath: dataDir.path);
    _log.info('eSpeak runtime provisioned (revision $kEspeakDataRevision)');
    return true;
  } on Object catch (e, st) {
    _log.warning(
      'eSpeak provisioning failed; alignment stays fail-closed',
      e,
      st,
    );
    return false;
  }
}

/// A complete revision carries `phontab` plus the `.provisioned` marker, so
/// warm launches skip asset enumeration entirely.
bool _isProvisioned(Directory revisionDir) {
  final sep = Platform.pathSeparator;
  return File('${revisionDir.path}$sep.provisioned').existsSync() &&
      File('${revisionDir.path}${sep}espeak-ng-data${sep}phontab').existsSync();
}
