part of 'transcript_repository.dart';

/// External subtitle sources for [TranscriptRepository]: adjacent sidecar
/// `.srt` / `.vtt` discovery for local files, user-supplied subtitle import,
/// and embedded-stream extraction via ffmpeg.
extension _TranscriptRepositorySubtitleImport on TranscriptRepository {
  /// Internal step of [resolveOnOpen]: imports matching sidecar subtitle
  /// files next to a local media file.
  ///
  /// Returns the number of newly imported sidecar files.
  Future<int> _importSidecarSubtitles(String mediaId) async {
    final uri = await resolvePlayableSourceUri(_db, mediaId);
    if (uri == null) return 0;

    final tt = await dexieTargetTypeForId(_db, mediaId);
    if (tt == null) return 0;

    final sidecars = discoverSidecarSubtitleFiles(uri);
    if (sidecars.isEmpty) return 0;

    var imported = 0;
    for (final file in sidecars) {
      final name = p.basename(file.path);
      final language = languageHintFromSubtitleFileName(name);
      const source = 'user';
      final id = enjoyTranscriptId(
        targetType: tt,
        targetId: mediaId,
        language: language,
        source: source,
      );
      if (await _db.transcriptDao.getById(id) != null) continue;

      await importSubtitle(
        mediaId: mediaId,
        file: XFile(file.path, name: name),
        language: language,
        label: p.basenameWithoutExtension(name),
      );
      imported++;
    }
    return imported;
  }

  Future<void> _importSubtitle({
    required String mediaId,
    required XFile file,
    required String language,
    String? label,
  }) async {
    final tt = await dexieTargetTypeForId(_db, mediaId);
    if (tt == null) return;
    final text = await file.readAsString();
    final lines = const SubtitleParserFacade().parseWithHint(
      text,
      fileName: file.name,
    );
    final json = jsonEncode(lines.map((e) => e.toJson()).toList());
    const source = 'user';
    final id = enjoyTranscriptId(
      targetType: tt,
      targetId: mediaId,
      language: language,
      source: source,
    );
    final now = DateTime.now();
    await _db.transcriptDao.upsert(
      TranscriptRow(
        id: id,
        targetType: tt,
        targetId: mediaId,
        language: language,
        source: source,
        timelineJson: json,
        referenceId: null,
        label: label ?? p.basenameWithoutExtension(file.name),
        trackIndex: null,
        syncStatus: 'local',
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      ),
    );
    final session = await _db.echoSessionDao.getLatestForTarget(tt, mediaId);
    if (session?.transcriptId == null) {
      await _db.echoSessionDao.updatePrimaryTranscriptForTarget(
        tt,
        mediaId,
        id,
      );
    }
  }

  Future<int> _extractEmbeddedTracks({
    required String mediaId,
    required String sourceUri,
    List<mk.SubtitleTrack> playerSubtitleTracks = const [],
  }) async {
    final tt = await dexieTargetTypeForId(_db, mediaId);
    if (tt == null) return 0;

    final existing = await _db.transcriptDao.listForTarget(tt, mediaId);
    final existingIndices = existing
        .where((r) => r.trackIndex != null)
        .map((r) => r.trackIndex!)
        .toSet();

    final extracted = await const EmbeddedSubtitleService().extractTracks(
      targetId: mediaId,
      targetTypeDexie: tt,
      mediaSourceUri: sourceUri,
      tracks: playerSubtitleTracks,
      existingTrackIndices: existingIndices,
    );

    if (extracted.isEmpty) return 0;

    for (final row in extracted) {
      await _db.transcriptDao.upsert(row);
    }

    final session = await _db.echoSessionDao.getLatestForTarget(tt, mediaId);
    if (session?.transcriptId == null) {
      await _db.echoSessionDao.updatePrimaryTranscriptForTarget(
        tt,
        mediaId,
        extracted.first.id,
      );
    }

    return extracted.length;
  }
}
