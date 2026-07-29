/// Tests for [sync_types.dart] — wire-name conversions and [SyncResult.merge].
///
/// `sync_types.dart` is referenced transitively by every sync test, but its
/// own contract (round-trippable wire names, the empty-errors edge case in
/// [SyncResult.merge]) is not asserted anywhere. These tests pin the contract
/// so a future refactor of the wire format does not silently desync mobile
/// from the backend.
library;

import 'package:enjoy_player/features/sync/domain/sync_types.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SyncEntityType', () {
    test('wireName matches backend spelling', () {
      expect(SyncEntityType.audio.wireName, 'audio');
      expect(SyncEntityType.video.wireName, 'video');
      expect(SyncEntityType.recording.wireName, 'recording');
      expect(
        SyncEntityType.youtubeSubscription.wireName,
        'youtube_subscription',
      );
      expect(SyncEntityType.vocabularyItem.wireName, 'vocabulary_item');
      expect(SyncEntityType.vocabularyContext.wireName, 'vocabulary_context');
    });

    test('tryParse round-trips every wire name', () {
      for (final type in SyncEntityType.values) {
        expect(
          SyncEntityTypeWire.tryParse(type.wireName),
          same(type),
          reason: 'round-trip failed for ${type.name}',
        );
      }
    });

    test('tryParse returns null for unknown wire names', () {
      expect(SyncEntityTypeWire.tryParse(''), isNull);
      expect(SyncEntityTypeWire.tryParse('subtitle'), isNull);
      expect(SyncEntityTypeWire.tryParse('YOUTUBE_SUBSCRIPTION'), isNull);
    });
  });

  group('SyncAction', () {
    test('wireName matches backend spelling', () {
      expect(SyncAction.create.wireName, 'create');
      expect(SyncAction.update.wireName, 'update');
      expect(SyncAction.delete.wireName, 'delete');
    });

    test('tryParse round-trips every wire name', () {
      for (final action in SyncAction.values) {
        expect(
          SyncActionWire.tryParse(action.wireName),
          same(action),
          reason: 'round-trip failed for ${action.name}',
        );
      }
    });

    test('tryParse returns null for unknown wire names', () {
      expect(SyncActionWire.tryParse(''), isNull);
      expect(SyncActionWire.tryParse('upsert'), isNull);
      expect(SyncActionWire.tryParse('DELETE'), isNull);
    });
  });

  group('SyncOptions', () {
    test('resetFailed defaults to false', () {
      expect(const SyncOptions().resetFailed, isFalse);
    });

    test('resetFailed can be set', () {
      expect(const SyncOptions(resetFailed: true).resetFailed, isTrue);
    });
  });

  group('SyncResult.merge', () {
    test('success is true only when both succeed', () {
      final ok = const SyncResult(success: true, synced: 1, failed: 0);
      final fail = const SyncResult(success: false, synced: 0, failed: 1);

      expect(ok.merge(ok).success, isTrue);
      expect(ok.merge(fail).success, isFalse);
      expect(fail.merge(ok).success, isFalse);
      expect(fail.merge(fail).success, isFalse);
    });

    test('synced and failed counts add', () {
      final a = const SyncResult(success: true, synced: 3, failed: 1);
      final b = const SyncResult(success: true, synced: 2, failed: 4);

      final merged = a.merge(b);
      expect(merged.synced, 5);
      expect(merged.failed, 5);
    });

    test('errors list concatenates when both sides present', () {
      final a = const SyncResult(
        success: false,
        synced: 0,
        failed: 1,
        errors: ['audio: 404'],
      );
      final b = const SyncResult(
        success: false,
        synced: 0,
        failed: 1,
        errors: ['video: 500'],
      );

      final merged = a.merge(b);
      expect(merged.errors, ['audio: 404', 'video: 500']);
    });

    test('merge of two null-errors results yields an empty list', () {
      // `errors: [...?errors, ...?other.errors]` always allocates the list,
      // so two null-error inputs produce `[]`, not `null`. Pin this so a
      // refactor that returns null instead does not silently change the
      // JSON shape.
      final a = const SyncResult(success: true, synced: 1, failed: 0);
      final b = const SyncResult(success: true, synced: 1, failed: 0);

      final merged = a.merge(b);
      expect(merged.errors, isNotNull);
      expect(merged.errors, isEmpty);
    });

    test('merge propagates the left errors list when right is null', () {
      final a = const SyncResult(
        success: false,
        synced: 0,
        failed: 1,
        errors: ['recording: timeout'],
      );
      final b = const SyncResult(success: true, synced: 1, failed: 0);

      expect(a.merge(b).errors, ['recording: timeout']);
    });

    test('merge propagates the right errors list when left is null', () {
      final a = const SyncResult(success: true, synced: 1, failed: 0);
      final b = const SyncResult(
        success: false,
        synced: 0,
        failed: 1,
        errors: ['video: 500'],
      );

      expect(a.merge(b).errors, ['video: 500']);
    });

    test('merge with one empty errors list still concatenates', () {
      final a = const SyncResult(
        success: false,
        synced: 0,
        failed: 1,
        errors: ['a'],
      );
      final b = const SyncResult(
        success: true,
        synced: 1,
        failed: 0,
        errors: [],
      );

      expect(a.merge(b).errors, ['a']);
    });
  });
}
