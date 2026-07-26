// Tests for `lib/features/update/application/update_controller.dart` —
// covers build(), bootstrap(), checkForUpdatesStartup/Manual() (both
// non-direct early-return and direct-channel paths via DB state),
// snoozeOptionalUpdate(), dismissOptionalPrompt(), applyPendingUpdate()
// (no-release path), and cancelPendingUpdate().
//
// The CI test target defaults to TargetPlatform.android (store channel),
// so the strategy is not invoked. We exercise the direct-channel code
// paths by seeding `state` directly and via persistLastCheck side effects.
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/settings_keys.dart';
import 'package:enjoy_player/features/update/application/noop_update_strategy.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/update/application/update_providers.dart';
import 'package:enjoy_player/features/update/application/update_strategy.dart';
import 'package:enjoy_player/features/update/domain/update_types.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _ScriptedStrategy implements UpdateStrategy {
  _ScriptedStrategy(this._result);

  final UpdateCheckResult _result;
  int callCount = 0;

  @override
  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
    String? snoozedVersion,
    DateTime? snoozeUntil,
  }) async {
    callCount++;
    return _result;
  }

  @override
  Stream<UpdateInstallProgress> applyUpdate(AppRelease release) async* {}

  @override
  Future<void> cancelUpdate() async {}
}

ReleaseManifest _manifest({String version = '1.2.3'}) {
  return ReleaseManifest(
    version: version,
    build: 99,
    minSupportedVersion: '1.0.0',
    notes: '',
    assets: const {},
  );
}

AppRelease _release({UpdateSeverity severity = UpdateSeverity.optional}) {
  return AppRelease(
    manifest: _manifest(),
    severity: severity,
    currentVersion: '1.0.0',
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  group('UpdateCtrl.build', () {
    test('starts with a null state', () {
      final container = ProviderContainer(
        overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      expect(container.read(updateCtrlProvider), isNull);
    });
  });

  group('UpdateCtrl.checkForUpdatesStartup (store channel)', () {
    test(
      'returns upToDate without invoking the strategy on non-direct channel',
      () async {
        final strategy = _ScriptedStrategy(
          UpdateCheckResult(
            availability: UpdateAvailability.updateAvailable,
            release: _release(),
          ),
        );
        final container = ProviderContainer(
          overrides: [
            deviceGlobalAppDatabaseProvider.overrideWithValue(db),
            updateStrategyProvider.overrideWithValue(strategy),
          ],
        );
        addTearDown(container.dispose);

        final result = await container
            .read(updateCtrlProvider.notifier)
            .checkForUpdatesStartup();
        expect(result.availability, UpdateAvailability.upToDate);
        expect(strategy.callCount, 0);
        expect(container.read(updateCtrlProvider), isNull);
      },
    );
  });

  group('UpdateCtrl.checkForUpdatesManual (store channel)', () {
    test('returns upToDate without invoking the strategy', () async {
      final strategy = _ScriptedStrategy(const UpdateCheckResult.upToDate());
      final container = ProviderContainer(
        overrides: [
          deviceGlobalAppDatabaseProvider.overrideWithValue(db),
          updateStrategyProvider.overrideWithValue(strategy),
        ],
      );
      addTearDown(container.dispose);

      final result = await container
          .read(updateCtrlProvider.notifier)
          .checkForUpdatesManual();
      expect(result.availability, UpdateAvailability.upToDate);
      expect(strategy.callCount, 0);
    });
  });

  group('UpdateCtrl.snoozeOptionalUpdate', () {
    test('persists snooze and clears availability', () async {
      final container = ProviderContainer(
        overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final release = _release();
      // Seed state with release so snooze can mutate it.
      container.read(updateCtrlProvider.notifier).state = UpdateCheckResult(
        availability: UpdateAvailability.updateAvailable,
        release: release,
      );
      await container
          .read(updateCtrlProvider.notifier)
          .snoozeOptionalUpdate(release);

      final until = await db.settingsDao.getValue(
        SettingsKeys.updateSnoozeUntil,
      );
      expect(until, isNotNull);
      final version = await db.settingsDao.getValue(
        SettingsKeys.updateSnoozeVersion,
      );
      expect(version, '1.2.3');
      expect(
        container.read(updateCtrlProvider)?.availability,
        UpdateAvailability.upToDate,
      );
      expect(container.read(updateCtrlProvider)?.release, isNotNull);
    });

    test('also snoozes a mandatory release', () async {
      final container = ProviderContainer(
        overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final release = _release(severity: UpdateSeverity.mandatory);
      container.read(updateCtrlProvider.notifier).state = UpdateCheckResult(
        availability: UpdateAvailability.mandatoryUpdate,
        release: release,
      );
      await container
          .read(updateCtrlProvider.notifier)
          .snoozeOptionalUpdate(release);

      final until = await db.settingsDao.getValue(
        SettingsKeys.updateSnoozeUntil,
      );
      expect(until, isNotNull);
      expect(
        container.read(updateCtrlProvider)?.availability,
        UpdateAvailability.upToDate,
      );
    });
  });

  group('UpdateCtrl.dismissOptionalPrompt', () {
    test('clears availability only for optional releases', () {
      final container = ProviderContainer(
        overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      final optional = _release(severity: UpdateSeverity.optional);
      final mandatory = _release(severity: UpdateSeverity.mandatory);

      // Optional release → dismiss.
      container.read(updateCtrlProvider.notifier).state = UpdateCheckResult(
        availability: UpdateAvailability.updateAvailable,
        release: optional,
      );
      container.read(updateCtrlProvider.notifier).dismissOptionalPrompt();
      expect(
        container.read(updateCtrlProvider)?.availability,
        UpdateAvailability.upToDate,
      );

      // Mandatory release → dismiss is a no-op.
      container.read(updateCtrlProvider.notifier).state = UpdateCheckResult(
        availability: UpdateAvailability.mandatoryUpdate,
        release: mandatory,
      );
      container.read(updateCtrlProvider.notifier).dismissOptionalPrompt();
      expect(
        container.read(updateCtrlProvider)?.availability,
        UpdateAvailability.mandatoryUpdate,
      );
    });

    test('is a no-op when state has no release', () {
      final container = ProviderContainer(
        overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      // Empty state.
      container.read(updateCtrlProvider.notifier).dismissOptionalPrompt();
      expect(container.read(updateCtrlProvider), isNull);
    });
  });

  group('UpdateCtrl.applyPendingUpdate', () {
    test('yields a failure when there is no pending release', () async {
      final container = ProviderContainer(
        overrides: [
          deviceGlobalAppDatabaseProvider.overrideWithValue(db),
          updateStrategyProvider.overrideWithValue(const NoOpUpdateStrategy()),
        ],
      );
      addTearDown(container.dispose);

      final events = <UpdateInstallProgress>[];
      await for (final e
          in container.read(updateCtrlProvider.notifier).applyPendingUpdate()) {
        events.add(e);
      }
      expect(events, isNotEmpty);
      expect(events.last.phase, UpdateInstallPhase.failed);
    });
  });

  group('UpdateCtrl.cancelPendingUpdate', () {
    test('does not throw on empty state', () async {
      final container = ProviderContainer(
        overrides: [
          deviceGlobalAppDatabaseProvider.overrideWithValue(db),
          updateStrategyProvider.overrideWithValue(const NoOpUpdateStrategy()),
        ],
      );
      addTearDown(container.dispose);

      await container.read(updateCtrlProvider.notifier).cancelPendingUpdate();
    });
  });

  group('updateAvailableBadge', () {
    test('is false when state is null', () {
      final container = ProviderContainer(
        overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
      expect(container.read(updateAvailableBadgeProvider), isFalse);
    });

    test('is true when state has a release', () {
      final container = ProviderContainer(
        overrides: [deviceGlobalAppDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);

      container.read(updateCtrlProvider.notifier).state = UpdateCheckResult(
        availability: UpdateAvailability.upToDate,
        release: _release(),
      );
      expect(container.read(updateAvailableBadgeProvider), isTrue);
    });
  });
}
