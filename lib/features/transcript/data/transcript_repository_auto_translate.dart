part of 'transcript_repository.dart';

/// Auto-translate AI-track management for [TranscriptRepository]: durable
/// skeleton creation keyed to the primary transcript, per-line translated
/// text writes, and staleness detection against the current primary.
extension _TranscriptRepositoryAutoTranslate on TranscriptRepository {
  Future<String?> _ensureAutoTranslateTrack({
    required String mediaId,
    required String primaryTranscriptId,
    required String targetLanguage,
    required List<TranscriptLine> primaryLines,
  }) async {
    final tt = await dexieTargetTypeForId(_db, mediaId);
    if (tt == null || primaryLines.isEmpty) return null;

    final id = autoTranslateAiTrackId(
      targetType: tt,
      mediaId: mediaId,
      targetLanguage: targetLanguage,
    );
    final existing = await _db.transcriptDao.getById(id);
    if (existing != null &&
        !isAutoTranslateTrackStale(
          aiRow: existing,
          primaryId: primaryTranscriptId,
          primaryLines: primaryLines,
        )) {
      return id;
    }

    final skeleton = buildAutoTranslateSkeleton(primaryLines);
    final json = jsonEncode(skeleton.map((e) => e.toJson()).toList());
    final now = DateTime.now();

    await _db.transcriptDao.upsert(
      TranscriptRow(
        id: id,
        targetType: tt,
        targetId: mediaId,
        language: targetLanguage,
        source: 'ai',
        timelineJson: json,
        referenceId: primaryTranscriptId,
        label: existing?.label.isNotEmpty == true
            ? existing!.label
            : 'Auto translate ($targetLanguage)',
        trackIndex: null,
        syncStatus: 'local',
        serverUpdatedAt: null,
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      ),
    );
    _linesCache.remove(id);
    return id;
  }

  Future<void> _updateAutoTranslateLineText({
    required String aiTranscriptId,
    required int lineIndex,
    required String text,
    String? sourceKey,
  }) async {
    final row = await _db.transcriptDao.getById(aiTranscriptId);
    if (row == null) return;
    final lines = List<TranscriptLine>.from(linesForRow(row));
    if (lineIndex < 0 || lineIndex >= lines.length) return;
    lines[lineIndex] = TranscriptLine(
      text: text,
      startMs: lines[lineIndex].startMs,
      durationMs: lines[lineIndex].durationMs,
      sourceKey: text.trim().isEmpty ? null : sourceKey,
    );
    final now = DateTime.now();
    await _db.transcriptDao.upsert(
      row.copyWith(
        timelineJson: jsonEncode(lines.map((e) => e.toJson()).toList()),
        updatedAt: now,
      ),
    );
    _linesCache.remove(aiTranscriptId);
  }

  bool _isAutoTranslateTrackStale({
    required TranscriptRow aiRow,
    required String primaryId,
    required List<TranscriptLine> primaryLines,
  }) {
    final aiLines = linesForRow(aiRow);
    return isAutoTranslateTimelineStale(
      referencePrimaryId: aiRow.referenceId,
      primaryId: primaryId,
      primaryLines: primaryLines,
      aiLines: aiLines,
    );
  }
}
