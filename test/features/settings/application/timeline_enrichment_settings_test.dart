import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/settings/application/timeline_enrichment_settings.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('readTimelineEnrichmentEnabledFromDb', () {
    test('returns false when key is missing', () async {
      expect(await readTimelineEnrichmentEnabledFromDb(db), isFalse);
    });

    test('returns true when stored value is "true"', () async {
      await db.settingsDao.setValue(
        SettingsKeys.transcriptTimelineEnrichment,
        'true',
      );
      expect(await readTimelineEnrichmentEnabledFromDb(db), isTrue);
    });

    test('returns false when stored value is "false"', () async {
      await db.settingsDao.setValue(
        SettingsKeys.transcriptTimelineEnrichment,
        'false',
      );
      expect(await readTimelineEnrichmentEnabledFromDb(db), isFalse);
    });
  });

  test('setEnabled round-trips via SettingsDao', () async {
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(timelineEnrichmentSettingsProvider.future),
      isFalse,
    );
    await container
        .read(timelineEnrichmentSettingsProvider.notifier)
        .setEnabled(true);
    expect(
      await container.read(timelineEnrichmentSettingsProvider.future),
      isTrue,
    );
    expect(
      await db.settingsDao.getValue(SettingsKeys.transcriptTimelineEnrichment),
      'true',
    );

    await container
        .read(timelineEnrichmentSettingsProvider.notifier)
        .setEnabled(false);
    expect(await readTimelineEnrichmentEnabledFromDb(db), isFalse);
  });
}
