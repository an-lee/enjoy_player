import 'package:flutter_test/flutter_test.dart';
import 'package:forced_alignment/forced_alignment.dart';
import 'package:forced_alignment/src/cue_window.dart';

void main() {
  test('clamps word times into the cue window plus 50 ms pad', () {
    const drifted = TimelineEntry(
      type: TimelineEntryType.word,
      text: 'hello',
      startTime: -0.2,
      endTime: 2.4,
      timeline: [
        TimelineEntry(
          type: TimelineEntryType.phone,
          text: 'h',
          startTime: -0.3,
          endTime: 2.5,
        ),
      ],
    );
    final clamped = clampTimelineToCueWindow(drifted, startTime: 0, endTime: 2);
    expect(clamped.startTime, closeTo(-kCuePadSeconds, 1e-9));
    expect(clamped.endTime, closeTo(2 + kCuePadSeconds, 1e-9));
    expect(clamped.timeline!.single.startTime, closeTo(-kCuePadSeconds, 1e-9));
    expect(clamped.timeline!.single.endTime, closeTo(2 + kCuePadSeconds, 1e-9));
  });

  test('withSegmentId copies id onto the segment only', () {
    const entry = TimelineEntry(
      type: TimelineEntryType.segment,
      text: 'hello',
      startTime: 0,
      endTime: 2,
      timeline: [
        TimelineEntry(
          type: TimelineEntryType.word,
          text: 'hello',
          startTime: 0,
          endTime: 2,
        ),
      ],
    );
    final tagged = withSegmentId(entry, 7);
    expect(tagged.id, 7);
    expect(tagged.timeline!.single.id, isNull);
  });
}
