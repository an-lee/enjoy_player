import 'dart:io';

import 'package:flutter/services.dart';
import 'package:forced_alignment/forced_alignment.dart'
    show
        kEspeakAndroidSoname,
        kEspeakRequiredDataRelativePaths,
        missingEspeakRequiredDataFiles,
        setEspeakNativePathOverrides;
import 'package:path_provider/path_provider.dart';

import '../logging/log.dart';

final _log = logNamed('espeak.provision');

/// Bump when the vendored `espeak-ng-data` tree changes so installed apps
/// re-extract on next launch.
const kEspeakDataRevision = '1.52.0-2';

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
    var libPath = '$nativeLibDir${Platform.pathSeparator}libespeak-ng.so';
    if (!File(libPath).existsSync()) {
      // MIUI / uncompressed-in-APK installs often have no regular file
      // under nativeLibraryDir even though dlopen(soname) works.
      var listing = 'unreadable';
      try {
        listing = Directory(nativeLibDir).existsSync()
            ? Directory(nativeLibDir).listSync().map((e) => e.path).join(', ')
            : 'dir missing';
      } on Object catch (_) {}
      _log.warning(
        'libespeak-ng.so not a regular file at $libPath '
        '(listing: $listing); pinning Android soname for dlopen',
      );
      libPath = kEspeakAndroidSoname;
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
      if (!_hasRequiredRelativeFiles(files.keys)) {
        _log.warning(
          'espeak-ng-data assets missing phontab or lang voices; '
          'keys=${files.keys.toList()..sort()}',
        );
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

/// A complete revision carries `phontab`, mapped `lang/` voices, and the
/// `.provisioned` marker, so warm launches skip asset enumeration.
bool _isProvisioned(Directory revisionDir) {
  final sep = Platform.pathSeparator;
  final dataDir = Directory('${revisionDir.path}${sep}espeak-ng-data');
  if (!File('${revisionDir.path}$sep.provisioned').existsSync()) return false;
  return missingEspeakRequiredDataFiles(dataDir.path).isEmpty;
}

bool _hasRequiredRelativeFiles(Iterable<String> relativePaths) {
  final keys = relativePaths.toSet();
  return kEspeakRequiredDataRelativePaths.every(keys.contains);
}
