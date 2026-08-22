/// Persistence for Craft-synthesized audio: dedupe lookup, import, load-for-edit,
/// in-place rewrite, and provenance clearing.
library;

import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:drift/drift.dart';

import 'package:enjoy_player/core/application/app_language_catalog.dart';
import 'package:enjoy_player/core/ids/enjoy_ids.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/app_managed_media_gc.dart';
import 'package:enjoy_player/data/files/file_storage.dart';
import 'package:enjoy_player/data/files/media_duration_probe.dart';
import 'package:enjoy_player/features/craft/domain/craft_edit_source.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';

/// Owns the Craft audio lifecycle inside the library database: content-hash
/// dedupe, import of synthesized audio + optional solid transcript,
/// load-for-edit snapshots, in-place rewrites, and history-record removal.
///
/// Every row this module writes is an `audios` row; Craft items are
/// distinguished by `provider = 'craft'` and a `source` flag of
/// `craft-express` / `craft-translate` / `craft-direct`.
class CraftLibraryRepository {
  CraftLibraryRepository(this._db, this._storage, {this._enqueueSync});

  final AppDatabase _db;
  final FileStorage _storage;
  final SyncEnqueueFn? _enqueueSync;

  /// Content hash over the dedupe key — one definition shared by the
  /// import / find / update paths so the three can never drift.
  String _craftContentHash({
    required String sourceFlag,
    required String learningLanguage,
    required String normalizedText,
    String? voice,
  }) {
    final key = '$sourceFlag|$learningLanguage|$normalizedText|${voice ?? ''}';
    return sha256.convert(utf8.encode(key)).toString();
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
    final contentHash = _craftContentHash(
      sourceFlag: sourceFlag,
      learningLanguage: learningLanguage,
      normalizedText: normalizedText,
      voice: voice,
    );
    final existing = await _db.audioDao.getByMd5(contentHash);
    return existing?.id;
  }

  /// Imports synthesized TTS audio + transcript(s) from the Craft from text
  /// flow. Dedupes by content hash over (sourceFlag|learningLanguage|normalizedText).
  ///
  /// [sourceFlag] is `'craft-express'`, `'craft-translate'` or
  /// `'craft-direct'`.
  ///
  /// When [sourceLanguage] is non-null (Translate then speak), the native
  /// text is kept on `sourceText`; no fabricated secondary transcript is
  /// written (see below).
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
    final contentHash = _craftContentHash(
      sourceFlag: sourceFlag,
      learningLanguage: learningLanguage,
      normalizedText: normalizedText,
      voice: voice,
    );

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

    // Probe duration asynchronously (same path as library import).
    unawaited(
      probeAndPatchMediaDuration(_db, id, importResult.localPath, video: false),
    );

    // Enqueue sync.
    await _enqueueSync?.call(SyncEntityType.audio, id, SyncAction.create);
    return id;
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
    final contentHash = _craftContentHash(
      sourceFlag: sourceFlag,
      learningLanguage: canonicalLearning,
      normalizedText: normalizedText,
      voice: voice,
    );

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
          // Reset the previous cloud URL so CraftAudioCloudUploader re-uploads
          // the new bytes. Otherwise the upload pre-step in SyncUploadService
          // would short-circuit (mediaUrl != null) and the cloud copy would
          // stay stale. See specs/043-craft-cloud-sync/US2.
          mediaUrl: const Value(null),
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
      await deleteAppManagedMediaIfUnreferenced(
        db: _db,
        storage: _storage,
        fileUri: previousUri,
      );
    }

    unawaited(
      probeAndPatchMediaDuration(
        _db,
        mediaId,
        importResult.localPath,
        video: false,
      ),
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

  /// Trims normalized text to ~40 chars for the audio title.
  String _craftTitle(String normalizedText) {
    if (normalizedText.length <= 40) return normalizedText;
    return '${normalizedText.substring(0, 40)}…';
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
}
