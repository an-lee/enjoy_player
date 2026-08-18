import 'dart:io';

import 'package:meta/meta.dart';

import '../language_map.dart';

String? _libraryPathOverride;
String? _dataPathOverride;
String? _resolvedExecutableOverride;

/// Android linker soname. `dlopen` can resolve this even when the `.so` is
/// not a regular file under `nativeLibraryDir` (uncompressed in the APK).
const kEspeakAndroidSoname = 'libespeak-ng.so';

/// Pin resolved native paths for a worker isolate (sendable strings).
void setEspeakNativePathOverrides({String? libraryPath, String? dataPath}) {
  _libraryPathOverride = libraryPath;
  _dataPathOverride = dataPath;
}

/// Test harness: pretend [Platform.resolvedExecutable] is an app binary.
@visibleForTesting
void debugSetEspeakResolvedExecutable(String? path) {
  _resolvedExecutableOverride = path;
}

String _resolvedExecutable() =>
    _resolvedExecutableOverride ?? Platform.resolvedExecutable;

/// Candidate directories that may contain vendored `libespeak-ng` + data.
List<String> espeakNativeSearchRoots() {
  final cwd = Directory.current.path;
  final sep = Platform.pathSeparator;
  return [
    '$cwd${sep}packages${sep}forced_alignment${sep}native',
    '$cwd${sep}native',
  ];
}

List<String> espeakLibraryFileNames() {
  if (Platform.isWindows) {
    return const ['libespeak-ng.dll', 'libespeak_ng.dll'];
  }
  if (Platform.isMacOS || Platform.isIOS) {
    return const ['libespeak-ng.dylib', 'libespeak_ng.dylib'];
  }
  return const ['libespeak-ng.so', 'libespeak_ng.so'];
}

String espeakOsFolderName() {
  if (Platform.isWindows) return 'windows';
  if (Platform.isMacOS) return 'macos';
  if (Platform.isIOS) return 'ios';
  if (Platform.isAndroid) return 'android';
  return 'linux';
}

/// App-bundle library paths derived from the running executable.
///
/// macOS: `App.app/Contents/MacOS/<exe>` → `Contents/Frameworks/libespeak-ng.dylib`
/// iOS: `Runner.app/<exe>` → `Frameworks/libespeak-ng.dylib`
@visibleForTesting
List<String> espeakBundleLibraryCandidates({
  String? resolvedExecutable,
  String? osFolder,
}) {
  final exe = resolvedExecutable ?? _resolvedExecutable();
  final exeDir = File(exe).parent.path;
  final sep = Platform.pathSeparator;
  switch (osFolder ?? espeakOsFolderName()) {
    case 'macos':
      final contents = Directory(exeDir).parent.path;
      return [
        '$contents${sep}Frameworks${sep}libespeak-ng.dylib',
        '$contents${sep}Frameworks${sep}libespeak_ng.dylib',
      ];
    case 'ios':
      return [
        '$exeDir${sep}Frameworks${sep}libespeak-ng.dylib',
        '$exeDir${sep}Frameworks${sep}libespeak_ng.dylib',
        '$exeDir${sep}Frameworks${sep}eSpeakNG.framework${sep}eSpeakNG',
      ];
    default:
      return const [];
  }
}

/// App-bundle `espeak-ng-data` directories derived from the running executable.
@visibleForTesting
List<String> espeakBundleDataCandidates({
  String? resolvedExecutable,
  String? osFolder,
}) {
  final exe = resolvedExecutable ?? _resolvedExecutable();
  final exeDir = File(exe).parent.path;
  final sep = Platform.pathSeparator;
  switch (osFolder ?? espeakOsFolderName()) {
    case 'macos':
      final contents = Directory(exeDir).parent.path;
      return ['$contents${sep}Resources${sep}espeak-ng-data'];
    case 'ios':
      return [
        '$exeDir${sep}espeak-ng-data',
        '$exeDir${sep}Frameworks${sep}espeak-ng-data',
      ];
    default:
      return const [];
  }
}

bool _isUsableDataDir(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) return false;
  return dir.listSync().any(
    (e) => e.path.split(Platform.pathSeparator).last != '.gitkeep',
  );
}

bool _libraryPathIsUsable(String path) {
  if (File(path).existsSync()) return true;
  // Bare soname: Android's linker namespace finds the packaged JNI lib.
  return path == kEspeakAndroidSoname;
}

/// First existing library path, or null.
String? resolveEspeakLibraryPath() {
  if (_libraryPathOverride != null &&
      _libraryPathIsUsable(_libraryPathOverride!)) {
    return _libraryPathOverride;
  }
  final os = espeakOsFolderName();
  for (final root in espeakNativeSearchRoots()) {
    for (final name in espeakLibraryFileNames()) {
      final candidate =
          '$root${Platform.pathSeparator}$os${Platform.pathSeparator}$name';
      if (File(candidate).existsSync()) return candidate;
      final flat = '$root${Platform.pathSeparator}$name';
      if (File(flat).existsSync()) return flat;
    }
  }
  for (final candidate in espeakBundleLibraryCandidates()) {
    if (File(candidate).existsSync()) return candidate;
  }
  return null;
}

/// First existing `espeak-ng-data` directory, or null.
String? resolveEspeakDataPath() {
  if (_dataPathOverride != null && Directory(_dataPathOverride!).existsSync()) {
    return _dataPathOverride;
  }
  for (final root in espeakNativeSearchRoots()) {
    final candidate = '$root${Platform.pathSeparator}espeak-ng-data';
    if (_isUsableDataDir(candidate)) return candidate;
  }
  for (final candidate in espeakBundleDataCandidates()) {
    if (_isUsableDataDir(candidate)) return candidate;
  }
  return null;
}

/// Relative paths from [kEspeakRequiredDataRelativePaths] that are missing
/// under [dataDir]. Empty means focus voices can resolve via SetVoiceByName.
List<String> missingEspeakRequiredDataFiles(String dataDir) {
  final sep = Platform.pathSeparator;
  return [
    for (final rel in kEspeakRequiredDataRelativePaths)
      if (!File('$dataDir$sep${rel.replaceAll('/', sep)}').existsSync()) rel,
  ];
}
