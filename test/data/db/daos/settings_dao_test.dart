// Tests for `lib/data/db/daos/settings_dao.dart` (and the SettingsKv table
// generated accessors in `app_database.g.dart`).
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('SettingsDao', () {
    test('getValue returns null when no row exists', () async {
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), isNull);
    });

    test('setValue + getValue round-trip', () async {
      await db.settingsDao.setValue(
        SettingsKeys.apiBaseUrl,
        'https://example.test/v1',
      );
      expect(
        await db.settingsDao.getValue(SettingsKeys.apiBaseUrl),
        'https://example.test/v1',
      );
    });

    test('setValue with insertOrReplace overwrites existing', () async {
      await db.settingsDao.setValue(
        SettingsKeys.apiBaseUrl,
        'https://first.test',
      );
      await db.settingsDao.setValue(
        SettingsKeys.apiBaseUrl,
        'https://second.test',
      );
      expect(
        await db.settingsDao.getValue(SettingsKeys.apiBaseUrl),
        'https://second.test',
      );
    });

    test('setValue persists across distinct keys', () async {
      await db.settingsDao.setValue(SettingsKeys.apiBaseUrl, 'A');
      await db.settingsDao.setValue(SettingsKeys.apiAiBaseUrl, 'B');
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), 'A');
      expect(await db.settingsDao.getValue(SettingsKeys.apiAiBaseUrl), 'B');
    });

    test('deleteValue removes the row', () async {
      await db.settingsDao.setValue(
        SettingsKeys.apiBaseUrl,
        'https://example.test',
      );
      await db.settingsDao.deleteValue(SettingsKeys.apiBaseUrl);
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), isNull);
    });

    test('deleteValue on missing key is a no-op', () async {
      // Should not throw.
      await db.settingsDao.deleteValue(SettingsKeys.apiBaseUrl);
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), isNull);
    });

    test('dynamic keys (sync.cursor.recording.*) are accepted', () async {
      const k = 'sync.cursor.recording.Video.media-1';
      await db.settingsDao.setValue(k, '2026-01-01T00:00:00Z');
      expect(await db.settingsDao.getValue(k), '2026-01-01T00:00:00Z');
      await db.settingsDao.deleteValue(k);
      expect(await db.settingsDao.getValue(k), isNull);
    });

    test('dynamic keys (sync.last_pull_at.recording.*) are accepted', () async {
      const k = 'sync.last_pull_at.recording.Video.media-1';
      await db.settingsDao.setValue(k, '2026-01-01T00:00:00Z');
      expect(await db.settingsDao.getValue(k), '2026-01-01T00:00:00Z');
    });

    test('dynamic keys (asr.long_form.attempt.*) are accepted', () async {
      const k = 'asr.long_form.attempt.media-1';
      await db.settingsDao.setValue(k, '2026-01-01T00:00:00Z');
      expect(await db.settingsDao.getValue(k), '2026-01-01T00:00:00Z');
    });

    test('all four SettingsKeys constants are recognised as known', () {
      expect(SettingsKeys.isKnown(SettingsKeys.apiBaseUrl), isTrue);
      expect(SettingsKeys.isKnown(SettingsKeys.apiAiBaseUrl), isTrue);
      expect(SettingsKeys.isKnown(SettingsKeys.prefsLocale), isTrue);
      expect(
        SettingsKeys.isKnown(
          SettingsKeys.syncCursorRecordingTarget('Video', 'm1'),
        ),
        isTrue,
      );
    });

    test('unrecognised key returns false from isKnown', () {
      expect(SettingsKeys.isKnown('not.a.real.key'), isFalse);
    });

    test(
      'kDefaultApiBaseUrl and kDefaultAiApiBaseUrl are non-empty https URLs',
      () {
        expect(kDefaultApiBaseUrl, startsWith('https://'));
        expect(kDefaultAiApiBaseUrl, startsWith('https://'));
      },
    );
  });
}
