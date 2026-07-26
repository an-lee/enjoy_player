// Pure-helper coverage for lib/data/subtitle/embedded_subtitle_service.dart.
//
// The service shell itself shells out to ffmpeg and ffmpeg_kit which we don't
// run in unit tests, so we focus on the three `@visibleForTesting` static
// helpers (`allocateLanguageCode`, `rowForExtracted`, `trackLabelFromParts`)
// that carry the interesting branch logic.
import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/data/subtitle/embedded_subtitle_service.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:flutter_test/flutter_test.dart';

TranscriptLine _line(String text, {int startMs = 0, int endMs = 1000}) =>
    TranscriptLine(text: text, startMs: startMs, durationMs: endMs - startMs);

void main() {
  group('allocateLanguageCode', () {
    test('returns the language as-is when it is not yet used', () {
      final used = <String>{};
      expect(EmbeddedSubtitleService.allocateLanguageCode('en', used), 'en');
      expect(used, {'en'});
    });

    test('falls back to "und" for an empty input string', () {
      final used = <String>{};
      expect(EmbeddedSubtitleService.allocateLanguageCode('', used), 'und');
      expect(used, {'und'});
    });

    test('disambiguates with -2/-3/... when the base language is taken', () {
      final used = {'en'};
      expect(EmbeddedSubtitleService.allocateLanguageCode('en', used), 'en-2');
      expect(used, {'en', 'en-2'});

      expect(EmbeddedSubtitleService.allocateLanguageCode('en', used), 'en-3');
      expect(used, {'en', 'en-2', 'en-3'});
    });

    test(
      'skips already-allocated -N variants before returning a fresh one',
      () {
        final used = {'en', 'en-2', 'en-3'};
        expect(
          EmbeddedSubtitleService.allocateLanguageCode('en', used),
          'en-4',
        );
        expect(used, {'en', 'en-2', 'en-3', 'en-4'});
      },
    );
  });

  group('trackLabelFromParts', () {
    test('combines title and uppercased language with a separator', () {
      final label = EmbeddedSubtitleService.trackLabelFromParts(
        'Forced',
        'en',
        0,
      );
      expect(label, 'Forced · EN');
    });

    test('omits the language segment when it is "und"', () {
      expect(EmbeddedSubtitleService.trackLabelFromParts('Hi', 'und', 0), 'Hi');
    });

    test('omits the language segment when it is null or empty', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts(null, null, 2),
        'Track 3',
      );
      expect(
        EmbeddedSubtitleService.trackLabelFromParts('Title', '', 0),
        'Title',
      );
    });

    test(
      'uses a 1-based "Track N" fallback when both title and lang are absent',
      () {
        expect(
          EmbeddedSubtitleService.trackLabelFromParts(null, 'und', 4),
          'Track 5',
        );
      },
    );
  });

  group('rowForExtracted', () {
    test('builds a row with the expected id, source, and timeline JSON', () {
      final lines = [_line('hi', startMs: 0, endMs: 1000)];
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'video-1',
        targetTypeDexie: 'Video',
        language: 'en',
        label: 'EN',
        trackIndex: 2,
        lines: lines,
      );

      expect(row.targetType, 'Video');
      expect(row.targetId, 'video-1');
      expect(row.language, 'en');
      expect(row.source, 'user');
      expect(row.label, 'EN');
      expect(row.trackIndex, 2);
      expect(row.referenceId, 'embedded:2');
      expect(row.syncStatus, 'local');
      expect(row.serverUpdatedAt, isNull);
      // The id is derived from (targetType, targetId, language, source).
      expect(
        row.id,
        enjoyTranscriptId(
          targetType: 'Video',
          targetId: 'video-1',
          language: 'en',
          source: 'user',
        ),
      );
      // Timeline is JSON-encoded array of line JSON.
      expect(row.timelineJson, contains('"text":"hi"'));
    });
  });
}
