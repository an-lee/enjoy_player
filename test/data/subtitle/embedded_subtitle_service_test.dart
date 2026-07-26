import 'dart:convert';

import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/data/subtitle/embedded_subtitle_service.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('EmbeddedSubtitleService.allocateLanguageCode', () {
    test('returns the language unchanged when not yet used', () {
      final used = <String>{};
      expect(EmbeddedSubtitleService.allocateLanguageCode('eng', used), 'eng');
      expect(used, contains('eng'));
    });

    test('converts empty string to und', () {
      final used = <String>{};
      expect(EmbeddedSubtitleService.allocateLanguageCode('', used), 'und');
      expect(used, contains('und'));
    });

    test('appends -2 suffix when language already used', () {
      final used = <String>{'eng'};
      expect(
        EmbeddedSubtitleService.allocateLanguageCode('eng', used),
        'eng-2',
      );
      expect(used, containsAll(<String>{'eng', 'eng-2'}));
    });

    test('increments suffix when -2 is also taken', () {
      final used = <String>{'eng', 'eng-2'};
      expect(
        EmbeddedSubtitleService.allocateLanguageCode('eng', used),
        'eng-3',
      );
      expect(used, containsAll(<String>{'eng', 'eng-2', 'eng-3'}));
    });

    test('handles und collision with suffix', () {
      final used = <String>{'und'};
      expect(EmbeddedSubtitleService.allocateLanguageCode('', used), 'und-2');
    });

    test('multiple allocations build up the set correctly', () {
      final used = <String>{};
      expect(EmbeddedSubtitleService.allocateLanguageCode('jpn', used), 'jpn');
      expect(
        EmbeddedSubtitleService.allocateLanguageCode('jpn', used),
        'jpn-2',
      );
      expect(
        EmbeddedSubtitleService.allocateLanguageCode('jpn', used),
        'jpn-3',
      );
      expect(used, hasLength(3));
    });

    test('different languages do not collide', () {
      final used = <String>{};
      expect(EmbeddedSubtitleService.allocateLanguageCode('eng', used), 'eng');
      expect(EmbeddedSubtitleService.allocateLanguageCode('fra', used), 'fra');
      expect(EmbeddedSubtitleService.allocateLanguageCode('deu', used), 'deu');
      expect(used, hasLength(3));
    });

    test('does not collide with related codes that share a prefix', () {
      final used = <String>{'eng-2'};
      expect(EmbeddedSubtitleService.allocateLanguageCode('eng', used), 'eng');
    });

    test('handles language with existing high suffix', () {
      final used = <String>{'zho', 'zho-2', 'zho-3', 'zho-4', 'zho-5'};
      expect(
        EmbeddedSubtitleService.allocateLanguageCode('zho', used),
        'zho-6',
      );
    });

    test('empty used set always returns base', () {
      expect(
        EmbeddedSubtitleService.allocateLanguageCode('ita', <String>{}),
        'ita',
      );
      expect(
        EmbeddedSubtitleService.allocateLanguageCode('', <String>{}),
        'und',
      );
    });
  });

  group('EmbeddedSubtitleService.trackLabelFromParts', () {
    test('uses title when provided', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts('Commentary', 'eng', 0),
        'Commentary · ENG',
      );
    });

    test('uses uppercased language when no title', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts(null, 'fra', 2),
        'FRA',
      );
    });

    test('falls back to Track N when both title and language are null', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts(null, null, 0),
        'Track 1',
      );
      expect(
        EmbeddedSubtitleService.trackLabelFromParts(null, null, 4),
        'Track 5',
      );
    });

    test('ignores und language', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts(null, 'und', 1),
        'Track 2',
      );
    });

    test('ignores empty title', () {
      expect(EmbeddedSubtitleService.trackLabelFromParts('', 'deu', 0), 'DEU');
    });

    test('ignores empty language', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts('Director', '', 3),
        'Director',
      );
    });

    test('title and und language falls back to title only', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts('Forced', 'und', 0),
        'Forced',
      );
    });

    test('both empty falls back to Track N', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts('', '', 9),
        'Track 10',
      );
    });

    test('title with special characters preserved', () {
      expect(
        EmbeddedSubtitleService.trackLabelFromParts("Director's Cut", 'eng', 0),
        "Director's Cut · ENG",
      );
    });
  });

  group('EmbeddedSubtitleService.rowForExtracted', () {
    final lines = <TranscriptLine>[
      const TranscriptLine(text: 'Hello', startMs: 1000, durationMs: 2000),
      const TranscriptLine(text: 'World', startMs: 3500, durationMs: 1500),
    ];

    test('produces a TranscriptRow with correct fields', () {
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-123',
        targetTypeDexie: 'Video',
        language: 'eng',
        label: 'English',
        trackIndex: 0,
        lines: lines,
      );

      expect(row.targetId, 'vid-123');
      expect(row.targetType, 'Video');
      expect(row.language, 'eng');
      expect(row.source, 'user');
      expect(row.label, 'English');
      expect(row.trackIndex, 0);
      expect(row.referenceId, 'embedded:0');
      expect(row.syncStatus, 'local');
      expect(row.serverUpdatedAt, isNull);
    });

    test('generates deterministic id via enjoyTranscriptId', () {
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-123',
        targetTypeDexie: 'Video',
        language: 'eng',
        label: 'English',
        trackIndex: 0,
        lines: lines,
      );

      final expectedId = enjoyTranscriptId(
        targetType: 'Video',
        targetId: 'vid-123',
        language: 'eng',
        source: 'user',
      );
      expect(row.id, expectedId);
    });

    test('different languages produce different ids', () {
      final rowEng = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-1',
        targetTypeDexie: 'Video',
        language: 'eng',
        label: 'English',
        trackIndex: 0,
        lines: lines,
      );
      final rowFra = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-1',
        targetTypeDexie: 'Video',
        language: 'fra',
        label: 'French',
        trackIndex: 1,
        lines: lines,
      );
      expect(rowEng.id, isNot(rowFra.id));
    });

    test('timelineJson is valid JSON array of TranscriptLine', () {
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-1',
        targetTypeDexie: 'Audio',
        language: 'jpn',
        label: 'Japanese',
        trackIndex: 2,
        lines: lines,
      );

      final decoded = jsonDecode(row.timelineJson) as List<dynamic>;
      expect(decoded, hasLength(2));

      final first = decoded[0] as Map<String, dynamic>;
      expect(first['text'], 'Hello');
      expect(first['start'], 1000);
      expect(first['duration'], 2000);

      final second = decoded[1] as Map<String, dynamic>;
      expect(second['text'], 'World');
      expect(second['start'], 3500);
      expect(second['duration'], 1500);
    });

    test('empty lines list produces empty JSON array', () {
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-1',
        targetTypeDexie: 'Video',
        language: 'und',
        label: 'Track 1',
        trackIndex: 0,
        lines: const <TranscriptLine>[],
      );
      expect(jsonDecode(row.timelineJson), isEmpty);
    });

    test('referenceId encodes the track index', () {
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-1',
        targetTypeDexie: 'Video',
        language: 'eng',
        label: 'E',
        trackIndex: 5,
        lines: lines,
      );
      expect(row.referenceId, 'embedded:5');
    });

    test('createdAt and updatedAt are recent and equal', () {
      final before = DateTime.now();
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-1',
        targetTypeDexie: 'Video',
        language: 'eng',
        label: 'E',
        trackIndex: 0,
        lines: lines,
      );
      final after = DateTime.now();

      expect(
        row.createdAt.isAfter(before) || row.createdAt.isAtSameMomentAs(before),
        isTrue,
      );
      expect(
        row.createdAt.isBefore(after) || row.createdAt.isAtSameMomentAs(after),
        isTrue,
      );
      expect(row.updatedAt, row.createdAt);
    });

    test('lines with sourceKey serialize correctly', () {
      final linesWithKey = <TranscriptLine>[
        const TranscriptLine(
          text: 'Bonjour',
          startMs: 0,
          durationMs: 1000,
          sourceKey: 'abc123',
        ),
      ];
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-1',
        targetTypeDexie: 'Video',
        language: 'fra',
        label: 'FRA',
        trackIndex: 0,
        lines: linesWithKey,
      );

      final decoded = jsonDecode(row.timelineJson) as List<dynamic>;
      final first = decoded[0] as Map<String, dynamic>;
      expect(first['sourceKey'], 'abc123');
    });
  });

  group('EmbeddedSubtitleService.rowForExtracted target types', () {
    final lines = <TranscriptLine>[
      const TranscriptLine(text: 'Line', startMs: 0, durationMs: 500),
    ];

    test('works with Audio target type', () {
      final row = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'aud-99',
        targetTypeDexie: 'Audio',
        language: 'kor',
        label: 'KOR',
        trackIndex: 1,
        lines: lines,
      );
      expect(row.targetType, 'Audio');
      expect(row.targetId, 'aud-99');
      expect(
        row.id,
        enjoyTranscriptId(
          targetType: 'Audio',
          targetId: 'aud-99',
          language: 'kor',
          source: 'user',
        ),
      );
    });

    test('same inputs always produce the same id', () {
      final row1 = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-x',
        targetTypeDexie: 'Video',
        language: 'spa',
        label: 'SPA',
        trackIndex: 0,
        lines: lines,
      );
      final row2 = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-x',
        targetTypeDexie: 'Video',
        language: 'spa',
        label: 'SPA',
        trackIndex: 0,
        lines: lines,
      );
      expect(row1.id, row2.id);
    });

    test('different trackIndex does not change id (id is language-scoped)', () {
      final row1 = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-x',
        targetTypeDexie: 'Video',
        language: 'spa',
        label: 'SPA',
        trackIndex: 0,
        lines: lines,
      );
      final row2 = EmbeddedSubtitleService.rowForExtracted(
        targetId: 'vid-x',
        targetTypeDexie: 'Video',
        language: 'spa',
        label: 'SPA',
        trackIndex: 3,
        lines: lines,
      );
      expect(row1.id, row2.id);
      expect(row1.referenceId, 'embedded:0');
      expect(row2.referenceId, 'embedded:3');
    });
  });
}
