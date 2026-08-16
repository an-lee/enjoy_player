import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/settings/application/karaoke_highlight_settings.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('readKaraokeHighlightEnabledFromDb', () {
    test('returns false when key is missing', () async {
      expect(await readKaraokeHighlightEnabledFromDb(db), isFalse);
    });

    test('returns true when stored value is "true"', () async {
      await db.settingsDao.setValue(
        SettingsKeys.transcriptKaraokeHighlight,
        'true',
      );
      expect(await readKaraokeHighlightEnabledFromDb(db), isTrue);
    });

    test('returns false when stored value is "false"', () async {
      await db.settingsDao.setValue(
        SettingsKeys.transcriptKaraokeHighlight,
        'false',
      );
      expect(await readKaraokeHighlightEnabledFromDb(db), isFalse);
    });
  });

  test('setEnabled round-trips via SettingsDao', () async {
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(
      await container.read(karaokeHighlightSettingsProvider.future),
      isFalse,
    );
    await container
        .read(karaokeHighlightSettingsProvider.notifier)
        .setEnabled(true);
    expect(
      await container.read(karaokeHighlightSettingsProvider.future),
      isTrue,
    );
    expect(
      await db.settingsDao.getValue(SettingsKeys.transcriptKaraokeHighlight),
      'true',
    );

    await container
        .read(karaokeHighlightSettingsProvider.notifier)
        .setEnabled(false);
    expect(await readKaraokeHighlightEnabledFromDb(db), isFalse);
  });

  test('delayed true is not treated as off after await', () async {
    await db.settingsDao.setValue(
      SettingsKeys.transcriptKaraokeHighlight,
      'true',
    );
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final loading = container.read(karaokeHighlightSettingsProvider);
    expect(loading.value == false, isFalse);
    expect(
      await container.read(karaokeHighlightSettingsProvider.future),
      isTrue,
    );
    expect(container.read(karaokeHighlightSettingsProvider).value, isTrue);
  });
}
