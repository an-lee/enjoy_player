part of 'transcript_repository.dart';

/// YouTube transcript fetching for [TranscriptRepository]: the three-tier
/// fallback chain (worker cache → direct InnerTube fetch), worker id /
/// caption-language resolution, and the post-fetch primary picker.
extension _TranscriptRepositoryYoutubeFetch on TranscriptRepository {
  /// Worker body `video_id` / `videoId`: prefer [VideoRow.vid] when it is an
  /// 11-character YouTube id; otherwise fall back to [youtubePlaybackVideoId].
  String _workerYoutubeVideoId(VideoRow video) {
    final v = video.vid.trim();
    if (_youtubeWorkerVideoIdRe.hasMatch(v)) return v;
    final pb = youtubePlaybackVideoId(
      provider: video.provider,
      vid: video.vid,
      mediaUrl: video.mediaUrl,
      source: video.source,
    );
    return pb ?? v;
  }

  String? _workerCaptionLanguage(VideoRow video) {
    final lang = video.language.trim();
    if (kInvalidLanguageTags.contains(lang)) return null;
    return workerLanguageBase(lang);
  }

  /// Three-tier fallback chain for YouTube transcript fetching.
  ///
  /// Tier 1: Worker GET cache (skipped when [force] is true; also skipped
  /// when the video row has no usable content language).
  /// Tier 2: Client-side direct YouTube fetch (bypasses worker).
  /// Every direct fetch uploads all tracks to the worker for caching.
  ///
  /// Tier 2 always runs when the row resolves to YouTube playback, even
  /// when `videos.language` is empty / `und` / unknown — the InnerTube
  /// fetch itself discovers every available language. The unknown
  /// language only narrows the Tier 1 lookup and the `preferredLang`
  /// hint handed to the fetcher.
  ///
  /// Every branch logs its outcome (at INFO or WARNING) so the chain is
  /// observable in production. Without these logs a Windows → worker → Android
  /// failure mode looks like a true no-op: no server-side upload log, no
  /// client-side failure, no UI signal.
  Future<TranscriptCloudFetchResult> _fetchYoutubeTranscriptsWithFallback({
    required String mediaId,
    required VideoRow video,
    required bool force,
    String? learningLanguage,
  }) async {
    final workerVideoId = _workerYoutubeVideoId(video);
    final videoLanguage = video.language.trim();
    final workerLanguage = _workerCaptionLanguage(video);

    // Tier 1: Worker GET cache (skip when forcing a refresh OR when the
    // video has no usable content language to query with). A missing
    // worker language is *not* a reason to abort the chain — Tier 2 will
    // still run and discover every available caption language.
    if (!force && workerLanguage != null) {
      _log.info(
        'YouTube Tier 1 (worker cache) GET '
        '$workerVideoId/$workerLanguage',
      );
      final cached = await _fetchWorkerCachedTranscript(
        videoId: workerVideoId,
        language: workerLanguage,
      );
      if (cached != null) {
        final result = await _upsertWorkerCachedTranscript(
          mediaId: mediaId,
          response: cached,
          fallbackNow: DateTime.now(),
        );
        if (result) {
          _log.info(
            'YouTube Tier 1 hit for $workerVideoId/$workerLanguage — '
            'using cached transcript (skipping InnerTube)',
          );
          await _pickYoutubePrimary(
            mediaId: mediaId,
            videoLanguage: videoLanguage.isEmpty ? null : videoLanguage,
            learningLanguage: learningLanguage,
          );
          return const TranscriptCloudFetchResult(
            status: TranscriptCloudFetchStatus.success,
            storedCount: 1,
          );
        }
        _log.info(
          'YouTube Tier 1 returned a body but stored 0 lines for '
          '$workerVideoId/$workerLanguage — falling through to InnerTube',
        );
      } else {
        _log.info(
          'YouTube Tier 1 miss for $workerVideoId/$workerLanguage — '
          'falling through to direct InnerTube fetch',
        );
      }
    } else if (workerLanguage == null) {
      _log.info(
        'YouTube Tier 1 skipped for $workerVideoId — '
        'videos.language is empty/"und" (Tier 2 will still discover)',
      );
    }

    // Tier 2: Client-side direct YouTube fetch — download all tracks.
    final fetcher = _youtubeFetcher;
    if (fetcher == null) {
      _log.warning(
        'YouTube Tier 2 unavailable: YoutubeCaptionFetcher is not wired',
      );
      return const TranscriptCloudFetchResult(
        status: TranscriptCloudFetchStatus.skipped,
      );
    }

    // InnerTube always discovers every language. When `videos.language`
    // is unknown we pass an empty preferredLang so no track is artificially
    // ranked first and every available language is still returned.
    final preferredLang = workerLanguage ?? '';
    final allResult = await fetcher.fetchAllSubtitles(
      videoId: workerVideoId,
      preferredLang: preferredLang,
    );

    if (!allResult.isSuccess) {
      _log.warning(
        'YouTube Tier 2 (direct InnerTube) failed for '
        '$workerVideoId/$preferredLang: ${allResult.error}',
      );
      return TranscriptCloudFetchResult(
        status: TranscriptCloudFetchStatus.error,
        errorMessage: allResult.error ?? 'No captions available',
      );
    }

    final now = DateTime.now();
    var storedCount = 0;

    for (final trackResult in allResult.results) {
      if (!trackResult.isSuccess || trackResult.subtitles.isEmpty) continue;
      if (trackResult.language.isEmpty) continue;

      final source = _normalizeSource(trackResult.source);
      final id = enjoyTranscriptId(
        targetType: 'Video',
        targetId: mediaId,
        language: trackResult.language,
        source: source,
      );
      final timelineJson = jsonEncode(
        trackResult.subtitles.map((e) => e.toJson()).toList(),
      );

      await _db.transcriptDao.upsert(
        TranscriptRow(
          id: id,
          targetType: 'Video',
          targetId: mediaId,
          language: trackResult.language,
          source: source,
          timelineJson: timelineJson,
          referenceId: null,
          label: 'YouTube captions (${trackResult.language})',
          trackIndex: null,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      storedCount++;

      _uploadToWorkerAfterDirectFetch(
        videoId: workerVideoId,
        language: trackResult.language,
        source: source,
        lines: trackResult.subtitles,
      );
    }

    if (storedCount == 0) {
      _log.info(
        'YouTube Tier 2 succeeded profile=${allResult.fetchProfile} '
        'but stored 0 valid tracks for $workerVideoId/$preferredLang',
      );
      return const TranscriptCloudFetchResult(
        status: TranscriptCloudFetchStatus.empty,
      );
    }

    _log.info(
      'YouTube Tier 2 stored $storedCount track(s) via '
      'profile=${allResult.fetchProfile} for $workerVideoId/$preferredLang; '
      'uploads dispatched to worker',
    );

    await _pickYoutubePrimary(
      mediaId: mediaId,
      videoLanguage: videoLanguage.isEmpty ? null : videoLanguage,
      learningLanguage: learningLanguage,
    );

    return TranscriptCloudFetchResult(
      status: TranscriptCloudFetchStatus.success,
      storedCount: storedCount,
    );
  }

  /// Chooses a primary transcript for a YouTube media row based on the
  /// video's content language, falling back to the user's learning
  /// language, then to source priority.
  ///
  /// Honors an existing user-picked primary: when the session already
  /// references a row that still exists, it is preserved (mirrors the
  /// guard in [_ensurePrimaryTranscript]).
  Future<void> _pickYoutubePrimary({
    required String mediaId,
    required String? videoLanguage,
    required String? learningLanguage,
  }) async {
    final rows = await _db.transcriptDao.listForTarget('Video', mediaId);
    if (rows.isEmpty) return;

    final session = await _db.echoSessionDao.getLatestForTarget(
      'Video',
      mediaId,
    );
    final currentId = session?.transcriptId;
    if (currentId != null && rows.any((r) => r.id == currentId)) return;

    final videoMatch = _bestByLanguage(rows, videoLanguage);
    final learningMatch = videoMatch == null
        ? _bestByLanguage(rows, learningLanguage)
        : null;
    final picked =
        videoMatch ??
        learningMatch ??
        () {
          final sorted = [...rows];
          _sortTranscriptRows(sorted);
          return sorted.first;
        }();

    await _db.echoSessionDao.updatePrimaryTranscriptForTarget(
      'Video',
      mediaId,
      picked.id,
    );
  }

  /// Returns the best row whose [TranscriptRow.language] matches [language]
  /// under [matchesLanguageBroad], ranked by source priority then createdAt.
  /// Returns null when no row matches.
  TranscriptRow? _bestByLanguage(List<TranscriptRow> rows, String? language) {
    if (language == null || language.isEmpty) return null;
    final filtered = rows
        .where((r) => matchesLanguageBroad(r.language, language))
        .toList();
    if (filtered.isEmpty) return null;
    _sortTranscriptRows(filtered);
    return filtered.first;
  }
}
