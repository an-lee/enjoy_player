import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/subtitle/transcript_display_readiness.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_enrichment_controller.dart';

const _lineOnly = [
  TranscriptLine(text: 'Hello world', startMs: 0, durationMs: 700),
];

AlignmentSuccess _successFor(List<AlignmentSegment> segments) {
  return AlignmentSuccess(
    AlignmentResult(
      timeline: [
        for (final s in segments)
          TimelineEntry(
            type: TimelineEntryType.segment,
            text: s.text,
            startTime: s.startTime,
            endTime: s.endTime,
            id: s.id,
            timeline: [
              TimelineEntry(
                type: TimelineEntryType.word,
                text: s.text.split(' ').first,
                startTime: s.startTime,
                endTime: s.endTime,
                timeline: [
                  TimelineEntry(
                    type: TimelineEntryType.phone,
                    text: 'ə',
                    startTime: s.startTime,
                    endTime: s.endTime,
                  ),
                ],
              ),
            ],
          ),
      ],
      wordTimeline: const [],
      transcript: segments.map((s) => s.text).join(' '),
      language: 'en-US',
      durationSeconds: 2,
    ),
  );
}

Future<Float32List> _dummyPcm(String _) async =>
    Float32List(kAlignmentSampleRate);

void main() {
  test('owned success persists timed words and phones', () async {
    List<TranscriptLine>? saved;
    var pcmCalls = 0;
    final enricher = TranscriptEnricher(
      replaceTimeline: ({required transcriptId, required lines}) async {
        saved = lines;
        return true;
      },
      decodeFile: (path) async {
        pcmCalls++;
        expect(path, '/tmp/owned.wav');
        return _dummyPcm(path);
      },
      decodeWindow:
          ({
            required pathOrUri,
            required startSeconds,
            required durationSeconds,
          }) async {
            fail('short files must not window-extract');
          },
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
            cancel,
          }) async {
            expect(language, 'en-US');
            return _successFor(segments);
          },
      phonemizeFn: ({required texts, required language, cancel}) async {
        fail('owned path must not phonemize');
      },
    );

    final outcome = await enricher.enrich(
      transcriptId: 't1',
      lines: _lineOnly,
      language: 'en',
      extractable: true,
      localPath: '/tmp/owned.wav',
    );

    expect(outcome, isA<TranscriptEnrichmentOk>());
    expect(pcmCalls, 1);
    expect(saved, isNotNull);
    expect(saved!.single.text, 'Hello world');
    expect(saved!.single.startMs, 0);
    expect(saved!.single.durationMs, 700);
    expect(saved!.single.timeline, isNotNull);
    expect(saved!.single.timeline!.first.durationMs, greaterThan(0));
    expect(saved!.single.timeline!.first.phones, isNotNull);
  });

  test(
    'unsupported language / extract fail / cancel leave original JSON',
    () async {
      var replaceCalls = 0;
      Future<TranscriptEnrichmentOutcome> run({
        required String language,
        required bool extractable,
        String? path,
        AlignmentCancelToken? cancel,
        DecodeFilePcm16k? decodeFile,
      }) {
        return TranscriptEnricher(
          replaceTimeline: ({required transcriptId, required lines}) async {
            replaceCalls++;
            return true;
          },
          decodeFile: decodeFile ?? _dummyPcm,
          alignSegmentsFn:
              ({
                required sourcePcm16k,
                required language,
                required segments,
                required granularity,
                cancel,
              }) async {
                return _successFor(segments);
              },
          phonemizeFn: ({required texts, required language, cancel}) async {
            fail('should not phonemize');
          },
        ).enrich(
          transcriptId: 't1',
          lines: _lineOnly,
          language: language,
          extractable: extractable,
          localPath: path,
          cancel: cancel,
        );
      }

      expect(
        await run(language: 'xx', extractable: true, path: '/tmp/a.wav'),
        isA<TranscriptEnrichmentErr>(),
      );
      expect(
        await run(
          language: 'en-US',
          extractable: true,
          path: '/tmp/a.wav',
          decodeFile: (path) async => throw StateError('missing'),
        ),
        isA<TranscriptEnrichmentErr>(),
      );
      expect(
        await run(
          language: 'en-US',
          extractable: true,
          path: '/tmp/a.wav',
          cancel: AlignmentCancelToken()..cancel(),
        ),
        isA<TranscriptEnrichmentErr>(),
      );
      expect(replaceCalls, 0);
    },
  );

  test('controller build does not start work', () {
    var replaceCalls = 0;
    final container = ProviderContainer(
      overrides: [
        transcriptEnricherProvider.overrideWithValue(
          TranscriptEnricher(
            replaceTimeline: ({required transcriptId, required lines}) async {
              replaceCalls++;
              return true;
            },
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    expect(
      container.read(transcriptEnrichmentControllerProvider('m1')).phase,
      TranscriptEnrichmentPhase.idle,
    );
    expect(replaceCalls, 0);
  });

  test('partial long-file success keeps failed cues line-only', () async {
    List<TranscriptLine>? saved;
    final lines = [
      const TranscriptLine(text: 'Hello', startMs: 0, durationMs: 1000),
      const TranscriptLine(text: 'Later', startMs: 91000, durationMs: 1000),
    ];
    var windowCalls = 0;
    final enricher = TranscriptEnricher(
      replaceTimeline: ({required transcriptId, required lines}) async {
        saved = lines;
        return true;
      },
      decodeFile: (path) async => fail('long files must not decode whole clip'),
      decodeWindow:
          ({
            required pathOrUri,
            required startSeconds,
            required durationSeconds,
          }) async {
            windowCalls++;
            if (startSeconds > 10) throw StateError('window missing');
            return Float32List(kAlignmentSampleRate);
          },
      alignFn:
          ({
            required sourcePcm16k,
            required transcript,
            required language,
            cancel,
            required timeOffset,
          }) async {
            return AlignmentSuccess(
              AlignmentResult(
                timeline: [
                  TimelineEntry(
                    type: TimelineEntryType.segment,
                    text: transcript,
                    startTime: timeOffset,
                    endTime: timeOffset + 0.7,
                    timeline: [
                      TimelineEntry(
                        type: TimelineEntryType.word,
                        text: 'Hello',
                        startTime: timeOffset,
                        endTime: timeOffset + 0.7,
                        timeline: [
                          TimelineEntry(
                            type: TimelineEntryType.phone,
                            text: 'h',
                            startTime: timeOffset,
                            endTime: timeOffset + 0.7,
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
                wordTimeline: const [],
                transcript: transcript,
                language: language,
                durationSeconds: 1,
              ),
            );
          },
      phonemizeFn: ({required texts, required language, cancel}) async {
        fail('owned path must not phonemize');
      },
    );

    final outcome = await enricher.enrich(
      transcriptId: 't1',
      lines: lines,
      language: 'en-US',
      extractable: true,
      localPath: '/tmp/long.wav',
    );
    expect(outcome, isA<TranscriptEnrichmentOk>());
    expect(windowCalls, 2);
    expect(saved, hasLength(2));
    expect(saved!.first.timeline, isNotNull);
    expect(saved!.last.timeline, isNull);
    expect(saved!.last.text, 'Later');

    final readiness = transcriptDisplayReadiness(
      lines: saved!,
      canTrustWordTimes: true,
    );
    expect(readiness.hasNestedWords, isTrue);
    expect(readiness.showEnrich, isFalse);
  });

  test('owned HTTP URL downloads then aligns locally', () async {
    var decoded = '';
    var downloaded = '';
    final enricher = TranscriptEnricher(
      replaceTimeline: ({required transcriptId, required lines}) async => true,
      downloadHttp: (url, {cancel}) async {
        downloaded = url;
        return '/tmp/downloaded.mp3';
      },
      decodeFile: (path) async {
        decoded = path;
        return _dummyPcm(path);
      },
      decodeWindow:
          ({
            required pathOrUri,
            required startSeconds,
            required durationSeconds,
          }) async {
            fail('short files must not window-extract');
          },
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
            cancel,
          }) async {
            return _successFor(segments);
          },
      phonemizeFn: ({required texts, required language, cancel}) async {
        fail('owned remote URL must not phonemize');
      },
    );

    final outcome = await enricher.enrich(
      transcriptId: 't1',
      lines: _lineOnly,
      language: 'en',
      extractable: true,
      localPath: 'https://cdn.example/owned.mp3',
    );

    expect(outcome, isA<TranscriptEnrichmentOk>());
    expect(downloaded, 'https://cdn.example/owned.mp3');
    expect(decoded, '/tmp/downloaded.mp3');
  });

  test('window path reports cue progress including failed cues', () async {
    final progress = <(int, int)>[];
    final lines = [
      const TranscriptLine(text: 'Hello', startMs: 0, durationMs: 1000),
      const TranscriptLine(text: 'Later', startMs: 91000, durationMs: 1000),
    ];
    final enricher = TranscriptEnricher(
      replaceTimeline: ({required transcriptId, required lines}) async => true,
      decodeFile: (path) async => fail('long files must not decode whole clip'),
      decodeWindow:
          ({
            required pathOrUri,
            required startSeconds,
            required durationSeconds,
          }) async {
            if (startSeconds > 10) throw StateError('window missing');
            return Float32List(kAlignmentSampleRate);
          },
      alignFn:
          ({
            required sourcePcm16k,
            required transcript,
            required language,
            cancel,
            required timeOffset,
          }) async {
            return AlignmentSuccess(
              AlignmentResult(
                timeline: [
                  TimelineEntry(
                    type: TimelineEntryType.segment,
                    text: transcript,
                    startTime: timeOffset,
                    endTime: timeOffset + 0.7,
                    timeline: [
                      TimelineEntry(
                        type: TimelineEntryType.word,
                        text: 'Hello',
                        startTime: timeOffset,
                        endTime: timeOffset + 0.7,
                      ),
                    ],
                  ),
                ],
                wordTimeline: const [],
                transcript: transcript,
                language: language,
                durationSeconds: 1,
              ),
            );
          },
      phonemizeFn: ({required texts, required language, cancel}) async {
        fail('owned path must not phonemize');
      },
    );

    await enricher.enrich(
      transcriptId: 't1',
      lines: lines,
      language: 'en-US',
      extractable: true,
      localPath: '/tmp/long.wav',
      onProgress: ({required completed, required total}) {
        progress.add((completed, total));
      },
    );

    expect(progress.first, (0, 2));
    expect(progress, contains((1, 2)));
    expect(progress.last, (2, 2));
  });
}
