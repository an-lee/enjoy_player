import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('TipStatus', () {
    test('storageValue round-trips through parse for every variant', () {
      for (final status in TipStatus.values) {
        expect(TipStatus.parse(status.storageValue), status);
      }
    });

    test('parse returns pending for null and unknown strings', () {
      expect(TipStatus.parse(null), TipStatus.pending);
      expect(TipStatus.parse(''), TipStatus.pending);
      expect(TipStatus.parse('PENDING'), TipStatus.pending);
      expect(TipStatus.parse('done'), TipStatus.pending);
      expect(TipStatus.parse('completed?'), TipStatus.pending);
    });

    test('parse returns the matching status for known wire values', () {
      expect(TipStatus.parse('completed'), TipStatus.completed);
      expect(TipStatus.parse('skipped'), TipStatus.skipped);
    });

    test('isResolved is true for completed and skipped only', () {
      expect(TipStatus.pending.isResolved, isFalse);
      expect(TipStatus.completed.isResolved, isTrue);
      expect(TipStatus.skipped.isResolved, isTrue);
    });
  });

  group('TipProgressSnapshot defaults and lookups', () {
    test('default snapshot is empty for both maps', () {
      const snap = TipProgressSnapshot();
      expect(snap.global, isEmpty);
      expect(snap.emptyTranscriptByMediaId, isEmpty);
    });

    test('statusOfGlobal defaults to pending for unknown ids', () {
      const snap = TipProgressSnapshot();
      expect(
        snap.statusOfGlobal(OnboardingTipId.homeImport),
        TipStatus.pending,
      );
    });

    test('statusOfGlobal returns the recorded value', () {
      const snap = TipProgressSnapshot(
        global: {'home.import': TipStatus.completed},
      );
      expect(
        snap.statusOfGlobal(OnboardingTipId.homeImport),
        TipStatus.completed,
      );
    });

    test('statusOfEmptyTranscript defaults to pending for unknown media', () {
      const snap = TipProgressSnapshot();
      expect(snap.statusOfEmptyTranscript('media-x'), TipStatus.pending);
    });

    test('statusOfEmptyTranscript returns the recorded value per mediaId', () {
      const snap = TipProgressSnapshot(
        emptyTranscriptByMediaId: {'media-a': TipStatus.skipped},
      );
      expect(snap.statusOfEmptyTranscript('media-a'), TipStatus.skipped);
      expect(snap.statusOfEmptyTranscript('media-b'), TipStatus.pending);
    });
  });

  group('TipProgressSnapshot.copyWith', () {
    test(
      'returns a new instance with the same data when called with no args',
      () {
        const snap = TipProgressSnapshot(
          global: {'home.import': TipStatus.completed},
          emptyTranscriptByMediaId: {'media-a': TipStatus.skipped},
        );
        final copy = snap.copyWith();
        expect(identical(copy, snap), isFalse);
        expect(copy.global, snap.global);
        expect(copy.emptyTranscriptByMediaId, snap.emptyTranscriptByMediaId);
      },
    );

    test('replaces the global map when provided', () {
      const snap = TipProgressSnapshot(
        global: {'home.import': TipStatus.completed},
      );
      final replaced = snap.copyWith(global: {'home.craft': TipStatus.skipped});
      expect(replaced.global, {'home.craft': TipStatus.skipped});
      expect(replaced.emptyTranscriptByMediaId, snap.emptyTranscriptByMediaId);
    });

    test('replaces the per-media map when provided', () {
      const snap = TipProgressSnapshot(
        emptyTranscriptByMediaId: {'media-a': TipStatus.skipped},
      );
      final replaced = snap.copyWith(
        emptyTranscriptByMediaId: {'media-b': TipStatus.completed},
      );
      expect(replaced.global, snap.global);
      expect(replaced.emptyTranscriptByMediaId, {
        'media-b': TipStatus.completed,
      });
    });
  });

  group('TipProgressSnapshot.decodeGlobalJson', () {
    test('returns empty map for null and empty input', () {
      expect(TipProgressSnapshot.decodeGlobalJson(null), isEmpty);
      expect(TipProgressSnapshot.decodeGlobalJson(''), isEmpty);
    });

    test('parses valid JSON for known tip ids', () {
      final map = TipProgressSnapshot.decodeGlobalJson(
        '{"home.import":"completed","home.craft":"skipped"}',
      );
      expect(map, {
        'home.import': TipStatus.completed,
        'home.craft': TipStatus.skipped,
      });
    });

    test('drops unknown tip ids for forward compatibility', () {
      final map = TipProgressSnapshot.decodeGlobalJson(
        '{"home.import":"completed","legacy.tip":"skipped"}',
      );
      expect(map['home.import'], TipStatus.completed);
      expect(map.containsKey('legacy.tip'), isFalse);
    });

    test('normalizes unknown status strings to pending', () {
      final map = TipProgressSnapshot.decodeGlobalJson(
        '{"home.import":"weird"}',
      );
      expect(map['home.import'], TipStatus.pending);
    });

    test('returns empty when JSON is not an object', () {
      expect(TipProgressSnapshot.decodeGlobalJson('"home.import"'), isEmpty);
      expect(TipProgressSnapshot.decodeGlobalJson('[1,2,3]'), isEmpty);
      expect(TipProgressSnapshot.decodeGlobalJson('42'), isEmpty);
    });

    test('returns empty on malformed JSON', () {
      expect(TipProgressSnapshot.decodeGlobalJson('{"home.import":'), isEmpty);
    });

    test('skips entries with null or empty keys', () {
      final map = TipProgressSnapshot.decodeGlobalJson(
        '{"":"completed","home.import":"skipped"}',
      );
      expect(map.length, 1);
      expect(map['home.import'], TipStatus.skipped);
    });
  });

  group('TipProgressSnapshot.encodeGlobalJson', () {
    test('returns "{}", "{}" for empty input', () {
      expect(TipProgressSnapshot.encodeGlobalJson(const {}), '{}');
    });

    test('strips pending entries (only completed/skipped are persisted)', () {
      final encoded = TipProgressSnapshot.encodeGlobalJson(const {
        'home.import': TipStatus.completed,
        'home.craft': TipStatus.skipped,
        'player.echo': TipStatus.pending,
      });
      final decoded = TipProgressSnapshot.decodeGlobalJson(encoded);
      expect(decoded, {
        'home.import': TipStatus.completed,
        'home.craft': TipStatus.skipped,
      });
    });

    test('round-trips every non-pending status through encode + decode', () {
      for (final status in const [TipStatus.completed, TipStatus.skipped]) {
        final encoded = TipProgressSnapshot.encodeGlobalJson({
          'home.import': status,
        });
        final decoded = TipProgressSnapshot.decodeGlobalJson(encoded);
        expect(decoded['home.import'], status);
      }
    });
  });
}
