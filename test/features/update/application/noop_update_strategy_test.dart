// Coverage for lib/features/update/application/noop_update_strategy.dart.
//
// NoOpUpdateStrategy is the "no update flow" implementation used for store-
// channel builds (TestFlight / Play). The contract is small and easy to pin:
//   * checkForUpdate always returns upToDate (no remote probing)
//   * applyUpdate immediately yields UpdateInstallProgress.completed()
//   * cancelUpdate is a no-op future
//
// We pin those contracts because future contributors sometimes reach for the
// remote manifest even on store channels — this test fails fast if the
// no-op strategy gains a network call.
import 'package:enjoy_player/features/update/application/noop_update_strategy.dart';
import 'package:enjoy_player/features/update/domain/update_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('NoOpUpdateStrategy.checkForUpdate', () {
    const strategy = NoOpUpdateStrategy();

    test(
      'returns upToDate even when current version is older-looking',
      () async {
        // The strategy must short-circuit before any network call, regardless
        // of the supplied version / snooze fields.
        expect(
          await strategy.checkForUpdate(currentVersion: '0.0.1'),
          const UpdateCheckResult.upToDate(),
        );
      },
    );

    test('ignores snooze fields (always upToDate)', () async {
      final result = await strategy.checkForUpdate(
        currentVersion: '1.2.3',
        snoozedVersion: '9.9.9',
        snoozeUntil: DateTime.utc(2099, 1, 1),
      );
      expect(result, const UpdateCheckResult.upToDate());
      expect(result.availability, UpdateAvailability.upToDate);
    });
  });

  group('NoOpUpdateStrategy.applyUpdate', () {
    const strategy = NoOpUpdateStrategy();

    test('yields exactly one UpdateInstallProgress.completed()', () async {
      final release = const AppRelease(
        manifest: ReleaseManifest(
          version: '1.0.0',
          build: 1,
          minSupportedVersion: '0.0.0',
          notes: '',
          assets: {},
        ),
        severity: UpdateSeverity.optional,
        currentVersion: '0.9.0',
      );

      final phases = <UpdateInstallProgress>[];
      await for (final phase in strategy.applyUpdate(release)) {
        phases.add(phase);
      }
      expect(phases, hasLength(1));
      expect(phases.single, const UpdateInstallProgress.completed());
      expect(phases.single.phase, UpdateInstallPhase.completed);
    });

    test('does not consult the release or severity', () async {
      // Sanity: even for mandatory severity, the no-op strategy completes
      // immediately (the store handles the actual update).
      final mandatoryRelease = const AppRelease(
        manifest: ReleaseManifest(
          version: '9.9.9',
          build: 99,
          minSupportedVersion: '9.0.0',
          notes: '',
          assets: {},
        ),
        severity: UpdateSeverity.mandatory,
        currentVersion: '1.0.0',
      );

      final phases = <UpdateInstallProgress>[];
      await for (final phase in strategy.applyUpdate(mandatoryRelease)) {
        phases.add(phase);
      }
      expect(phases.single.phase, UpdateInstallPhase.completed);
    });
  });

  group('NoOpUpdateStrategy.cancelUpdate', () {
    test('returns a Future that completes without throwing', () async {
      const strategy = NoOpUpdateStrategy();
      // The contract is "Future<void>" with no side effects.
      await strategy.cancelUpdate();
      // A second cancel call must also be a no-op (no state to corrupt).
      await strategy.cancelUpdate();
    });
  });
}
