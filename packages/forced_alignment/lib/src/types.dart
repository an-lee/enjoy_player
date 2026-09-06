/// Echogarden-shaped timeline node (`segment` / `sentence` / `word` / `token` / `phone`).
enum TimelineEntryType { segment, sentence, word, token, phone }

/// Quality / cost knob. Default product quality is [medium] (words + phones).

/// Recursive engine timeline entry. Times are seconds on the **source** audio.
final class TimelineEntry {
  const TimelineEntry({
    required this.type,
    required this.text,
    required this.startTime,
    required this.endTime,
    this.timeline,
    this.confidence,
    this.id,
  });

  final TimelineEntryType type;
  final String text;
  final double startTime;
  final double endTime;
  final List<TimelineEntry>? timeline;
  final double? confidence;

  /// Caller cue id from [AlignmentSegment.id], echoed on successful segments.
  final Object? id;

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is TimelineEntry &&
        other.type == type &&
        other.text == text &&
        other.startTime == startTime &&
        other.endTime == endTime &&
        other.confidence == confidence &&
        other.id == id &&
        _listEquals(other.timeline, timeline);
  }

  @override
  int get hashCode => Object.hash(
    type,
    text,
    startTime,
    endTime,
    confidence,
    id,
    Object.hashAll(timeline ?? const []),
  );
}

/// Successful alignment. Failures never use this type.
final class AlignmentResult {
  const AlignmentResult({
    required this.timeline,
    required this.wordTimeline,
    required this.transcript,
    required this.language,
    required this.durationSeconds,
  });

  final List<TimelineEntry> timeline;
  final List<TimelineEntry> wordTimeline;
  final String transcript;
  final String language;
  final double durationSeconds;
}

bool _listEquals(List<TimelineEntry>? a, List<TimelineEntry>? b) {
  if (identical(a, b)) return true;
  if (a == null || b == null) return a == b;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
