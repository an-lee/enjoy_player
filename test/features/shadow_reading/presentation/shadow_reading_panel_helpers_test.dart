// Tests for the `@visibleForTesting` helpers in
// `lib/features/shadow_reading/presentation/shadow_reading_panel.dart`.
//
// These helpers are pure functions inside a heavily platform-dependent
// ConsumerStatefulWidget, so the file exposes them via thin wrappers so we can
// unit-test them in isolation without spinning up the full widget tree.
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/shadow_reading_panel.dart';
import 'package:flutter_test/flutter_test.dart';

RecordingRow _row({
  required String id,
  required int startedAtMs,
  String language = 'en',
  String targetType = 'media',
  String targetId = 't1',
  String referenceText = '',
  int duration = 1500,
}) {
  final ts = DateTime.fromMillisecondsSinceEpoch(startedAtMs);
  return RecordingRow(
    id: id,
    targetType: targetType,
    targetId: targetId,
    referenceStart: 0,
    referenceDuration: 1500,
    referenceText: referenceText,
    language: language,
    duration: duration,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  group('shortSaveErrorForTest', () {
    test('returns trimmed string unchanged when short enough', () {
      expect(shortSaveErrorForTest('boom'), 'boom');
    });

    test('collapses internal whitespace to single spaces', () {
      expect(shortSaveErrorForTest('line1\nline2\tline3'), 'line1 line2 line3');
    });

    test('trims leading and trailing whitespace', () {
      expect(shortSaveErrorForTest('   hi   '), 'hi');
    });

    test('passes through 180-char strings verbatim', () {
      final s = 'x' * 180;
      expect(shortSaveErrorForTest(s), s);
      expect(shortSaveErrorForTest(s).length, 180);
    });

    test('truncates long strings to 177 chars + ellipsis', () {
      final s = 'x' * 500;
      final out = shortSaveErrorForTest(s);
      // substring(0, 177) + '…' = 178 chars total
      expect(out.length, 178);
      expect(out, endsWith('…'));
    });

    test('handles Exception objects via toString()', () {
      final out = shortSaveErrorForTest(Exception('disk full'));
      expect(out, contains('disk full'));
    });

    test('handles empty error strings', () {
      expect(shortSaveErrorForTest(''), '');
    });

    test('handles multi-line stack-like strings', () {
      final raw = 'Error: bad\n  at foo()\n  at bar()';
      final out = shortSaveErrorForTest(raw);
      expect(out, contains('Error: bad'));
      // Whitespace should be normalized to single spaces.
      expect(out.contains('\n'), isFalse);
    });
  });

  group('resolvedSelectedRowForTest', () {
    final rows = [
      _row(id: 'a', startedAtMs: 1000),
      _row(id: 'b', startedAtMs: 2000),
      _row(id: 'c', startedAtMs: 3000),
    ];

    test('returns null when the list is empty', () {
      expect(resolvedSelectedRowForTest(const [], 'a'), isNull);
    });

    test('returns null when the list is empty even with a selectedId', () {
      expect(resolvedSelectedRowForTest(const [], null), isNull);
    });

    test('returns the matching row when selectedId is present', () {
      expect(resolvedSelectedRowForTest(rows, 'b')?.id, 'b');
      expect(resolvedSelectedRowForTest(rows, 'a')?.id, 'a');
    });

    test('returns the first row when selectedId is null', () {
      expect(resolvedSelectedRowForTest(rows, null)?.id, 'a');
    });

    test('returns the first row when selectedId does not match', () {
      // Unknown id — fall through to the default (first) per the spec.
      expect(resolvedSelectedRowForTest(rows, 'missing')?.id, 'a');
    });

    test('returns the first row when selectedId is empty', () {
      expect(resolvedSelectedRowForTest(rows, '')?.id, 'a');
    });
  });
}
