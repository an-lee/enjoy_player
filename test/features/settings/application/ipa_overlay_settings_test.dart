import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/settings/application/ipa_overlay_settings.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('readIpaOverlayEnabledFromDb', () {
    test('returns false when key is missing', () async {
      expect(await readIpaOverlayEnabledFromDb(db), isFalse);
    });

    test('returns true when stored value is "true"', () async {
      await db.settingsDao.setValue(SettingsKeys.transcriptIpaOverlay, 'true');
      expect(await readIpaOverlayEnabledFromDb(db), isTrue);
    });

    test('returns false when stored value is "false"', () async {
      await db.settingsDao.setValue(SettingsKeys.transcriptIpaOverlay, 'false');
      expect(await readIpaOverlayEnabledFromDb(db), isFalse);
    });
  });

  test('setEnabled round-trips via SettingsDao', () async {
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(ipaOverlaySettingsProvider.future), isFalse);
    await container.read(ipaOverlaySettingsProvider.notifier).setEnabled(true);
    expect(await container.read(ipaOverlaySettingsProvider.future), isTrue);
    expect(
      await db.settingsDao.getValue(SettingsKeys.transcriptIpaOverlay),
      'true',
    );

    await container.read(ipaOverlaySettingsProvider.notifier).setEnabled(false);
    expect(await readIpaOverlayEnabledFromDb(db), isFalse);
  });

  test('delayed true is not treated as off after await', () async {
    await db.settingsDao.setValue(SettingsKeys.transcriptIpaOverlay, 'true');
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final loading = container.read(ipaOverlaySettingsProvider);
    expect(loading.value == false, isFalse);
    expect(await container.read(ipaOverlaySettingsProvider.future), isTrue);
    expect(container.read(ipaOverlaySettingsProvider).value, isTrue);
  });
}
