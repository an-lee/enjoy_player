import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/settings/application/word_practice_settings.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('readWordPracticeEnabledFromDb', () {
    test('returns false when key is missing', () async {
      expect(await readWordPracticeEnabledFromDb(db), isFalse);
    });

    test('returns true when stored value is "true"', () async {
      await db.settingsDao.setValue(
        SettingsKeys.transcriptWordPractice,
        'true',
      );
      expect(await readWordPracticeEnabledFromDb(db), isTrue);
    });

    test('returns false when stored value is "false"', () async {
      await db.settingsDao.setValue(
        SettingsKeys.transcriptWordPractice,
        'false',
      );
      expect(await readWordPracticeEnabledFromDb(db), isFalse);
    });
  });

  test('setEnabled round-trips via SettingsDao', () async {
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    expect(await container.read(wordPracticeSettingsProvider.future), isFalse);
    await container
        .read(wordPracticeSettingsProvider.notifier)
        .setEnabled(true);
    expect(await container.read(wordPracticeSettingsProvider.future), isTrue);
    expect(
      await db.settingsDao.getValue(SettingsKeys.transcriptWordPractice),
      'true',
    );

    await container
        .read(wordPracticeSettingsProvider.notifier)
        .setEnabled(false);
    expect(await readWordPracticeEnabledFromDb(db), isFalse);
  });

  test('delayed true is not treated as off after await', () async {
    await db.settingsDao.setValue(SettingsKeys.transcriptWordPractice, 'true');
    final container = ProviderContainer(
      overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
    );
    addTearDown(container.dispose);

    final loading = container.read(wordPracticeSettingsProvider);
    expect(loading.value == false, isFalse);
    expect(await container.read(wordPracticeSettingsProvider.future), isTrue);
    expect(container.read(wordPracticeSettingsProvider).value, isTrue);
  });
}
