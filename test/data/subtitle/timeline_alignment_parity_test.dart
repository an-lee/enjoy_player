/// Issue #540 §12 interface-parity contract, adapted to the shipped shape.
///
/// The engine emits an Echogarden-shaped recursive `AlignmentResult`
/// (`segment → word → phone`, `type`/`text`/`startTime`/`endTime`/`timeline`,
/// seconds). Persistence uses the enjoy-web cue contract
/// (`timeline[].text/start/duration` ms relative to the line,
/// `phones[].phone/text/startTime/endTime/wordIndex`, seconds).
/// This fixture test pins the exact JSON keys and nesting of the adapter
/// boundary so neither side can drift silently.
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';

import 'package:enjoy_player/data/subtitle/attach_alignment_to_lines.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';

/// Echogarden-shaped fixture: one segment with two words, phones on word 0.
AlignmentResult _echogardenShapedFixture() {
  const hello = TimelineEntry(
    type: TimelineEntryType.word,
    text: 'Hello',
    startTime: 0.10,
    endTime: 0.60,
    timeline: [
      TimelineEntry(
        type: TimelineEntryType.phone,
        text: 'h',
        startTime: 0.10,
        endTime: 0.20,
      ),
      TimelineEntry(
        type: TimelineEntryType.phone,
        text: 'ə',
        startTime: 0.20,
        endTime: 0.45,
      ),
      TimelineEntry(
        type: TimelineEntryType.phone,
        text: 'oʊ',
        startTime: 0.45,
        endTime: 0.60,
      ),
    ],
  );
  const world = TimelineEntry(
    type: TimelineEntryType.word,
    text: 'world',
    startTime: 0.70,
    endTime: 1.00,
  );
  return const AlignmentResult(
    timeline: [
      TimelineEntry(
        type: TimelineEntryType.segment,
        text: 'Hello world',
        startTime: 0,
        endTime: 1.0,
        id: 0,
        timeline: [hello, world],
      ),
    ],
    wordTimeline: [hello, world],
    transcript: 'Hello world',
    language: 'en-US',
    durationSeconds: 1.0,
  );
}

void main() {
  test('engine timeline maps to the exact enjoy-web cue JSON contract', () {
    const line = TranscriptLine(
      text: 'Hello world',
      startMs: 0,
      durationMs: 1000,
    );
    final attached = attachAlignmentToLines([line], _echogardenShapedFixture());
    expect(attached.single.toJson(), {
      'text': 'Hello world',
      'start': 0,
      'duration': 1000,
      'timeline': [
        {
          'text': 'Hello',
          'start': 100,
          'duration': 500,
          'phones': [
            {
              'phone': 'h',
              'text': 'h',
              'startTime': 0.10,
              'endTime': 0.20,
              'wordIndex': 0,
            },
            {
              'phone': 'ə',
              'text': 'ə',
              'startTime': 0.20,
              'endTime': 0.45,
              'wordIndex': 0,
            },
            {
              'phone': 'oʊ',
              'text': 'oʊ',
              'startTime': 0.45,
              'endTime': 0.60,
              'wordIndex': 0,
            },
          ],
        },
        {'text': 'world', 'start': 700, 'duration': 300},
      ],
    });
  });

  test('contract JSON round-trips through the opaque timeline column', () {
    const line = TranscriptLine(
      text: 'Hello world',
      startMs: 0,
      durationMs: 1250,
    );
    final attached = attachAlignmentToLines([
      line,
    ], _echogardenShapedFixture()).single;
    final encoded = jsonEncode(attached.toJson());
    final decoded = TranscriptLine.fromJson(
      jsonDecode(encoded) as Map<String, dynamic>,
    );
    expect(decoded, attached);
    // Word clocks stay line-relative ms; phone clocks stay media seconds.
    expect(decoded.timeline![0].startMs, 100);
    expect(decoded.timeline![0].phones![2].endTime, closeTo(0.60, 1e-9));
  });

  test('line identity fields never change across the adapter', () {
    const line = TranscriptLine(
      text: 'Hello world',
      startMs: 0,
      durationMs: 1000,
      sourceKey: 'src-1',
      confidence: 0.9,
    );
    final attached = attachAlignmentToLines([
      line,
    ], _echogardenShapedFixture()).single;
    expect(attached.text, line.text);
    expect(attached.startMs, line.startMs);
    expect(attached.durationMs, line.durationMs);
    expect(attached.sourceKey, line.sourceKey);
    expect(attached.confidence, line.confidence);
  });
}
