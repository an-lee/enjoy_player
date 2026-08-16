/// Persisted transcript karaoke / current-word highlight preference (default off).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';

part 'karaoke_highlight_settings.g.dart';

Future<bool> readKaraokeHighlightEnabledFromDb(AppDatabase db) async {
  final raw = await db.settingsDao.getValue(
    SettingsKeys.transcriptKaraokeHighlight,
  );
  return raw == 'true';
}

Future<void> writeKaraokeHighlightEnabledToDb(
  AppDatabase db, {
  required bool enabled,
}) async {
  await db.settingsDao.setValue(
    SettingsKeys.transcriptKaraokeHighlight,
    enabled ? 'true' : 'false',
  );
}

@Riverpod(keepAlive: true)
class KaraokeHighlightSettings extends _$KaraokeHighlightSettings {
  @override
  Future<bool> build() async {
    final db = ref.watch(deviceGlobalAppDatabaseProvider);
    return readKaraokeHighlightEnabledFromDb(db);
  }

  Future<void> setEnabled(bool enabled) async {
    final db = ref.read(deviceGlobalAppDatabaseProvider);
    await writeKaraokeHighlightEnabledToDb(db, enabled: enabled);
    state = AsyncData(enabled);
  }
}
