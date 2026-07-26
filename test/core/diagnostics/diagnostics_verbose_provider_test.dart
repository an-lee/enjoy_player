import 'package:drift/native.dart';
import 'package:enjoy_player/core/diagnostics/diagnostics_verbose_provider.dart';
import 'package:enjoy_player/core/logging/diagnostic_log_config.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('readDiagnosticsVerboseEnabledFromDb', () {
    test('returns false when key is missing', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      expect(await readDiagnosticsVerboseEnabledFromDb(db), isFalse);
    });

    test('returns true when stored value is "true"', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await db.settingsDao.setValue(
        SettingsKeys.diagnosticsVerboseEnabled,
        'true',
      );
      expect(await readDiagnosticsVerboseEnabledFromDb(db), isTrue);
    });

    test('returns false when stored value is "false"', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await db.settingsDao.setValue(
        SettingsKeys.diagnosticsVerboseEnabled,
        'false',
      );
      expect(await readDiagnosticsVerboseEnabledFromDb(db), isFalse);
    });

    test('returns false when stored value is any other string', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await db.settingsDao.setValue(
        SettingsKeys.diagnosticsVerboseEnabled,
        'yes-please',
      );
      expect(await readDiagnosticsVerboseEnabledFromDb(db), isFalse);
    });
  });

  group('writeDiagnosticsVerboseEnabledToDb', () {
    test('persists enabled=true as "true"', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await writeDiagnosticsVerboseEnabledToDb(db, enabled: true);
      expect(
        await db.settingsDao.getValue(SettingsKeys.diagnosticsVerboseEnabled),
        'true',
      );
    });

    test('persists enabled=false as "false"', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await writeDiagnosticsVerboseEnabledToDb(db, enabled: false);
      expect(
        await db.settingsDao.getValue(SettingsKeys.diagnosticsVerboseEnabled),
        'false',
      );
    });

    test('overwrites a prior value', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await writeDiagnosticsVerboseEnabledToDb(db, enabled: true);
      await writeDiagnosticsVerboseEnabledToDb(db, enabled: false);
      expect(await readDiagnosticsVerboseEnabledFromDb(db), isFalse);
      await writeDiagnosticsVerboseEnabledToDb(db, enabled: true);
      expect(await readDiagnosticsVerboseEnabledFromDb(db), isTrue);
    });
  });

  group('DiagnosticLogConfig integration', () {
    setUp(() {
      DiagnosticLogConfig.setVerboseEnabled(false);
    });

    test('setVerboseEnabled updates the global flag', () {
      DiagnosticLogConfig.setVerboseEnabled(true);
      expect(DiagnosticLogConfig.verboseEnabled, isTrue);
      DiagnosticLogConfig.setVerboseEnabled(false);
      expect(DiagnosticLogConfig.verboseEnabled, isFalse);
    });
  });
}
