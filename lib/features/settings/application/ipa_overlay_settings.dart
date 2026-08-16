/// Persisted transcript IPA overlay preference (default off).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';

part 'ipa_overlay_settings.g.dart';

Future<bool> readIpaOverlayEnabledFromDb(AppDatabase db) async {
  final raw = await db.settingsDao.getValue(SettingsKeys.transcriptIpaOverlay);
  return raw == 'true';
}

Future<void> writeIpaOverlayEnabledToDb(
  AppDatabase db, {
  required bool enabled,
}) async {
  await db.settingsDao.setValue(
    SettingsKeys.transcriptIpaOverlay,
    enabled ? 'true' : 'false',
  );
}

@Riverpod(keepAlive: true)
class IpaOverlaySettings extends _$IpaOverlaySettings {
  @override
  Future<bool> build() async {
    final db = ref.watch(deviceGlobalAppDatabaseProvider);
    return readIpaOverlayEnabledFromDb(db);
  }

  Future<void> setEnabled(bool enabled) async {
    final db = ref.read(deviceGlobalAppDatabaseProvider);
    await writeIpaOverlayEnabledToDb(db, enabled: enabled);
    state = AsyncData(enabled);
  }
}
