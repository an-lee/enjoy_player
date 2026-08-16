import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/audio/pcm16k_mono.dart';
import 'package:enjoy_player/features/craft/application/craft_timeline_enricher.dart';

const _lineOnlyJson = '[{"text":"Hello world.","start":0,"duration":700}]';

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

Future<Float32List> _dummyPcm(Uint8List _) async =>
    Float32List(kAlignmentSampleRate);

void main() {
  test(
    'alignmentLanguageForCraft expands primary tags without swapping families',
    () {
      expect(alignmentLanguageForCraft('en'), 'en-US');
      expect(alignmentLanguageForCraft('en-US'), 'en-US');
      expect(alignmentLanguageForCraft('en-GB'), 'en-GB');
      expect(alignmentLanguageForCraft('ja'), 'ja-JP');
      expect(alignmentLanguageForCraft('xx'), isNull);
      expect(alignmentLanguageForCraft(''), isNull);
    },
  );

  final audio = Uint8List.fromList(const [1, 2, 3, 4]);

  test('setting off returns spec 030 JSON unchanged', () async {
    var aligned = false;
    final enricher = CraftTimelineEnricher(
      enabled: false,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async {
            aligned = true;
            return _successFor(segments);
          },
    );
    final out = await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'en-US',
    );
    expect(out, _lineOnlyJson);
    expect(aligned, isFalse);
  });

  test('blank 030 JSON stays null and does not invent lines', () async {
    var aligned = false;
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async {
            aligned = true;
            return _successFor(segments);
          },
    );
    final out = await enricher.enrich(
      timelineJson: null,
      audioBytes: audio,
      language: 'en-US',
    );
    expect(out, isNull);
    expect(aligned, isFalse);
  });

  test('setting on attaches nested timeline and phones', () async {
    AlignmentGranularity? seenGranularity;
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async {
            seenGranularity = granularity;
            expect(segments, hasLength(1));
            expect(segments.single.id, 0);
            return _successFor(segments);
          },
    );
    final out = await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'en-US',
    );
    expect(seenGranularity, AlignmentGranularity.medium);
    final decoded = jsonDecode(out!) as List;
    expect(decoded.single['text'], 'Hello world.');
    expect(decoded.single['start'], 0);
    expect(decoded.single['duration'], 700);
    final words = decoded.single['timeline'] as List;
    expect(words, isNotEmpty);
    expect(words.first['phones'], isNotEmpty);
  });

  test('spokenReferenceUnavailable falls back to original JSON', () async {
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async => const AlignmentFailed(
            AlignmentFailure(
              reason: AlignmentFailureReason.spokenReferenceUnavailable,
            ),
          ),
    );
    final out = await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'en-US',
    );
    expect(out, _lineOnlyJson);
  });

  test('unsupportedLanguage falls back to original JSON', () async {
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async => const AlignmentFailed(
            AlignmentFailure(
              reason: AlignmentFailureReason.unsupportedLanguage,
            ),
          ),
    );
    final out = await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'xx-YY',
    );
    expect(out, _lineOnlyJson);
  });

  test('PCM extract throw falls back to original JSON', () async {
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: (_) async =>
          throw const Pcm16kDecodeException('extract failed'),
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async => _successFor(segments),
    );
    final out = await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'en-US',
    );
    expect(out, _lineOnlyJson);
  });

  test('timeout falls back to original JSON', () async {
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async => const AlignmentFailed(
            AlignmentFailure(reason: AlignmentFailureReason.timedOut),
          ),
    );
    final out = await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'en-US',
    );
    expect(out, _lineOnlyJson);
  });

  test('partial cue success nests only winning lines', () async {
    const twoLines =
        '[{"text":"Hello","start":0,"duration":1000},'
        '{"text":"World","start":1200,"duration":800}]';
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async => _successFor([segments.first]),
    );
    final out = await enricher.enrich(
      timelineJson: twoLines,
      audioBytes: audio,
      language: 'en-US',
    );
    final decoded = jsonDecode(out!) as List;
    expect(decoded, hasLength(2));
    expect(decoded[0]['text'], 'Hello');
    expect(decoded[0]['timeline'], isNotEmpty);
    expect(decoded[1]['text'], 'World');
    expect(decoded[1]['start'], 1200);
    expect(decoded[1]['duration'], 800);
    expect(decoded[1].containsKey('timeline'), isFalse);
  });

  test('maps Craft primary tag en to en-US', () async {
    String? seenLanguage;
    final enricher = CraftTimelineEnricher(
      enabled: true,
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async {
            seenLanguage = language;
            return _successFor(segments);
          },
    );
    await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'en',
    );
    expect(seenLanguage, 'en-US');
  });

  test(
    'keeps en-GB and does not call align for an unmapped language',
    () async {
      String? seenLanguage;
      final gb = CraftTimelineEnricher(
        enabled: true,
        decodePcm: _dummyPcm,
        alignSegmentsFn:
            ({
              required sourcePcm16k,
              required language,
              required segments,
              required granularity,
            }) async {
              seenLanguage = language;
              return _successFor(segments);
            },
      );
      await gb.enrich(
        timelineJson: _lineOnlyJson,
        audioBytes: audio,
        language: 'en-GB',
      );
      expect(seenLanguage, 'en-GB');

      var aligned = false;
      final unknown = CraftTimelineEnricher(
        enabled: true,
        decodePcm: _dummyPcm,
        alignSegmentsFn:
            ({
              required sourcePcm16k,
              required language,
              required segments,
              required granularity,
            }) async {
              aligned = true;
              return _successFor(segments);
            },
      );
      final out = await unknown.enrich(
        timelineJson: _lineOnlyJson,
        audioBytes: audio,
        language: 'xx',
      );
      expect(out, _lineOnlyJson);
      expect(aligned, isFalse);
    },
  );

  test('awaits resolveEnabled instead of treating loading as off', () async {
    var aligned = false;
    final enricher = CraftTimelineEnricher(
      enabled: false,
      resolveEnabled: () async {
        await Future<void>.delayed(Duration.zero);
        return true;
      },
      decodePcm: _dummyPcm,
      alignSegmentsFn:
          ({
            required sourcePcm16k,
            required language,
            required segments,
            required granularity,
          }) async {
            aligned = true;
            return _successFor(segments);
          },
    );
    final out = await enricher.enrich(
      timelineJson: _lineOnlyJson,
      audioBytes: audio,
      language: 'en',
    );
    expect(aligned, isTrue);
    final decoded = jsonDecode(out!) as List;
    expect(decoded.single['timeline'], isNotEmpty);
  });
}
