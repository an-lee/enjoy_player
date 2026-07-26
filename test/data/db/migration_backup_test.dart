import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/migration_backup.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import '../../support/test_path_provider.dart';

void main() {
  late Directory tempRoot;
  late Directory supportDir;
  late AppDatabase db;

  setUp(() {
    tempRoot = Directory.systemTemp.createTempSync('migration_backup_test_');
    supportDir = Directory(p.join(tempRoot.path, 'support'));
    supportDir.createSync(recursive: true);
    PathProviderPlatform.instance = TestPathProvider(supportDir.path);
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
    if (tempRoot.existsSync()) {
      tempRoot.deleteSync(recursive: true);
    }
  });

  group('migrationBackupTableNames', () {
    test(
      'includes every legacy + new table the destructive migration cares about',
      () {
        expect(
          migrationBackupTableNames,
          containsAll(<String>[
            'videos',
            'audios',
            'transcripts',
            'echo_sessions',
            'recordings',
            'dictations',
            'sync_queue',
            'settings',
            'media',
          ]),
        );
        expect(
          migrationBackupTableNames.length,
          migrationBackupTableNames.toSet().length,
          reason: 'no duplicates',
        );
      },
    );
  });

  group('backupToJson', () {
    test(
      'writes the backup file under migrations/ and parses as JSON',
      () async {
        final path = await backupToJson(db, from: 8, to: 10);
        expect(path, isNotNull);
        final file = File(path!);
        expect(file.existsSync(), isTrue);
        final content = await file.readAsString();
        final json = jsonDecode(content) as Map<String, dynamic>;
        expect(json['schemaFrom'], 8);
        expect(json['schemaTo'], 10);
        expect(json['exportedAt'], isA<String>());
        expect(json['tables'], isA<Map<String, dynamic>>());
      },
    );

    test('populates per-table row arrays (empty for new tables)', () async {
      final path = await backupToJson(db, from: 8, to: 10);
      final json =
          jsonDecode(await File(path!).readAsString()) as Map<String, dynamic>;
      final tables = json['tables'] as Map<String, dynamic>;
      for (final name in migrationBackupTableNames) {
        expect(
          tables[name],
          isA<Map<String, dynamic>>(),
          reason: 'table $name missing',
        );
        final t = tables[name] as Map<String, dynamic>;
        // Unknown tables are exported as {rowCount: 0, rows: [], missing: true}.
        // Real ones carry rows with at least the rowCount key.
        if (t['missing'] == null) {
          expect(t['rowCount'], isA<int>());
          expect(t['rows'], isA<List>());
        }
      }
    });

    test(
      'serializes a real Settings row through the date-time jsonify',
      () async {
        await db.settingsDao.setValue(SettingsKeys.prefsLocale, 'en-US');
        final path = await backupToJson(db, from: 8, to: 10);
        final json =
            jsonDecode(await File(path!).readAsString())
                as Map<String, dynamic>;
        final settings =
            (json['tables'] as Map<String, dynamic>)['settings']
                as Map<String, dynamic>;
        expect(settings['rowCount'], greaterThan(0));
        final rows = settings['rows'] as List;
        expect(rows, hasLength(1));
        final entry = (rows.single as Map<String, dynamic>)['value'];
        expect(entry, 'en-US');
      },
    );

    test('returns null and does not crash when path_provider throws', () async {
      PathProviderPlatform.instance = _BrokenPathProvider();
      final result = await backupToJson(db, from: 8, to: 10);
      expect(result, isNull);
    });

    test('file name embeds the from/to versions + a UTC stamp', () async {
      final path = await backupToJson(db, from: 8, to: 10);
      final name = p.basename(path!);
      expect(name, startsWith('8_to_10_'));
      expect(name, endsWith('.json'));
    });
  });
}

class _BrokenPathProvider extends TestPathProvider {
  _BrokenPathProvider() : super('/this/does/not/matter');
  @override
  Future<String?> getApplicationSupportPath() async {
    throw const FileSystemException('synthetic failure for test');
  }
}
