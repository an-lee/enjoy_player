import 'dart:io';

String? _libraryPathOverride;
String? _dataPathOverride;

/// Pin resolved native paths for a worker isolate (sendable strings).
void setEspeakNativePathOverrides({String? libraryPath, String? dataPath}) {
  _libraryPathOverride = libraryPath;
  _dataPathOverride = dataPath;
}

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

/// First existing library path, or null.
String? resolveEspeakLibraryPath() {
  if (_libraryPathOverride != null &&
      File(_libraryPathOverride!).existsSync()) {
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
  return null;
}

/// First existing `espeak-ng-data` directory, or null.
String? resolveEspeakDataPath() {
  if (_dataPathOverride != null && Directory(_dataPathOverride!).existsSync()) {
    return _dataPathOverride;
  }
  for (final root in espeakNativeSearchRoots()) {
    final candidate = '$root${Platform.pathSeparator}espeak-ng-data';
    final dir = Directory(candidate);
    if (dir.existsSync() &&
        dir.listSync().any(
          (e) => e.path.split(Platform.pathSeparator).last != '.gitkeep',
        )) {
      return candidate;
    }
  }
  return null;
}
