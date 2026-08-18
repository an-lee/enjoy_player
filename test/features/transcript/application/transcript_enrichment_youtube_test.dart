import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_enrichment_controller.dart';

const _lineOnly = [
  TranscriptLine(text: 'Hello world', startMs: 0, durationMs: 700),
];

void main() {
  test(
    'YouTube run never calls PCM helpers and persists untimed IPA',
    () async {
      List<TranscriptLine>? saved;
      final enricher = TranscriptEnricher(
        replaceTimeline: ({required transcriptId, required lines}) async {
          saved = lines;
          return true;
        },
        decodeFile: (path) async => fail('YouTube must not decode PCM'),
        decodeWindow:
            ({
              required pathOrUri,
              required startSeconds,
              required durationSeconds,
            }) async {
              fail('YouTube must not window-extract');
            },
        alignSegmentsFn:
            ({
              required sourcePcm16k,
              required language,
              required segments,
              required granularity,
              cancel,
            }) async {
              fail('YouTube must not alignSegments');
            },
        phonemizeFn: ({required texts, required language, cancel}) async {
          expect(language, 'en-US');
          return const PhonemizeSuccess([
            PhonemizeLineResult(
              words: [
                PhonemeWord(text: 'Hello', phones: ['h', 'ə']),
                PhonemeWord(text: 'world', phones: ['w']),
              ],
            ),
          ]);
        },
      );

      final outcome = await enricher.enrich(
        transcriptId: 't1',
        lines: _lineOnly,
        language: 'en',
        extractable: false,
        localPath: 'https://youtube.example/watch',
      );

      expect(outcome, isA<TranscriptEnrichmentOk>());
      expect(saved, isNotNull);
      expect(saved!.single.timeline, hasLength(2));
      expect(saved!.single.timeline!.first.startMs, isNull);
      expect(saved!.single.timeline!.first.durationMs, isNull);

      final readiness = transcriptDisplayReadiness(
        lines: saved!,
        canTrustWordTimes: false,
      );
      expect(readiness.karaokeSwitchEnabled, isFalse);
      expect(readiness.ipaSwitchEnabled, isTrue);
      expect(readiness.showEnrich, isFalse);
    },
  );

  test('YouTube phonemize strips subtitle markup before eSpeak', () async {
    late List<String> seen;
    final enricher = TranscriptEnricher(
      replaceTimeline: ({required transcriptId, required lines}) async => true,
      decodeFile: (path) async => fail('YouTube must not decode PCM'),
      decodeWindow:
          ({
            required pathOrUri,
            required startSeconds,
            required durationSeconds,
          }) async {
            fail('YouTube must not window-extract');
          },
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
            cancel,
          }) async {
            fail('YouTube must not alignSegments');
          },
      phonemizeFn: ({required texts, required language, cancel}) async {
        seen = texts;
        return const PhonemizeSuccess([
          PhonemizeLineResult(
            words: [
              PhonemeWord(text: 'Hello', phones: ['h']),
            ],
          ),
        ]);
      },
    );

    final outcome = await enricher.enrich(
      transcriptId: 't1',
      lines: const [
        TranscriptLine(text: '<font>Hello</font>', startMs: 0, durationMs: 700),
      ],
      language: 'en',
      extractable: false,
    );

    expect(outcome, isA<TranscriptEnrichmentOk>());
    expect(seen, ['Hello']);
  });
}
