/// Cooperative cancel for an in-flight alignment isolate.
final class AlignmentCancelToken {
  bool _cancelled = false;
  final List<void Function()> _hooks = [];

  bool get isCancelled => _cancelled;

  void onCancel(void Function() hook) {
    if (_cancelled) {
      hook();
      return;
    }
    _hooks.add(hook);
  }

  void cancel() {
    if (_cancelled) return;
    _cancelled = true;
    for (final hook in List<void Function()>.of(_hooks)) {
      hook();
    }
  }
}

/// One cue window for [alignSegments]. Times are seconds on the source PCM.
final class AlignmentSegment {
  const AlignmentSegment({
    required this.text,
    required this.startTime,
    required this.endTime,
    this.id,
  });

  final String text;
  final double startTime;
  final double endTime;
  final Object? id;
}
