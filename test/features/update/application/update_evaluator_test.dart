// Tests for `lib/features/update/application/update_evaluator.dart` — pure
// logic that compares the running version to a remote manifest and produces
// a `UpdateCheckResult` with the right availability + snooze handling.
import 'package:enjoy_player/features/update/application/update_evaluator.dart';
import 'package:enjoy_player/features/update/domain/update_types.dart';
import 'package:flutter_test/flutter_test.dart';

const _asset = PlatformAsset(url: 'https://example.com/installer.dmg');

ReleaseManifest _manifest({
  String version = '1.2.0',
  String minSupportedVersion = '1.0.0',
}) {
  return ReleaseManifest(
    version: version,
    build: 100,
    minSupportedVersion: minSupportedVersion,
    notes: '',
    assets: const {'macos': _asset},
  );
}

void main() {
  final now = DateTime.utc(2026, 7, 25, 12);

  group('evaluateUpdate', () {
    test('returns upToDate when currentVersion == manifest.version', () {
      final r = evaluateUpdate(
        currentVersion: '1.2.0',
        manifest: _manifest(),
        now: now,
      );
      expect(r.availability, UpdateAvailability.upToDate);
      expect(r.release, isNull);
    });

    test('returns upToDate when currentVersion > manifest.version', () {
      final r = evaluateUpdate(
        currentVersion: '1.3.0',
        manifest: _manifest(),
        now: now,
      );
      expect(r.availability, UpdateAvailability.upToDate);
      expect(r.release, isNull);
    });

    test(
      'returns mandatoryUpdate when current < manifest.minSupportedVersion',
      () {
        final r = evaluateUpdate(
          currentVersion: '0.9.0',
          manifest: _manifest(minSupportedVersion: '1.0.0'),
          now: now,
        );
        expect(r.availability, UpdateAvailability.mandatoryUpdate);
        expect(r.release?.severity, UpdateSeverity.mandatory);
      },
    );

    test('returns updateAvailable when newer but supported', () {
      final r = evaluateUpdate(
        currentVersion: '1.1.0',
        manifest: _manifest(),
        now: now,
      );
      expect(r.availability, UpdateAvailability.updateAvailable);
      expect(r.release?.severity, UpdateSeverity.optional);
    });

    test(
      'suppresses optional prompt when snoozed for the same version and time',
      () {
        final r = evaluateUpdate(
          currentVersion: '1.1.0',
          manifest: _manifest(),
          snoozedVersion: '1.2.0',
          snoozeUntil: now.add(const Duration(hours: 12)),
          now: now,
        );
        // availability is upToDate (suppressed) but the badge still shows.
        expect(r.availability, UpdateAvailability.upToDate);
        expect(r.release, isNotNull);
        expect(r.showsUpdateBadge, isTrue);
      },
    );

    test('shows updateAvailable again when snooze has expired', () {
      final r = evaluateUpdate(
        currentVersion: '1.1.0',
        manifest: _manifest(),
        snoozedVersion: '1.2.0',
        snoozeUntil: now.subtract(const Duration(seconds: 1)),
        now: now,
      );
      expect(r.availability, UpdateAvailability.updateAvailable);
    });

    test('different snoozedVersion does not suppress the prompt', () {
      final r = evaluateUpdate(
        currentVersion: '1.1.0',
        manifest: _manifest(),
        snoozedVersion: '1.1.0',
        snoozeUntil: now.add(const Duration(hours: 12)),
        now: now,
      );
      expect(r.availability, UpdateAvailability.updateAvailable);
    });
  });
}
