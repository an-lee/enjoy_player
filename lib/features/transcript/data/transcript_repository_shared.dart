part of 'transcript_repository.dart';

/// Module-private helpers shared by the [TranscriptRepository] part files:
/// content-hash cache keying, timeline decoding, track-row mapping, source
/// normalization / ordering, and robust server date parsing.

class _LinesCacheEntry {
  _LinesCacheEntry(this.hash, this.lines);
  final String hash;
  final List<TranscriptLine> lines;
}

String _timelineJsonHash(String timelineJson) =>
    sha1.convert(utf8.encode(timelineJson)).toString().substring(0, 16);

/// Timelines larger than this are decoded in a background isolate before
/// [TranscriptRepository.linesForRow] serves them synchronously.
const int _kPreloadTimelineJsonBytes = 16 * 1024;

List<TranscriptLine> _decodeTimeline(String timelineJson) {
  final decoded = (jsonDecode(timelineJson) as List)
      .cast<Map<String, dynamic>>();
  return decoded.map(TranscriptLine.fromJson).toList();
}

TranscriptTrack _trackFromRow(TranscriptRow row) {
  return TranscriptTrack(
    id: row.id,
    targetType: row.targetType,
    targetId: row.targetId,
    language: row.language,
    source: row.source,
    label: row.label,
    trackIndex: row.trackIndex,
  );
}

int _sourcePriority(String source) {
  switch (source) {
    case 'official':
      return 0;
    case 'auto':
      return 1;
    case 'ai':
      return 2;
    case 'user':
      return 3;
    default:
      return 4;
  }
}

void _sortTranscriptRows(List<TranscriptRow> rows) {
  rows.sort((a, b) {
    final pa = _sourcePriority(a.source);
    final pb = _sourcePriority(b.source);
    if (pa != pb) return pa.compareTo(pb);
    return a.createdAt.compareTo(b.createdAt);
  });
}

String _normalizeSource(String raw) {
  switch (raw) {
    case 'official':
    case 'auto':
    case 'ai':
    case 'user':
      return raw;
    default:
      return 'official';
  }
}

DateTime _parseServerDate(dynamic v, DateTime fallback) {
  if (v is String) {
    return DateTime.tryParse(v) ?? fallback;
  }
  return fallback;
}

final Logger _log = logNamed('TranscriptRepository');
