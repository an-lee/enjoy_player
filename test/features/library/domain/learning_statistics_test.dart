import 'package:enjoy_player/features/library/domain/learning_statistics.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PeriodStats.fromJson', () {
    test('parses numeric duration and count', () {
      final p = PeriodStats.fromJson({
        'recordingDuration': 12345,
        'recordingCount': 7,
      });
      expect(p.recordingDurationMs, 12345);
      expect(p.recordingCount, 7);
    });

    test('parses numeric duration as double and rounds', () {
      final p = PeriodStats.fromJson({
        'recordingDuration': 1234.6,
        'recordingCount': 2.4,
      });
      expect(p.recordingDurationMs, 1235);
      expect(p.recordingCount, 2);
    });

    test('parses string-encoded numbers', () {
      final p = PeriodStats.fromJson({
        'recordingDuration': '500',
        'recordingCount': '3',
      });
      expect(p.recordingDurationMs, 500);
      expect(p.recordingCount, 3);
    });

    test('returns zero when json is null or empty', () {
      expect(PeriodStats.fromJson(null), PeriodStats.zero());
      expect(PeriodStats.fromJson({}), PeriodStats.zero());
    });

    test('returns zero for unparseable values', () {
      final p = PeriodStats.fromJson({
        'recordingDuration': 'not-a-number',
        'recordingCount': null,
      });
      expect(p.recordingDurationMs, 0);
      expect(p.recordingCount, 0);
    });

    test('handles missing individual fields', () {
      final p = PeriodStats.fromJson({'recordingDuration': 100});
      expect(p.recordingDurationMs, 100);
      expect(p.recordingCount, 0);
    });
  });

  group('LearningStatistics.fromJson', () {
    test('parses today/week/month blocks', () {
      final s = LearningStatistics.fromJson({
        'today': {'recordingDuration': 100, 'recordingCount': 1},
        'week': {'recordingDuration': 200, 'recordingCount': 2},
        'month': {'recordingDuration': 300, 'recordingCount': 3},
      });
      expect(s.today.recordingDurationMs, 100);
      expect(s.week.recordingDurationMs, 200);
      expect(s.month.recordingDurationMs, 300);
      expect(s.month.recordingCount, 3);
    });

    test('falls back to zero blocks when periods are missing', () {
      final s = LearningStatistics.fromJson({});
      expect(s.today.recordingDurationMs, 0);
      expect(s.week.recordingCount, 0);
      expect(s.month.recordingCount, 0);
    });

    test('handles non-object period entries', () {
      final s = LearningStatistics.fromJson({
        'today': 'today-string',
        'week': 99,
        'month': null,
      });
      // All three resolve to zero via castJsonObjectOrNull → null.
      expect(s.today, PeriodStats.zero());
      expect(s.week, PeriodStats.zero());
      expect(s.month, PeriodStats.zero());
    });

    test('empty() returns all-zero statistics', () {
      final s = LearningStatistics.empty();
      expect(s.today, PeriodStats.zero());
      expect(s.week, PeriodStats.zero());
      expect(s.month, PeriodStats.zero());
    });

    test('PeriodStats.zero() returns a const zero record', () {
      final z = PeriodStats.zero();
      expect(z.recordingDurationMs, 0);
      expect(z.recordingCount, 0);
    });
  });
}
