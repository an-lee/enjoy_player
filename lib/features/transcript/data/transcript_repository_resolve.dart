part of 'transcript_repository.dart';

/// Open-time transcript resolution for [TranscriptRepository]: primary
/// assignment, sidecar import kickoff, cloud fetch kickoff, and
/// fetch-outcome persistence behind [TranscriptRepository.resolveOnOpen].
extension _TranscriptRepositoryResolve on TranscriptRepository {
  Future<TranscriptResolveResult> _resolveOnOpen(
    String mediaId, {
    bool forceCloud = false,
    bool fetchCloud = true,
    String? nativeLanguage,
    String? learningLanguage,
  }) async {
    final tt = await dexieTargetTypeForId(_db, mediaId);
    if (tt == null) {
      return const TranscriptResolveResult(hasTracks: false);
    }

    await _ensurePrimaryTranscript(mediaId, targetType: tt);
    try {
      await _importSidecarSubtitles(mediaId);
    } on Object catch (e, st) {
      _log.warning('sidecar subtitle import failed for $mediaId', e, st);
    }
    await _ensurePrimaryTranscript(mediaId, targetType: tt);

    TranscriptCloudFetchResult cloud = const TranscriptCloudFetchResult(
      status: TranscriptCloudFetchStatus.skipped,
    );
    if (fetchCloud) {
      cloud = await fetchCloudTranscripts(
        mediaId,
        force: forceCloud,
        nativeLanguage: nativeLanguage,
        learningLanguage: learningLanguage,
      );
      await _ensurePrimaryTranscript(mediaId, targetType: tt);
    }

    final hasTracks = (await _db.transcriptDao.listForTarget(
      tt,
      mediaId,
    )).isNotEmpty;
    final result = TranscriptResolveResult(
      hasTracks: hasTracks,
      cloud: cloud,
      errorMessage: cloud.status == TranscriptCloudFetchStatus.error
          ? cloud.errorMessage
          : null,
    );

    if (fetchCloud && cloud.status != TranscriptCloudFetchStatus.skipped) {
      await _persistFetchOutcome(tt, mediaId, result);
    }

    return result;
  }

  /// Internal step of [resolveOnOpen]: assigns the primary transcript when
  /// tracks exist but the session has none.
  ///
  /// When [targetType] is provided, skips the `dexieTargetTypeForId`
  /// lookup (issue #481 — avoids redundant queries when the caller
  /// already resolved the type).
  Future<bool> _ensurePrimaryTranscript(
    String mediaId, {
    String? targetType,
  }) async {
    final tt = targetType ?? await dexieTargetTypeForId(_db, mediaId);
    if (tt == null) return false;

    final session = await _db.echoSessionDao.getLatestForTarget(tt, mediaId);
    final rows = await _db.transcriptDao.listForTarget(tt, mediaId);
    _sortTranscriptRows(rows);
    if (rows.isEmpty) return false;

    final currentId = session?.transcriptId;
    if (currentId != null && rows.any((r) => r.id == currentId)) {
      return false;
    }

    await _db.echoSessionDao.updatePrimaryTranscriptForTarget(
      tt,
      mediaId,
      rows.first.id,
    );
    return true;
  }

  Future<void> _persistFetchOutcome(
    String targetType,
    String mediaId,
    TranscriptResolveResult result,
  ) async {
    final now = DateTime.now();
    final status = result.uiStatus;
    if (status == TranscriptFetchStatus.loading ||
        status == TranscriptFetchStatus.idle) {
      return;
    }

    await _db.transcriptFetchStateDao.upsertOutcome(
      targetType: targetType,
      targetId: mediaId,
      lastFetchedAt: now,
      lastStatus: TranscriptFetchUiState.toPersisted(status),
      lastError: result.errorMessage,
    );
  }
}
