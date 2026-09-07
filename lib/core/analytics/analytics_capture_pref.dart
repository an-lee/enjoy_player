/// Persisted product analytics capture preference (specs/046, research D4).
///
/// Device-global on purpose: it must cover anonymous pre-sign-in events and
/// survive sign-out so a shared device's next user neither inherits nor
/// silently loses the previous user's choice (spec FR-007). Mirrors the
/// `DiagnosticsVerbose` recipe.
library;

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';

part 'analytics_capture_pref.g.dart';

/// Reads the capture preference. Missing value ≡ `true` (capture on — the
/// documented default; the Settings toggle is the opt-out).
Future<bool> readAnalyticsCaptureEnabledFromDb(AppDatabase db) async {
  final raw = await db.settingsDao.getValue(
    SettingsKeys.analyticsCaptureEnabled,
  );
  return raw != 'false';
}

Future<void> writeAnalyticsCaptureEnabledToDb(
  AppDatabase db, {
  required bool enabled,
}) async {
  await db.settingsDao.setValue(
    SettingsKeys.analyticsCaptureEnabled,
    enabled ? 'true' : 'false',
  );
}

@Riverpod(keepAlive: true)
class AnalyticsCapturePref extends _$AnalyticsCapturePref {
  @override
  Future<bool> build() async {
    final db = ref.watch(deviceGlobalAppDatabaseProvider);
    return readAnalyticsCaptureEnabledFromDb(db);
  }

  /// Persists the choice, then reports it so callers can apply the vendor
  /// enable/disable immediately. DB first: the toggle reflects stored truth
  /// on restart even if the vendor call fails.
  Future<bool> setEnabled(bool enabled) async {
    final db = ref.read(deviceGlobalAppDatabaseProvider);
    await writeAnalyticsCaptureEnabledToDb(db, enabled: enabled);
    state = AsyncData(enabled);
    return enabled;
  }
}
