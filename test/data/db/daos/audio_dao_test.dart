import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:flutter_test/flutter_test.dart';

AudioRow _audioRow({
  String id = 'a-1',
  String aid = 'aid-1',
  String provider = 'user',
  String title = 'Hello',
  int durationSeconds = 0,
  String language = 'und',
  String? md5,
  String? localUri,
}) {
  final now = DateTime.fromMillisecondsSinceEpoch(1700000000000);
  return AudioRow(
    id: id,
    aid: aid,
    provider: provider,
    title: title,
    durationSeconds: durationSeconds,
    language: language,
    md5: md5,
    localUri: localUri,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('AudioDao', () {
    test('insertRow persists and getById reads it back', () async {
      await db.audioDao.insertRow(_audioRow(id: 'a'));
      final found = await db.audioDao.getById('a');
      expect(found, isNotNull);
      expect(found!.id, 'a');
      expect(found.title, 'Hello');
    });

    test('insertRow with same primary key replaces existing row', () async {
      await db.audioDao.insertRow(_audioRow(id: 'a', title: 'first'));
      await db.audioDao.insertRow(_audioRow(id: 'a', title: 'second'));
      final found = await db.audioDao.getById('a');
      expect(found!.title, 'second');
    });

    test('getById returns null for missing id', () async {
      expect(await db.audioDao.getById('missing'), isNull);
    });

    test('getByMd5 returns row with matching md5', () async {
      await db.audioDao.insertRow(_audioRow(id: 'a', md5: 'abc'));
      await db.audioDao.insertRow(_audioRow(id: 'b', md5: 'xyz'));
      final found = await db.audioDao.getByMd5('xyz');
      expect(found, isNotNull);
      expect(found!.id, 'b');
    });

    test('getByMd5 returns null when no match', () async {
      await db.audioDao.insertRow(_audioRow(id: 'a', md5: 'abc'));
      expect(await db.audioDao.getByMd5('zzz'), isNull);
    });

    test('updateLanguage changes language and bumps updatedAt', () async {
      await db.audioDao.insertRow(_audioRow(id: 'a'));
      final before = await db.audioDao.getById('a');
      final beforeTs = before!.updatedAt;
      await Future<void>.delayed(const Duration(milliseconds: 5));
      await db.audioDao.updateLanguage(id: 'a', language: 'en');
      final after = await db.audioDao.getById('a');
      expect(after!.language, 'en');
      expect(after.updatedAt.isAfter(beforeTs), isTrue);
    });

    test('updateLanguage is a no-op for missing id (still executes)', () async {
      await db.audioDao.updateLanguage(id: 'missing', language: 'en');
      // No assertion needed — Drift `update().write()` does not throw on
      // missing rows; this test just covers the execution path.
      expect(await db.audioDao.getById('missing'), isNull);
    });

    test(
      'touchUpdatedAt bumps updatedAt without changing other fields',
      () async {
        await db.audioDao.insertRow(_audioRow(id: 'a', title: 'Hi'));
        final before = await db.audioDao.getById('a');
        final beforeTs = before!.updatedAt;
        await Future<void>.delayed(const Duration(milliseconds: 5));
        await db.audioDao.touchUpdatedAt('a');
        final after = await db.audioDao.getById('a');
        expect(after!.title, 'Hi');
        expect(after.updatedAt.isAfter(beforeTs), isTrue);
      },
    );

    test('deleteId removes the row', () async {
      await db.audioDao.insertRow(_audioRow(id: 'kill'));
      await db.audioDao.insertRow(_audioRow(id: 'keep'));
      await db.audioDao.deleteId('kill');
      expect(await db.audioDao.getById('kill'), isNull);
      expect(await db.audioDao.getById('keep'), isNotNull);
    });

    test('existsByLocalUri returns true for matching rows', () async {
      await db.audioDao.insertRow(_audioRow(id: '1', localUri: 'file://1'));
      await db.audioDao.insertRow(_audioRow(id: '2', localUri: 'file://1'));
      await db.audioDao.insertRow(_audioRow(id: '3', localUri: 'file://2'));
      expect(await db.audioDao.existsByLocalUri('file://1'), isTrue);
      expect(await db.audioDao.existsByLocalUri('file://2'), isTrue);
      expect(await db.audioDao.existsByLocalUri('file://3'), isFalse);
    });

    test('watchAll emits rows ordered by createdAt descending', () async {
      final older = DateTime.utc(2026, 1, 1);
      final newer = DateTime.utc(2026, 6, 1);
      await db.audioDao.insertRow(
        _audioRow(id: 'old').copyWith(createdAt: older, updatedAt: older),
      );
      await db.audioDao.insertRow(
        _audioRow(id: 'new').copyWith(createdAt: newer, updatedAt: newer),
      );
      final list = await db.audioDao.watchAll().first;
      expect(list.map((r) => r.id), ['new', 'old']);
    });
  });

  group('SettingsDao', () {
    test('getValue returns null for unset key', () async {
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), isNull);
    });

    test('setValue then getValue round-trips a string', () async {
      await db.settingsDao.setValue(SettingsKeys.apiBaseUrl, 'https://x');
      expect(
        await db.settingsDao.getValue(SettingsKeys.apiBaseUrl),
        'https://x',
      );
    });

    test('setValue with same key overwrites prior value', () async {
      await db.settingsDao.setValue(SettingsKeys.apiBaseUrl, 'https://a');
      await db.settingsDao.setValue(SettingsKeys.apiBaseUrl, 'https://b');
      expect(
        await db.settingsDao.getValue(SettingsKeys.apiBaseUrl),
        'https://b',
      );
    });

    test('setValue allows several distinct keys', () async {
      await db.settingsDao.setValue(SettingsKeys.apiBaseUrl, 'a');
      await db.settingsDao.setValue(SettingsKeys.prefsLocale, 'zh-CN');
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), 'a');
      expect(await db.settingsDao.getValue(SettingsKeys.prefsLocale), 'zh-CN');
    });

    test('deleteValue removes a previously stored key', () async {
      await db.settingsDao.setValue(SettingsKeys.apiBaseUrl, 'x');
      await db.settingsDao.deleteValue(SettingsKeys.apiBaseUrl);
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), isNull);
    });

    test('deleteValue is a no-op for unknown keys', () async {
      await db.settingsDao.deleteValue(SettingsKeys.apiBaseUrl);
      expect(await db.settingsDao.getValue(SettingsKeys.apiBaseUrl), isNull);
    });

    test('dynamic sync cursor keys are accepted', () async {
      final key = SettingsKeys.syncCursorRecordingTarget('video', 'v-1');
      await db.settingsDao.setValue(key, 'cursor-1');
      expect(await db.settingsDao.getValue(key), 'cursor-1');
      await db.settingsDao.deleteValue(key);
      expect(await db.settingsDao.getValue(key), isNull);
    });

    test('SettingsKeys.isKnown covers static and dynamic families', () {
      // Static keys.
      expect(SettingsKeys.isKnown(SettingsKeys.apiBaseUrl), isTrue);
      expect(SettingsKeys.isKnown(SettingsKeys.prefsLocale), isTrue);
      expect(SettingsKeys.isKnown(SettingsKeys.updateLastCheckAt), isTrue);
      // Dynamic families.
      expect(
        SettingsKeys.isKnown(
          SettingsKeys.syncCursorRecordingTarget('video', 'v-1'),
        ),
        isTrue,
      );
      expect(
        SettingsKeys.isKnown(
          SettingsKeys.syncLastPullAtRecordingTarget('audio', 'a-1'),
        ),
        isTrue,
      );
      expect(
        SettingsKeys.isKnown(SettingsKeys.asrLongFormAttempt('m-1')),
        isTrue,
      );
      // Unknown keys.
      expect(SettingsKeys.isKnown('definitely.not.known'), isFalse);
      expect(SettingsKeys.isKnown(''), isFalse);
      expect(
        SettingsKeys.isKnown('sync.cursor.unknown'), // different family
        isFalse,
      );
    });
  });
}
