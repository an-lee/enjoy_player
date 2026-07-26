// Tests for `lib/features/update/domain/update_types.dart` — pure data
// classes used by the update prompt / controller / strategy layer.
import 'package:enjoy_player/features/update/domain/update_types.dart';
import 'package:flutter_test/flutter_test.dart';

const _asset = PlatformAsset(url: 'https://example.com/installer.dmg');
const _manifest = ReleaseManifest(
  version: '1.2.0',
  build: 100,
  minSupportedVersion: '1.0.0',
  notes: 'Bug fixes',
  assets: {'macos': _asset},
);

void main() {
  group('UpdateCheckResult', () {
    test('upToDate() factory sets availability to upToDate and nulls', () {
      const r = UpdateCheckResult.upToDate();
      expect(r.availability, UpdateAvailability.upToDate);
      expect(r.release, isNull);
      expect(r.errorMessage, isNull);
    });

    test('hasUpdate is true for updateAvailable', () {
      final r = const UpdateCheckResult(
        availability: UpdateAvailability.updateAvailable,
        release: AppRelease(
          manifest: _manifest,
          severity: UpdateSeverity.optional,
          currentVersion: '1.1.0',
        ),
      );
      expect(r.hasUpdate, isTrue);
    });

    test('hasUpdate is true for mandatoryUpdate', () {
      final r = const UpdateCheckResult(
        availability: UpdateAvailability.mandatoryUpdate,
        release: AppRelease(
          manifest: _manifest,
          severity: UpdateSeverity.mandatory,
          currentVersion: '0.9.0',
        ),
      );
      expect(r.hasUpdate, isTrue);
    });

    test('hasUpdate is false for upToDate even with a release set', () {
      final r = const UpdateCheckResult(
        availability: UpdateAvailability.upToDate,
        release: AppRelease(
          manifest: _manifest,
          severity: UpdateSeverity.optional,
          currentVersion: '1.2.0',
        ),
      );
      expect(r.hasUpdate, isFalse);
      // But the badge still shows — we want the user to know a build exists.
      expect(r.showsUpdateBadge, isTrue);
    });

    test('showsUpdateBadge is false when release is null', () {
      const r = UpdateCheckResult.upToDate();
      expect(r.showsUpdateBadge, isFalse);
    });

    test('errorMessage is surfaced via the toString-ish accessor', () {
      const r = UpdateCheckResult(
        availability: UpdateAvailability.upToDate,
        errorMessage: 'http 500',
      );
      expect(r.errorMessage, 'http 500');
    });
  });

  group('UpdateInstallProgress', () {
    test('preparing() factory sets phase = preparing, no percent', () {
      const p = UpdateInstallProgress.preparing();
      expect(p.phase, UpdateInstallPhase.preparing);
      expect(p.percent, isNull);
      expect(p.failureReason, isNull);
    });

    test('downloading(percent) captures percent and no failure', () {
      const p = UpdateInstallProgress.downloading(0.5);
      expect(p.phase, UpdateInstallPhase.downloading);
      expect(p.percent, 0.5);
      expect(p.failureReason, isNull);
    });

    test('verifying() / openingInstaller() / completed() phases', () {
      const v = UpdateInstallProgress.verifying();
      expect(v.phase, UpdateInstallPhase.verifying);
      expect(v.percent, isNull);

      const o = UpdateInstallProgress.openingInstaller();
      expect(o.phase, UpdateInstallPhase.openingInstaller);

      const c = UpdateInstallProgress.completed();
      expect(c.phase, UpdateInstallPhase.completed);
    });

    test('canceled() sets canceled phase + canceled reason', () {
      const p = UpdateInstallProgress.canceled();
      expect(p.phase, UpdateInstallPhase.canceled);
      expect(p.failureReason, UpdateInstallFailureReason.canceled);
      expect(p.isTerminal, isTrue);
    });

    test('failed() carries reason + optional detail', () {
      const p = UpdateInstallProgress.failed(
        reason: UpdateInstallFailureReason.checksum,
        detail: 'sha mismatch',
      );
      expect(p.phase, UpdateInstallPhase.failed);
      expect(p.failureReason, UpdateInstallFailureReason.checksum);
      expect(p.failureDetail, 'sha mismatch');
      expect(p.isTerminal, isTrue);
    });

    test('isTerminal is false during downloading / verifying', () {
      const d = UpdateInstallProgress.downloading(0.1);
      const v = UpdateInstallProgress.verifying();
      expect(d.isTerminal, isFalse);
      expect(v.isTerminal, isFalse);
    });
  });

  group('PlatformAsset / ReleaseManifest / AppRelease', () {
    test('PlatformAsset stores url + optional sha256 + file', () {
      const a = PlatformAsset(
        url: 'https://example.com/x.msi',
        sha256: 'abc',
        file: 'x.msi',
      );
      expect(a.url, 'https://example.com/x.msi');
      expect(a.sha256, 'abc');
      expect(a.file, 'x.msi');
    });

    test('ReleaseManifest round-trips fields', () {
      const m = _manifest; // const for compile-time check
      expect(m.version, '1.2.0');
      expect(m.build, 100);
      expect(m.minSupportedVersion, '1.0.0');
      expect(m.notes, 'Bug fixes');
      expect(m.assets['macos'], _asset);
    });

    test('AppRelease carries manifest + severity + currentVersion', () {
      const r = AppRelease(
        manifest: _manifest,
        severity: UpdateSeverity.mandatory,
        currentVersion: '0.9.0',
      );
      expect(r.manifest, _manifest);
      expect(r.severity, UpdateSeverity.mandatory);
      expect(r.currentVersion, '0.9.0');
    });
  });
}
