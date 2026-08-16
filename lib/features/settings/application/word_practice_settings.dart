/// Persisted transcript word-level practice preference (default off).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';

part 'word_practice_settings.g.dart';

Future<bool> readWordPracticeEnabledFromDb(AppDatabase db) async {
  final raw = await db.settingsDao.getValue(
    SettingsKeys.transcriptWordPractice,
  );
  return raw == 'true';
}

Future<void> writeWordPracticeEnabledToDb(
  AppDatabase db, {
  required bool enabled,
}) async {
  await db.settingsDao.setValue(
    SettingsKeys.transcriptWordPractice,
    enabled ? 'true' : 'false',
  );
}

@Riverpod(keepAlive: true)
class WordPracticeSettings extends _$WordPracticeSettings {
  @override
  Future<bool> build() async {
    final db = ref.watch(deviceGlobalAppDatabaseProvider);
    return readWordPracticeEnabledFromDb(db);
  }

  Future<void> setEnabled(bool enabled) async {
    final db = ref.read(deviceGlobalAppDatabaseProvider);
    await writeWordPracticeEnabledToDb(db, enabled: enabled);
    state = AsyncData(enabled);
  }
}
