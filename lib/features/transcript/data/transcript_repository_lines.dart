part of 'transcript_repository.dart';

/// Decoded-timeline cache and reactive watches for [TranscriptRepository]:
/// memoized `timelineJson` decoding (with isolate pre-decode for large
/// payloads), Drift watch glue for the active primary / secondary lines, and
/// the sorted track list stream.
extension _TranscriptRepositoryLines on TranscriptRepository {
  List<TranscriptLine> _linesForRow(TranscriptRow row) {
    final hash = _timelineJsonHash(row.timelineJson);
    final hit = _linesCache[row.id];
    if (hit != null && hit.hash == hash) return hit.lines;
    final decoded = _decodeTimeline(row.timelineJson);
    _linesCache[row.id] = _LinesCacheEntry(hash, decoded);
    return decoded;
  }

  /// Pre-decodes [row.timelineJson] in a background isolate and caches the
  /// result when the payload is large enough ([_kPreloadTimelineJsonBytes])
  /// to justify leaving the UI isolate.
  Future<void> _preloadLinesForRow(TranscriptRow row) async {
    final hash = _timelineJsonHash(row.timelineJson);
    final hit = _linesCache[row.id];
    if (hit != null && hit.hash == hash) return;
    if (row.timelineJson.length <= _kPreloadTimelineJsonBytes) return;
    final decoded = await compute(_decodeTimeline, row.timelineJson);
    _linesCache[row.id] = _LinesCacheEntry(hash, decoded);
  }

  Stream<List<TranscriptLine>> _watchLines(
    String mediaId, {
    required bool primary,
  }) {
    return Stream.fromFuture(dexieTargetTypeForId(_db, mediaId)).asyncExpand((
      tt,
    ) {
      if (tt == null) {
        return Stream.value(<TranscriptLine>[]);
      }
      return Stream.fromFuture(
        _computeActiveLines(tt, mediaId, primary: primary),
      ).asyncExpand((initial) async* {
        yield initial;
        yield* StreamGroup.merge([
          _db.echoSessionDao
              .watchLatestForTarget(tt, mediaId)
              .asyncMap(
                (_) => _computeActiveLines(tt, mediaId, primary: primary),
              ),
          _db.transcriptDao
              .watchAllForTarget(tt, mediaId)
              .asyncMap(
                (_) => _computeActiveLines(tt, mediaId, primary: primary),
              ),
        ]).distinctBy(listEquals);
      });
    });
  }

  Future<List<TranscriptLine>> _computeActiveLines(
    String tt,
    String mediaId, {
    required bool primary,
  }) async {
    final echo = await _db.echoSessionDao.getLatestForTarget(tt, mediaId);
    final id = primary ? echo?.transcriptId : echo?.secondaryTranscriptId;
    if (id == null) return <TranscriptLine>[];
    // Fetch only the active row, not the entire transcript list. Avoids
    // reading every transcript's timeline_json blob on every Drift tick —
    // a frequent no-op tick when an in-active transcript row changes or
    // when echo session aggregates (recordingsCount, lastActiveAt, …) bump.
    final row = await _db.transcriptDao.getById(id);
    if (row == null) return <TranscriptLine>[];
    await _preloadLinesForRow(row);
    return linesForRow(row);
  }

  Future<TranscriptRow?> _primaryTranscriptRowForMedia(String mediaId) async {
    final tt = await dexieTargetTypeForId(_db, mediaId);
    if (tt == null) return null;
    final echo = await _db.echoSessionDao.getLatestForTarget(tt, mediaId);
    final id = echo?.transcriptId;
    if (id == null) return null;
    return _db.transcriptDao.getById(id);
  }

  Stream<List<TranscriptTrack>> _watchTracks(String mediaId) =>
      Stream.fromFuture(dexieTargetTypeForId(_db, mediaId)).asyncExpand((tt) {
        if (tt == null) {
          return Stream.value(<TranscriptTrack>[]);
        }
        return _db.transcriptDao
            .watchAllForTarget(tt, mediaId)
            .map((rows) {
              final sorted = [...rows];
              _sortTranscriptRows(sorted);
              return sorted.map(_trackFromRow).toList();
            })
            .distinctBy(listEquals);
      });
}
