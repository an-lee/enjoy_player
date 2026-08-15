import 'constants.dart';
import 'types.dart';

double _clamp(double value, double lo, double hi) {
  if (value < lo) return lo;
  if (value > hi) return hi;
  return value;
}

/// Clamp [entry] (and children) into `[startTime - pad, endTime + pad]`.
TimelineEntry clampTimelineToCueWindow(
  TimelineEntry entry, {
  required double startTime,
  required double endTime,
  double pad = kCuePadSeconds,
}) {
  final lo = startTime - pad;
  final hi = endTime + pad;
  final start = _clamp(entry.startTime, lo, hi);
  var end = _clamp(entry.endTime, lo, hi);
  if (end < start) end = start;
  final children = entry.timeline;
  return TimelineEntry(
    type: entry.type,
    text: entry.text,
    startTime: start,
    endTime: end,
    timeline: children
        ?.map(
          (child) => clampTimelineToCueWindow(
            child,
            startTime: startTime,
            endTime: endTime,
            pad: pad,
          ),
        )
        .toList(),
    confidence: entry.confidence,
    id: entry.id,
  );
}

/// Copy [id] onto a segment entry. Children keep their own ids.
TimelineEntry withSegmentId(TimelineEntry entry, Object? id) {
  if (id == null) return entry;
  return TimelineEntry(
    type: entry.type,
    text: entry.text,
    startTime: entry.startTime,
    endTime: entry.endTime,
    timeline: entry.timeline,
    confidence: entry.confidence,
    id: id,
  );
}
