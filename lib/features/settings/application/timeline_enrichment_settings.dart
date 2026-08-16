/// Persisted Craft timeline-enrichment preference (default off).
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';

part 'timeline_enrichment_settings.g.dart';

Future<bool> readTimelineEnrichmentEnabledFromDb(AppDatabase db) async {
  final raw = await db.settingsDao.getValue(
    SettingsKeys.transcriptTimelineEnrichment,
  );
  return raw == 'true';
}

Future<void> writeTimelineEnrichmentEnabledToDb(
  AppDatabase db, {
  required bool enabled,
}) async {
  await db.settingsDao.setValue(
    SettingsKeys.transcriptTimelineEnrichment,
    enabled ? 'true' : 'false',
  );
}

@Riverpod(keepAlive: true)
class TimelineEnrichmentSettings extends _$TimelineEnrichmentSettings {
  @override
  Future<bool> build() async {
    final db = ref.watch(deviceGlobalAppDatabaseProvider);
    return readTimelineEnrichmentEnabledFromDb(db);
  }

  Future<void> setEnabled(bool enabled) async {
    final db = ref.read(deviceGlobalAppDatabaseProvider);
    await writeTimelineEnrichmentEnabledToDb(db, enabled: enabled);
    state = AsyncData(enabled);
  }
}
