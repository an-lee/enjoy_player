/// Safe cleanup for shared app-managed media files under `documents/media/`.
library;

import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqlite3/sqlite3.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/data/files/lasting_local_access.dart';

/// Whether [fileUri] is still referenced by any library row that should keep
/// the on-disk app-managed copy alive.
///
/// Checks the current [db] and other per-user SQLite files under the app
/// documents directory (`enjoy_player_<userId>.sqlite`), because copy-fallback
/// imports share `{documents}/media/{hash}{ext}` across accounts.
Future<bool> isAppManagedMediaStillReferenced({
  required AppDatabase db,
  required String fileUri,
}) async {
  if (fileUri.isEmpty) return false;
  if (!await isAppManagedMediaPath(fileUri)) return false;

  final inCurrent =
      await db.audioDao.existsByLocalUri(fileUri) ||
      await db.videoDao.existsByLocalUri(fileUri);
  if (inCurrent) return true;

  return _otherPerUserDbReferencesLocalUri(
    currentDbBaseName: db.databaseFileBaseName,
    fileUri: fileUri,
  );
}

/// Deletes [fileUri] only when it is app-managed and unreferenced.
Future<void> deleteAppManagedMediaIfUnreferenced({
  required AppDatabase db,
  required FileStorage storage,
  required String? fileUri,
}) async {
  if (fileUri == null || fileUri.isEmpty) return;
  if (!await isAppManagedMediaPath(fileUri)) return;
  if (await isAppManagedMediaStillReferenced(db: db, fileUri: fileUri)) {
    return;
  }
  await storage.deleteAppManagedMedia(fileUri);
}

Future<bool> _otherPerUserDbReferencesLocalUri({
  required String currentDbBaseName,
  required String fileUri,
}) async {
  try {
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(docs.path);
    if (!await dir.exists()) return false;

    final currentFileName = '$currentDbBaseName.sqlite';
    await for (final entity in dir.list(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path);
      if (!_isPerUserLibraryDbFileName(name)) continue;
      if (name == currentFileName) continue;
      if (_sqliteFileReferencesLocalUri(entity.path, fileUri)) {
        return true;
      }
    }
  } on Object {
    // Best-effort — if we cannot scan, keep the file (safer than deleting).
    return true;
  }
  return false;
}

bool _isPerUserLibraryDbFileName(String name) {
  // Per-user: enjoy_player_<sanitizedUserId>.sqlite
  // Skip device-global enjoy_player.sqlite and sidecar -wal/-shm files.
  if (!name.startsWith('${AppDatabase.deviceGlobalDatabaseName}_')) {
    return false;
  }
  return name.endsWith('.sqlite');
}

bool _sqliteFileReferencesLocalUri(String dbPath, String fileUri) {
  Database? raw;
  try {
    raw = sqlite3.open(dbPath, mode: OpenMode.readOnly);
    final audio = raw.select(
      'SELECT 1 FROM audios WHERE local_uri = ? LIMIT 1',
      [fileUri],
    );
    if (audio.isNotEmpty) return true;
    final video = raw.select(
      'SELECT 1 FROM videos WHERE local_uri = ? LIMIT 1',
      [fileUri],
    );
    return video.isNotEmpty;
  } on Object {
    // Missing tables / locked DB — treat as referenced to avoid data loss.
    return true;
  } finally {
    raw?.close();
  }
}
