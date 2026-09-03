// Capture preference persistence (spec 046 US4): device-global Drift key,
// missing ≡ on, writes survive a fresh provider/container.
library;

import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/analytics/analytics_capture_pref.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  ProviderContainer container() => ProviderContainer(
    overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
  );

  test('missing key defaults to capture ON', () async {
    final c = container();
    addTearDown(c.dispose);
    expect(await c.read(analyticsCapturePrefProvider.future), isTrue);
  });

  test('setEnabled persists and updates state', () async {
    final c = container();
    addTearDown(c.dispose);

    final applied = await c
        .read(analyticsCapturePrefProvider.notifier)
        .setEnabled(false);
    expect(applied, isFalse);
    expect(await c.read(analyticsCapturePrefProvider.future), isFalse);

    final raw = await db.settingsDao.getValue(
      SettingsKeys.analyticsCaptureEnabled,
    );
    expect(raw, 'false');
  });

  test('a stored opt-out survives a fresh container (restart)', () async {
    final first = container();
    addTearDown(first.dispose);
    await first.read(analyticsCapturePrefProvider.notifier).setEnabled(false);

    final second = container();
    addTearDown(second.dispose);
    expect(await second.read(analyticsCapturePrefProvider.future), isFalse);
  });
}
