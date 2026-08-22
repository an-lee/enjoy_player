/// Copies a remote row into local Drift so it appears in the Library.
library;

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/cloud/domain/remote_library_item.dart';
import 'package:enjoy_player/features/sync/data/sync_serializers.dart';

class CloudAddToLibrary {
  CloudAddToLibrary(this._db);

  final AppDatabase _db;

  Future<bool> isInLibrary(RemoteLibraryItem item) async {
    if (item.isVideo) {
      return (await _db.videoDao.getById(item.id)) != null;
    }
    return (await _db.audioDao.getById(item.id)) != null;
  }

  /// Inserts metadata from the remote payload (`localUri` null; `mediaUrl` kept when set).
  Future<void> add(RemoteLibraryItem item) async {
    if (item.isVideo) {
      final row = videoRowFromServerJson(item.rawJson);
      await _db.videoDao.insertRow(row);
      return;
    }
    final row = audioRowFromServerJson(item.rawJson);
    await _db.audioDao.insertRow(row);
  }
}
