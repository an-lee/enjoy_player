import 'package:enjoy_player/features/craft/domain/craft_save_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('CraftSaveResult', () {
    test('equality for identical values', () {
      const a = CraftSaveResult(mediaId: 'm1', wroteSolidTranscript: true);
      const b = CraftSaveResult(mediaId: 'm1', wroteSolidTranscript: true);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('inequality when mediaId differs', () {
      const a = CraftSaveResult(mediaId: 'm1', wroteSolidTranscript: true);
      const b = CraftSaveResult(mediaId: 'm2', wroteSolidTranscript: true);
      expect(a, isNot(equals(b)));
    });

    test('inequality when wroteSolidTranscript differs', () {
      const a = CraftSaveResult(mediaId: 'm1', wroteSolidTranscript: true);
      const b = CraftSaveResult(mediaId: 'm1', wroteSolidTranscript: false);
      expect(a, isNot(equals(b)));
    });

    test('inequality when wasDedupe differs', () {
      const a = CraftSaveResult(
        mediaId: 'm1',
        wroteSolidTranscript: true,
        wasDedupe: false,
      );
      const b = CraftSaveResult(
        mediaId: 'm1',
        wroteSolidTranscript: true,
        wasDedupe: true,
      );
      expect(a, isNot(equals(b)));
    });

    test('identical instance is equal', () {
      const a = CraftSaveResult(mediaId: 'x', wroteSolidTranscript: false);
      expect(a == a, isTrue); // identical check
    });

    test('not equal to non-CraftSaveResult', () {
      const a = CraftSaveResult(mediaId: 'x', wroteSolidTranscript: false);
      // ignore: unrelated_type_equality_checks
      expect(a == 'not a result', isFalse);
    });

    test('wasDedupe defaults to false', () {
      const a = CraftSaveResult(mediaId: 'm1', wroteSolidTranscript: true);
      expect(a.wasDedupe, isFalse);
    });
  });
}
