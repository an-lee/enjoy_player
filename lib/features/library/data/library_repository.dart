/// Imports media files into Drift + local storage.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:cross_file/cross_file.dart';
import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/utils/collections.dart';
import 'package:enjoy_player/core/utils/youtube_video_identity.dart';
import 'package:logging/logging.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/app_managed_media_gc.dart';
import 'package:enjoy_player/data/files/ffmpeg_media_probe.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/data/files/media_resolver.dart';
import 'package:enjoy_player/features/library/domain/craft_edit_source.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/data/youtube_oembed_api.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';
import 'package:http/http.dart' as http;

typedef YoutubeMetadataPatch = ({String title, String? thumbnailUrl});

Media _mediaFromVideo(VideoRow row) => _mediaFromLibraryRow(
  id: row.id,
  kind: MediaKind.video,
  title: row.title,
  localUri: row.localUri,
  mediaUrl: row.mediaUrl,
  thumbnailUrl: row.thumbnailUrl,
  durationSeconds: row.durationSeconds,
  language: row.language,
  contentHash: row.vid,
  size: row.size,
  source: row.source,
  provider: row.provider,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
);

Media _mediaFromAudio(AudioRow row) => _mediaFromLibraryRow(
  id: row.id,
  kind: MediaKind.audio,
  title: row.title,
  localUri: row.localUri,
  mediaUrl: row.mediaUrl,
  thumbnailUrl: row.thumbnailUrl,
  durationSeconds: row.durationSeconds,
  language: row.language,
  contentHash: row.aid,
  size: row.size,
  source: row.source,
  provider: row.provider,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
);

Media _mediaFromLibraryRow({
  required String id,
  required MediaKind kind,
  required String title,
  required String? localUri,
  required String? mediaUrl,
  required String? thumbnailUrl,
  required int durationSeconds,
  required String language,
  required String contentHash,
  required int? size,
  required String? source,
  required String provider,
  required DateTime createdAt,
  required DateTime updatedAt,
}) {
  return Media(
    id: id,
    kind: kind,
    title: title,
    sourceUri: localUri ?? mediaUrl ?? '',
    thumbnailPath: thumbnailUrl,
    durationMs: durationSeconds * 1000,
    language: language,
    contentHash: contentHash,
    fileSize: size ?? 0,
    mediaUrl: mediaUrl,
    source: source,
    provider: provider,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

class MediaLibraryRepository {
  MediaLibraryRepository(
    this._db,
    this._storage, {
    this._enqueueSync,
    this._oembedClient,
  });

  static final Logger _log = logNamed('library.repository');

  final AppDatabase _db;
  final FileStorage _storage;
  final SyncEnqueueFn? _enqueueSync;
  final http.Client? _oembedClient;

  Stream<List<Media>> watchAll() {
    late StreamSubscription<List<VideoRow>> subV;
    late StreamSubscription<List<AudioRow>> subA;
    var videos = <VideoRow>[];
    var audios = <AudioRow>[];

    // Cache the last emitted merged list so we can skip identical re-emissions.
    // Both Drift `watchAll` streams re-query on ANY table change; without this,
    // a single row update (e.g. a `playbackSessionPersister` write that bumps
    // `updatedAt`, or a duration probe that flips one row) currently re-emits
    // the entire library — forcing `libraryHomeRecentsProvider` to re-sort and
    // `libraryFilteredListsProvider` to re-filter + re-sort both lists.
    //
    // `lastEmitted` is nullable (rather than starting as `const <Media>[]`) so
    // an empty library still produces its first emission: when both DAOs'
    // initial snapshots are empty, `merged` is `[]`, which used to compare
    // equal to the empty starting value and get swallowed by the dedupe
    // check — leaving `watchAll()` never emitting and every `StreamProvider`
    // built on it (library home/recents/filtered lists) stuck in
    // `AsyncLoading` forever whenever the local library has zero rows.
    List<Media>? lastEmitted;

    void emit(StreamController<List<Media>> c) {
      final merged = <Media>[
        ...videos.map(_mediaFromVideo),
        ...audios.map(_mediaFromAudio),
      ]..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      if (lastEmitted != null && listEquals(lastEmitted!, merged)) {
        return;
      }
      lastEmitted = merged;
      c.add(merged);
    }

    return Stream<List<Media>>.multi((controller) {
      subV = _db.videoDao.watchAll().listen((rows) {
        videos = rows;
        emit(controller);
      }, onError: controller.addError);
      subA = _db.audioDao.watchAll().listen((rows) {
        audios = rows;
        emit(controller);
      }, onError: controller.addError);
      controller.onCancel = () {
        unawaited(subV.cancel());
        unawaited(subA.cancel());
      };
    });
  }

  /// Imports a local file into the signed-in user's library.
  Future<String> importMedia(
    XFile file, {
    required String signedInUserId,
    String contentLanguage = kUnknownMediaLanguageTag,
  }) async {
    try {
      if (!isImportableLocalMediaFileName(file.name)) {
        throw const UnsupportedImportFileFailure();
      }
      final result = await _storage.importOrLinkPickedFile(file);
      final kind = isVideoFileName(file.name)
          ? MediaKind.video
          : MediaKind.audio;
      final now = DateTime.now();
      final contentHash = result.contentHashHex;

      if (kind == MediaKind.video) {
        final vid = enjoyLocalVideoVid(
          contentHashHex: contentHash,
          userId: signedInUserId,
        );
        final id = enjoyVideoId(vid: vid);
        final existing = await _db.videoDao.getById(id);
        await _db.videoDao.insertRow(
          VideoRow(
            id: id,
            vid: vid,
            provider: 'user',
            title: result.title,
            description: existing?.description,
            thumbnailUrl: existing?.thumbnailUrl,
            durationSeconds: existing?.durationSeconds ?? 0,
            language: canonicalMediaLanguageTag(contentLanguage),
            source: existing?.source,
            localUri: result.fileUri,
            bookmarkData: result.bookmarkData,
            md5: contentHash,
            size: result.fileSize,
            localMtimeMs: result.mtimeMs,
            mediaUrl: existing?.mediaUrl,
            syncStatus: 'pending',
            serverUpdatedAt: existing?.serverUpdatedAt,
            createdAt: existing?.createdAt ?? now,
            updatedAt: now,
          ),
        );
        return _finalizeLocalImport(
          id: id,
          previousUri: existing?.localUri,
          fileUri: result.fileUri,
          video: true,
          entityType: SyncEntityType.video,
          isUpdate: existing != null,
        );
      }

      final aid = enjoyLocalAudioAid(
        contentHashHex: contentHash,
        userId: signedInUserId,
      );
      final id = enjoyAudioId(aid: aid);
      final existing = await _db.audioDao.getById(id);
      await _db.audioDao.insertRow(
        AudioRow(
          id: id,
          aid: aid,
          provider: 'user',
          title: result.title,
          description: existing?.description,
          thumbnailUrl: existing?.thumbnailUrl,
          durationSeconds: existing?.durationSeconds ?? 0,
          language: canonicalMediaLanguageTag(contentLanguage),
          translationKey: existing?.translationKey,
          sourceText: existing?.sourceText,
          voice: existing?.voice,
          source: existing?.source,
          localUri: result.fileUri,
          bookmarkData: result.bookmarkData,
          md5: contentHash,
          size: result.fileSize,
          localMtimeMs: result.mtimeMs,
          mediaUrl: existing?.mediaUrl,
          syncStatus: 'pending',
          serverUpdatedAt: existing?.serverUpdatedAt,
          createdAt: existing?.createdAt ?? now,
          updatedAt: now,
        ),
      );
      return _finalizeLocalImport(
        id: id,
        previousUri: existing?.localUri,
        fileUri: result.fileUri,
        video: false,
        entityType: SyncEntityType.audio,
        isUpdate: existing != null,
      );
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(FileFailure('Import failed: $e'), st);
    }
  }

  /// Imports a YouTube video by pasted URL or bare video id.
  Future<String> importYoutubeVideo(
    String rawInput, {
    String? prefetchedTitle,
    String? prefetchedThumbnailUrl,
    String contentLanguage = kUnknownMediaLanguageTag,
  }) async {
    final id = parseYoutubeVideoId(rawInput);
    if (id == null) {
      throw const FileFailure('Invalid YouTube URL or video ID.');
    }
    final dup = await _db.videoDao.getYoutubeByVid(id);
    if (dup != null) {
      await _maybePatchYoutubeMetadata(
        dup,
        prefetchedTitle: prefetchedTitle,
        prefetchedThumbnailUrl: prefetchedThumbnailUrl,
      );
      // Resurface on Home even when metadata was already complete (re-add).
      await _db.videoDao.touchUpdatedAt(dup.id);
      return dup.id;
    }

    final oembed = await fetchYoutubeOembed(id, client: _oembedClient);
    final title = _resolveYoutubeTitle(
      id,
      prefetchedTitle: prefetchedTitle,
      oembed: oembed,
    );
    final thumb = _resolveYoutubeThumbnail(
      prefetchedThumbnailUrl: prefetchedThumbnailUrl,
      oembed: oembed,
    );

    final rowId = enjoyVideoId(provider: 'youtube', vid: id);
    final now = DateTime.now();

    final row = VideoRow(
      id: rowId,
      vid: id,
      provider: 'youtube',
      title: title,
      description: null,
      thumbnailUrl: thumb,
      durationSeconds: 0,
      language: canonicalMediaLanguageTag(contentLanguage),
      source: 'youtube',
      localUri: null,
      md5: null,
      size: null,
      mediaUrl: 'https://www.youtube.com/watch?v=$id',
      syncStatus: 'pending',
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    await _db.videoDao.insertRow(row);
    await _enqueueSync?.call(SyncEntityType.video, rowId, SyncAction.create);
    return rowId;
  }

  /// Imports synthesized TTS audio + transcript(s) from the Craft from text
  /// flow. Dedupes by content hash over (sourceFlag|learningLanguage|normalizedText).
  ///
  /// [sourceFlag] is `'craft-translate'` or `'craft-direct'` — avoids importing
  /// CraftMode from the craft feature module so this repository stays
  /// decoupled.
  ///
  /// When [sourceLanguage] is non-null (Translate then speak), a secondary
  /// transcript row is created so bilingual overlay works on first play.
  Future<String> importCraftedFromText({
    required Uint8List audioBytes,
    required String audioFormat,
    required String learningLanguage,
    String? sourceLanguage,
    required String text,
    required String normalizedText,
    String? primaryTimelineJson,
    String? voice,
    required String sourceFlag,
    required String signedInUserId,
  }) async {
    final voiceKey = voice ?? '';
    final dedupeKey = '$sourceFlag|$learningLanguage|$normalizedText|$voiceKey';
    final contentHash = sha256.convert(utf8.encode(dedupeKey)).toString();

    // Dedupe: if the same content hash exists, return the existing id.
    final existing = await _db.audioDao.getByMd5(contentHash);
    if (existing != null) {
      return existing.id;
    }

    // Write audio bytes to local storage.
    final importResult = await _storage.importBytes(
      audioBytes,
      extension: audioFormat,
      title: _craftTitle(normalizedText),
    );

    final aid = enjoyLocalAudioAid(
      contentHashHex: contentHash,
      userId: signedInUserId,
    );
    final id = enjoyAudioId(aid: aid);
    final now = DateTime.now();
    final canonicalLearning = canonicalMediaLanguageTag(learningLanguage);

    // Solid timeline → AI transcript row. Null → blank (no fabricated cues);
    // learner generates via STT in the player.
    final primaryTranscriptId = enjoyTranscriptId(
      targetType: 'Audio',
      targetId: id,
      language: canonicalLearning,
      source: 'ai',
    );

    // Single transaction: audio row + optional primary transcript.
    // We do NOT save a secondary source-text transcript — without word-level
    // alignment between source and synthesized target text, a secondary
    // transcript with fabricated timestamps is worse than no secondary.
    await _db.transaction(() async {
      final audioRow = AudioRow(
        id: id,
        aid: aid,
        provider: 'craft',
        title: importResult.title,
        // Full practice/synth text for edit when the timed transcript is blank
        // (Express stores native ASR in [sourceText], not practice wording).
        description: normalizedText,
        thumbnailUrl: null,
        durationSeconds: 0,
        language: canonicalLearning,
        translationKey: canonicalLearning,
        sourceText: text,
        voice: voice,
        source: sourceFlag,
        localUri: importResult.fileUri,
        md5: contentHash,
        size: importResult.fileSize,
        localMtimeMs: importResult.mtimeMs,
        mediaUrl: null,
        syncStatus: 'pending',
        serverUpdatedAt: null,
        createdAt: now,
        updatedAt: now,
      );
      await _db.audioDao.insertRow(audioRow);

      if (primaryTimelineJson != null) {
        final primaryRow = TranscriptRow(
          id: primaryTranscriptId,
          targetType: 'Audio',
          targetId: id,
          language: canonicalLearning,
          source: 'ai',
          timelineJson: primaryTimelineJson,
          referenceId: null,
          label: '',
          trackIndex: null,
          syncStatus: 'local',
          serverUpdatedAt: null,
          createdAt: now,
          updatedAt: now,
        );
        await _db.transcriptDao.upsert(primaryRow);
      }
    });

    // Probe duration asynchronously (same path as importMedia).
    unawaited(_probeAndPatchDuration(id, importResult.localPath, video: false));

    // Enqueue sync.
    await _enqueueSync?.call(SyncEntityType.audio, id, SyncAction.create);
    return id;
  }

  /// Trims normalized text to ~40 chars for the audio title.
  String _craftTitle(String normalizedText) {
    if (normalizedText.length <= 40) return normalizedText;
    return '${normalizedText.substring(0, 40)}…';
  }

  /// Checks whether a Crafted audio with the same content hash already exists.
  /// Returns the existing media id, or `null` if no match.
  ///
  /// Called by the Craft controller BEFORE any AI calls to enable dedupe
  /// without wasting translate / synthesize requests.
  Future<String?> findExistingCrafted({
    required String learningLanguage,
    required String normalizedText,
    required String sourceFlag,
    String? voice,
  }) async {
    final voiceKey = voice ?? '';
    final dedupeKey = '$sourceFlag|$learningLanguage|$normalizedText|$voiceKey';
    final contentHash = sha256.convert(utf8.encode(dedupeKey)).toString();
    final existing = await _db.audioDao.getByMd5(contentHash);
    return existing?.id;
  }

  /// Loads an editable snapshot of an existing Crafted audio item.
  ///
  /// Returns `null` when [mediaId] does not exist or is not a
  /// `provider = 'craft'` row — callers should treat this as "no longer
  /// available" (e.g. deleted from another device).
  Future<CraftEditSource?> getCraftEditSource(String mediaId) async {
    final row = await _db.audioDao.getById(mediaId);
    if (row == null || row.provider != 'craft') return null;

    final transcripts = await _db.transcriptDao.listForTarget('Audio', mediaId);
    // Prefer timed AI cues; else description (full practice text); else
    // sourceText (Advanced speak-direct / legacy rows).
    final practiceText =
        _joinTimelineText(transcripts) ??
        row.description ??
        row.sourceText ??
        '';

    return CraftEditSource(
      mediaId: mediaId,
      practiceText: practiceText,
      sourceText: row.sourceText,
      language: row.language,
      voice: row.voice,
      sourceFlag: row.source,
    );
  }

  /// Reconstructs the practice text by joining the primary transcript's
  /// timeline segment text fields. Returns `null` when no transcript rows
  /// exist or the timeline JSON cannot be parsed.
  String? _joinTimelineText(List<TranscriptRow> transcripts) {
    if (transcripts.isEmpty) return null;
    final primary = transcripts.firstWhere(
      (t) => t.source == 'ai',
      orElse: () => transcripts.first,
    );
    try {
      final decoded = jsonDecode(primary.timelineJson);
      if (decoded is! List) return null;
      final joined = decoded
          .map((e) => (e is Map ? e['text'] : null)?.toString() ?? '')
          .where((s) => s.isNotEmpty)
          .join(' ');
      return joined.isEmpty ? null : joined;
    } catch (_) {
      return null;
    }
  }

  /// Updates an existing Crafted audio item in place — same media id, new
  /// audio bytes + transcript. Used when editing an existing Craft item
  /// from Craft history instead of creating a new library entry.
  ///
  /// Throws [StateError] when [mediaId] does not exist or is not a
  /// `provider = 'craft'` row.
  Future<String> updateCraftedFromText({
    required String mediaId,
    required Uint8List audioBytes,
    required String audioFormat,
    required String learningLanguage,
    required String text,
    required String normalizedText,
    String? primaryTimelineJson,
    String? voice,
    required String sourceFlag,
  }) async {
    final existing = await _db.audioDao.getById(mediaId);
    if (existing == null || existing.provider != 'craft') {
      throw StateError('Craft media not found or not editable: $mediaId');
    }

    final previousUri = existing.localUri;
    final importResult = await _storage.importBytes(
      audioBytes,
      extension: audioFormat,
      title: _craftTitle(normalizedText),
    );

    final now = DateTime.now();
    final canonicalLearning = canonicalMediaLanguageTag(learningLanguage);
    final voiceKey = voice ?? '';
    final dedupeKey =
        '$sourceFlag|$canonicalLearning|$normalizedText|$voiceKey';
    final contentHash = sha256.convert(utf8.encode(dedupeKey)).toString();

    final primaryTranscriptId = enjoyTranscriptId(
      targetType: 'Audio',
      targetId: mediaId,
      language: canonicalLearning,
      source: 'ai',
    );

    await _db.transaction(() async {
      await _db.audioDao.insertRow(
        existing.copyWith(
          title: importResult.title,
          language: canonicalLearning,
          translationKey: Value(canonicalLearning),
          description: Value(normalizedText),
          sourceText: Value(text),
          voice: Value(voice),
          source: Value(sourceFlag),
          localUri: Value(importResult.fileUri),
          md5: Value(contentHash),
          size: Value(importResult.fileSize),
          localMtimeMs: Value(importResult.mtimeMs),
          durationSeconds: 0,
          syncStatus: const Value('pending'),
          updatedAt: now,
        ),
      );

      // Drop all prior transcripts for this media — solid rewrite replaces
      // the primary track; blank clears estimated/stale cues entirely.
      // Single bulk DELETE instead of per-row loop (issue #468).
      await _db.customStatement(
        'DELETE FROM transcripts WHERE target_type = ? AND target_id = ?',
        ['Audio', mediaId],
      );

      if (primaryTimelineJson != null) {
        await _db.transcriptDao.upsert(
          TranscriptRow(
            id: primaryTranscriptId,
            targetType: 'Audio',
            targetId: mediaId,
            language: canonicalLearning,
            source: 'ai',
            timelineJson: primaryTimelineJson,
            referenceId: null,
            label: '',
            trackIndex: null,
            syncStatus: 'local',
            serverUpdatedAt: null,
            createdAt: now,
            updatedAt: now,
          ),
        );
      }
    });

    if (previousUri != null && previousUri != importResult.fileUri) {
      await _maybeDeleteAppManagedMedia(previousUri);
    }

    unawaited(
      _probeAndPatchDuration(mediaId, importResult.localPath, video: false),
    );

    await _enqueueSync?.call(SyncEntityType.audio, mediaId, SyncAction.update);
    return mediaId;
  }

  /// Removes a Craft history record without deleting the practice audio.
  ///
  /// Clears Craft provenance (`provider` → `user`) so the item no longer
  /// appears in Craft history or with a Craft badge, while keeping the
  /// same media id, file, transcript, and library presence.
  ///
  /// Throws [StateError] when [mediaId] is missing or not `provider = 'craft'`.
  Future<void> removeCraftHistoryRecord(String mediaId) async {
    final existing = await _db.audioDao.getById(mediaId);
    if (existing == null || existing.provider != 'craft') {
      throw StateError('Craft history record not found: $mediaId');
    }

    final now = DateTime.now();
    await _db.audioDao.insertRow(
      existing.copyWith(
        provider: 'user',
        syncStatus: const Value('pending'),
        updatedAt: now,
      ),
    );
    await _enqueueSync?.call(SyncEntityType.audio, mediaId, SyncAction.update);
  }

  /// Re-fetches oEmbed when title/thumbnail are still import placeholders.
  Future<YoutubeMetadataPatch?> refreshYoutubeMetadataIfNeeded(
    String mediaId,
  ) async {
    final row = await _db.videoDao.getById(mediaId);
    if (row == null || row.provider.toLowerCase() != 'youtube') return null;
    if (!_youtubeMetadataNeedsRefresh(row)) return null;

    final meta = await fetchYoutubeOembed(row.vid, client: _oembedClient);
    if (meta == null) return null;

    final title = meta.title;
    final thumb = meta.thumbnailUrl ?? row.thumbnailUrl;
    await _db.videoDao.updateYoutubeMetadata(
      id: mediaId,
      title: title,
      thumbnailUrl: thumb,
    );
    await _enqueueYoutubeMetadataSync(row);
    return (title: title, thumbnailUrl: thumb);
  }

  bool _youtubeMetadataNeedsRefresh(VideoRow row) {
    return isYoutubeImportPlaceholderTitle(row.title, row.vid) ||
        row.thumbnailUrl == null ||
        row.thumbnailUrl!.trim().isEmpty;
  }

  String _resolveYoutubeTitle(
    String vid, {
    String? prefetchedTitle,
    YoutubeOembedMetadata? oembed,
  }) {
    final pref = prefetchedTitle?.trim();
    if (pref != null &&
        pref.isNotEmpty &&
        !isYoutubeImportPlaceholderTitle(pref, vid)) {
      return pref;
    }
    return oembed?.title ?? youtubeImportPlaceholderTitle(vid);
  }

  String? _resolveYoutubeThumbnail({
    String? prefetchedThumbnailUrl,
    YoutubeOembedMetadata? oembed,
  }) {
    final pref = prefetchedThumbnailUrl?.trim();
    if (pref != null && pref.isNotEmpty) return pref;
    return oembed?.thumbnailUrl;
  }

  Future<void> _maybePatchYoutubeMetadata(
    VideoRow row, {
    String? prefetchedTitle,
    String? prefetchedThumbnailUrl,
  }) async {
    if (!_youtubeMetadataNeedsRefresh(row)) return;

    final oembed = await fetchYoutubeOembed(row.vid, client: _oembedClient);
    final title = _resolveYoutubeTitle(
      row.vid,
      prefetchedTitle: prefetchedTitle,
      oembed: oembed,
    );
    final needsTitle =
        isYoutubeImportPlaceholderTitle(row.title, row.vid) &&
        !isYoutubeImportPlaceholderTitle(title, row.vid);
    final thumb = _resolveYoutubeThumbnail(
      prefetchedThumbnailUrl: prefetchedThumbnailUrl,
      oembed: oembed,
    );
    final needsThumb =
        (row.thumbnailUrl == null || row.thumbnailUrl!.trim().isEmpty) &&
        thumb != null &&
        thumb.isNotEmpty;
    if (!needsTitle && !needsThumb) return;

    final resolvedTitle = needsTitle ? title : row.title;
    final resolvedThumb = needsThumb ? thumb : row.thumbnailUrl;
    await _db.videoDao.updateYoutubeMetadata(
      id: row.id,
      title: resolvedTitle,
      thumbnailUrl: resolvedThumb,
    );
    await _enqueueYoutubeMetadataSync(row);
  }

  Future<void> _enqueueYoutubeMetadataSync(VideoRow row) async {
    final status = row.syncStatus?.trim();
    if (status == null || status.isEmpty) return;
    await _enqueueSync?.call(SyncEntityType.video, row.id, SyncAction.update);
  }

  /// Fills `duration_seconds` when still zero after import, using `ffmpeg -i`.
  ///
  /// The probe is dispatched to a worker isolate so a multi-GB video
  /// import does not block the UI thread for several seconds. The
  /// Isolate.run pattern mirrors `lib/data/files/file_storage.dart:128`
  /// (chunked SHA-256 hashing) so the platform-channel hop is amortised
  /// across the import.
  Future<void> _probeAndPatchDuration(
    String mediaId,
    String fileUri, {
    required bool video,
  }) async {
    final ffmpeg = await FfmpegMediaProbe.resolveFfmpegExecutable();
    if (ffmpeg == null) return;
    final input = FfmpegMediaProbe.mediaInputForFfmpeg(fileUri);

    Duration? sec;
    try {
      sec = await Isolate.run(
        () => _probeDurationInIsolate(ffmpeg, input),
        debugName: 'ffmpeg-duration-probe',
      );
    } catch (_) {
      return;
    }
    if (sec == null) return;

    if (video) {
      final row = await _db.videoDao.getById(mediaId);
      if (row == null || row.durationSeconds != 0) return;
      await _db.videoDao.insertRow(
        row.copyWith(durationSeconds: sec.inSeconds, updatedAt: DateTime.now()),
      );
    } else {
      final row = await _db.audioDao.getById(mediaId);
      if (row == null || row.durationSeconds != 0) return;
      await _db.audioDao.insertRow(
        row.copyWith(durationSeconds: sec.inSeconds, updatedAt: DateTime.now()),
      );
    }
  }

  /// Video posters are captured from the active [PlayerController] via media_kit
  /// screenshot; FFmpeg background extraction was removed.
  ///
  /// Kept as a stable hook for call sites (e.g. cloud add-to-library) — no-op.
  Future<void> ensureVideoPosterAfterMetadataInsert(VideoRow _) async {}

  /// Bumps library-row [updatedAt] so Home "Recent media" ranks recently opened
  /// items without enqueueing a cloud sync update.
  ///
  /// Failures are swallowed (logged) so fire-and-forget callers from
  /// [PlayerController.openMedia] cannot fail tests or tear-down when the DB
  /// is already closed.
  Future<void> touchMediaUpdatedAt(String mediaId) async {
    try {
      final video = await _db.videoDao.getById(mediaId);
      if (video != null) {
        await _db.videoDao.touchUpdatedAt(mediaId);
        return;
      }
      final audio = await _db.audioDao.getById(mediaId);
      if (audio != null) {
        await _db.audioDao.touchUpdatedAt(mediaId);
      }
    } on Object catch (e, st) {
      _log.warning('touchMediaUpdatedAt failed for $mediaId', e, st);
    }
  }

  Future<void> deleteMedia(String id) async {
    // Atomic: enqueue the sync row inside the same transaction as the
    // local delete. If the local delete fails, the sync enqueue is
    // rolled back and the user can retry; previously, a sync row
    // could be left pointing at a media id that no longer exists
    // locally when the local delete threw between the two calls.
    String? localUri;
    await _db.transaction(() async {
      final v = await _db.videoDao.getById(id);
      if (v != null) {
        localUri = v.localUri;
        await _enqueueSync?.call(SyncEntityType.video, id, SyncAction.delete);
        await _db.videoDao.deleteId(id);
        return;
      }
      final a = await _db.audioDao.getById(id);
      if (a != null) {
        localUri = a.localUri;
        await _enqueueSync?.call(SyncEntityType.audio, id, SyncAction.delete);
        await _db.audioDao.deleteId(id);
        return;
      }
    });
    await _maybeDeleteAppManagedMedia(localUri);
  }

  Future<void> _maybeDeleteAppManagedMedia(String? fileUri) {
    return deleteAppManagedMediaIfUnreferenced(
      db: _db,
      storage: _storage,
      fileUri: fileUri,
    );
  }

  Future<Media?> getById(String id) async {
    final v = await _db.videoDao.getById(id);
    if (v != null) return _mediaFromVideo(v);
    final a = await _db.audioDao.getById(id);
    if (a != null) return _mediaFromAudio(a);
    return null;
  }

  /// Updates content language on an existing audio or video row.
  Future<void> updateMediaLanguage(String id, String language) async {
    final canonical = canonicalMediaLanguageTag(language);
    final video = await _db.videoDao.getById(id);
    if (video != null) {
      if (tagsEqual(video.language, canonical)) return;
      await _db.videoDao.updateLanguage(id: id, language: canonical);
      await _db.transcriptFetchStateDao.clearForTarget('video', id);
      await _enqueueSync?.call(SyncEntityType.video, id, SyncAction.update);
      return;
    }
    final audio = await _db.audioDao.getById(id);
    if (audio != null) {
      if (tagsEqual(audio.language, canonical)) return;
      await _db.audioDao.updateLanguage(id: id, language: canonical);
      await _enqueueSync?.call(SyncEntityType.audio, id, SyncAction.update);
      return;
    }
    throw const FileFailure('Media not found.');
  }

  /// Link or copy a user-picked file when its chunked SHA-256 matches the
  /// row's `md5` field, then set [localUri] for playback on this device.
  Future<void> relocateLocalFile({
    required String mediaId,
    required XFile picked,
  }) async {
    try {
      final video = await _db.videoDao.getById(mediaId);
      if (video != null) {
        await _relocateLinkedFile(
          mediaId: mediaId,
          md5: video.md5,
          previousUri: video.localUri,
          entityType: SyncEntityType.video,
          picked: picked,
          persist: (result) => _db.videoDao.insertRow(
            video.copyWith(
              localUri: Value(result.fileUri),
              bookmarkData: Value(result.bookmarkData),
              size: Value(result.fileSize),
              localMtimeMs: Value(result.mtimeMs),
              updatedAt: DateTime.now(),
            ),
          ),
        );
        return;
      }

      final audio = await _db.audioDao.getById(mediaId);
      if (audio != null) {
        await _relocateLinkedFile(
          mediaId: mediaId,
          md5: audio.md5,
          previousUri: audio.localUri,
          entityType: SyncEntityType.audio,
          picked: picked,
          persist: (result) => _db.audioDao.insertRow(
            audio.copyWith(
              localUri: Value(result.fileUri),
              bookmarkData: Value(result.bookmarkData),
              size: Value(result.fileSize),
              localMtimeMs: Value(result.mtimeMs),
              updatedAt: DateTime.now(),
            ),
          ),
        );
        return;
      }

      throw const FileFailure('Media not found.');
    } on AppFailure {
      rethrow;
    } catch (e, st) {
      Error.throwWithStackTrace(FileFailure('Relocate failed: $e'), st);
    }
  }

  Future<String> _finalizeLocalImport({
    required String id,
    required String? previousUri,
    required String fileUri,
    required bool video,
    required SyncEntityType entityType,
    required bool isUpdate,
  }) async {
    if (previousUri != null && previousUri != fileUri) {
      await _maybeDeleteAppManagedMedia(previousUri);
    }
    unawaited(_probeAndPatchDuration(id, fileUri, video: video));
    await _enqueueSync?.call(
      entityType,
      id,
      isUpdate ? SyncAction.update : SyncAction.create,
    );
    return id;
  }

  Future<void> _relocateLinkedFile({
    required String mediaId,
    required String? md5,
    required String? previousUri,
    required SyncEntityType entityType,
    required XFile picked,
    required Future<void> Function(FileImportResult result) persist,
  }) async {
    final hash = md5;
    if (hash == null || hash.isEmpty) {
      throw const FileFailure(
        'Cannot locate file: this item has no content fingerprint.',
      );
    }
    final result = await _storage.importOrLinkPickedFile(
      picked,
      expectedHashHex: hash,
    );
    await persist(result);
    if (previousUri != null && previousUri != result.fileUri) {
      await _maybeDeleteAppManagedMedia(previousUri);
    }
    await _enqueueSync?.call(entityType, mediaId, SyncAction.update);
  }
}

/// Top-level so it can be sent to a worker isolate via [Isolate.run].
/// Returns the parsed duration in seconds, or `null` when ffmpeg is
/// missing / the input is unreadable / the stderr does not contain a
/// `Duration:` line.
Duration? _probeDurationInIsolate(String ffmpeg, String input) {
  // Run synchronously inside the worker isolate; ffmpeg `-i` only
  // inspects metadata so this typically returns in < 2s.
  final result = Process.runSync(ffmpeg, ['-hide_banner', '-i', input]);
  if (result.exitCode != 0 && result.exitCode != 1) {
    return null;
  }
  final stderr = result.stderr is String
      ? result.stderr as String
      : String.fromCharCodes((result.stderr as List<int>?) ?? const <int>[]);
  final sec = FfmpegMediaProbe.parseDurationSeconds(stderr);
  if (sec == null || sec <= 0) return null;
  return Duration(seconds: sec);
}
