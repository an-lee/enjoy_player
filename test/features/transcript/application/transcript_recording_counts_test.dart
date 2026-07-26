import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_line_recording_counts_provider.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_recording_counts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptLine _line(int startMs, int durationMs) =>
    TranscriptLine(text: 'line', startMs: startMs, durationMs: durationMs);

RecordingRow _recording(int referenceStart, int referenceDuration) {
  return RecordingRow(
    id: 'rec-${referenceStart}ms',
    targetType: 'Video',
    targetId: 'media-1',
    referenceStart: referenceStart,
    referenceDuration: referenceDuration,
    referenceText: 'test',
    language: 'en',
    duration: referenceDuration,
    createdAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2024),
  );
}

void main() {
  group('recordingOverlapsLine', () {
    test('true when recording fully inside line', () {
      final line = _line(1000, 5000); // [1000, 6000)
      final rec = _recording(2000, 1000); // [2000, 3000)
      expect(recordingOverlapsLine(rec, line), isTrue);
    });

    test('true when recording partially overlaps line start', () {
      final line = _line(1000, 2000); // [1000, 3000)
      final rec = _recording(500, 1000); // [500, 1500)
      expect(recordingOverlapsLine(rec, line), isTrue);
    });

    test('true when recording partially overlaps line end', () {
      final line = _line(1000, 2000); // [1000, 3000)
      final rec = _recording(2500, 1000); // [2500, 3500)
      expect(recordingOverlapsLine(rec, line), isTrue);
    });

    test('false when recording ends exactly at line start', () {
      final line = _line(1000, 2000); // [1000, 3000)
      final rec = _recording(0, 1000); // [0, 1000)
      expect(recordingOverlapsLine(rec, line), isFalse);
    });

    test('false when recording starts exactly at line end', () {
      final line = _line(1000, 2000); // [1000, 3000)
      final rec = _recording(3000, 1000); // [3000, 4000)
      expect(recordingOverlapsLine(rec, line), isFalse);
    });

    test('false when completely disjoint', () {
      final line = _line(5000, 1000); // [5000, 6000)
      final rec = _recording(0, 2000); // [0, 2000)
      expect(recordingOverlapsLine(rec, line), isFalse);
    });
  });

  group('countRecordingsPerLineIndex', () {
    test('returns empty map for empty lines', () {
      expect(countRecordingsPerLineIndex([], [_recording(0, 1000)]), isEmpty);
    });

    test('returns empty map for empty recordings', () {
      expect(countRecordingsPerLineIndex([_line(0, 1000)], []), isEmpty);
    });

    test('counts overlapping recordings per line', () {
      final lines = [_line(0, 2000), _line(2000, 2000), _line(4000, 2000)];
      final recordings = [
        _recording(500, 1000), // overlaps line 0 only
        _recording(1500, 1000), // overlaps line 0 and line 1
        _recording(4500, 500), // overlaps line 2 only
      ];
      final counts = countRecordingsPerLineIndex(lines, recordings);
      expect(counts[0], 2); // rec0 + rec1
      expect(counts[1], 1); // rec1
      expect(counts.containsKey(2), isTrue);
      expect(counts[2], 1); // rec2
    });

    test('omits lines with zero overlapping recordings', () {
      final lines = [_line(0, 1000), _line(5000, 1000)];
      final recordings = [_recording(0, 500)];
      final counts = countRecordingsPerLineIndex(lines, recordings);
      expect(counts[0], 1);
      expect(counts.containsKey(1), isFalse);
    });
  });

  group('resolveTranscriptLineRecordingCounts', () {
    test('returns null while lines are loading', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: const AsyncLoading(),
        targetTypeAsync: const AsyncData('Video'),
        recordingsAsync: const AsyncData([]),
        mediaId: 'm1',
      );
      expect(result, isNull);
    });

    test('returns empty map when lines have error', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: AsyncError(Exception('fail'), StackTrace.current),
        targetTypeAsync: const AsyncData('Video'),
        recordingsAsync: const AsyncData([]),
        mediaId: 'm1',
      );
      expect(result, isEmpty);
    });

    test('returns empty map when lines are empty', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: const AsyncData(<TranscriptLine>[]),
        targetTypeAsync: const AsyncData('Video'),
        recordingsAsync: const AsyncData([]),
        mediaId: 'm1',
      );
      expect(result, isEmpty);
    });

    test('returns null while targetType is loading', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: AsyncData([_line(0, 1000)]),
        targetTypeAsync: const AsyncLoading(),
        recordingsAsync: const AsyncData([]),
        mediaId: 'm1',
      );
      expect(result, isNull);
    });

    test('returns empty map when targetType has error', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: AsyncData([_line(0, 1000)]),
        targetTypeAsync: AsyncError(Exception('x'), StackTrace.current),
        recordingsAsync: const AsyncData([]),
        mediaId: 'm1',
      );
      expect(result, isEmpty);
    });

    test('returns empty map when targetType is null', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: AsyncData([_line(0, 1000)]),
        targetTypeAsync: const AsyncData(null),
        recordingsAsync: const AsyncData([]),
        mediaId: 'm1',
      );
      expect(result, isEmpty);
    });

    test('returns null while recordings are loading', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: AsyncData([_line(0, 1000)]),
        targetTypeAsync: const AsyncData('Video'),
        recordingsAsync: const AsyncLoading(),
        mediaId: 'm1',
      );
      expect(result, isNull);
    });

    test('returns empty map when recordings have error', () {
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: AsyncData([_line(0, 1000)]),
        targetTypeAsync: const AsyncData('Video'),
        recordingsAsync: AsyncError(Exception('y'), StackTrace.current),
        mediaId: 'm1',
      );
      expect(result, isEmpty);
    });

    test('returns counts when all data is available', () {
      final lines = [_line(0, 2000), _line(2000, 2000)];
      final recordings = [_recording(500, 1000)];
      final result = resolveTranscriptLineRecordingCounts(
        linesAsync: AsyncData(lines),
        targetTypeAsync: const AsyncData('Video'),
        recordingsAsync: AsyncData(recordings),
        mediaId: 'm1',
      );
      expect(result, isNotNull);
      expect(result![0], 1);
      expect(result.containsKey(1), isFalse);
    });
  });
}
