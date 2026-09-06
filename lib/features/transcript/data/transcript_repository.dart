/// Local transcript repository: track watching, resolution on open, cloud /
/// YouTube fetching, subtitle import, and auto-translate track management.
///
/// This file is the API surface: the class declaration with every public
/// member plus the module-private helpers shared by the part files. All
/// behavior lives in private part extensions on [TranscriptRepository]
/// (`_TranscriptRepositoryLines`, `_TranscriptRepositoryResolve`,
/// `_TranscriptRepositoryCloudFetch`, `_TranscriptRepositoryTracks`,
/// `_TranscriptRepositorySubtitleImport`,
/// `_TranscriptRepositoryAutoTranslate`, `_TranscriptRepositoryYoutubeFetch`,
/// `_TranscriptRepositoryYoutubeWorkerCache`); every public member forwards
/// to its extension body so fakes can override any part of the surface.
library;

import 'dart:async';
import 'dart:convert';

import 'package:async/async.dart';
import 'package:crypto/crypto.dart';
import 'package:cross_file/cross_file.dart';
import 'package:drift/drift.dart' show InsertMode, Value;
import 'package:flutter/foundation.dart';
import 'package:logging/logging.dart';
import 'package:media_kit/media_kit.dart' as mk;
import 'package:path/path.dart' as p;

import '../../../core/application/app_language_catalog.dart';
import '../../../core/ids/enjoy_ids.dart';
import '../../../core/logging/log.dart';
import '../../../core/utils/stream_distinct.dart';
import '../../../core/utils/youtube_video_identity.dart';
import '../../../data/api/services/ai/youtube_transcripts_api.dart';
import '../../../data/api/services/transcript_api.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/media_target_resolver.dart';
import '../../../data/subtitle/embedded_subtitle_service.dart';
import '../../../data/subtitle/subtitle_parser.dart';
import '../../../data/subtitle/transcript_line.dart';
import '../../../data/subtitle/subtitle_filename.dart';
import '../domain/auto_translate.dart';
import '../domain/transcript_fetch_status.dart';
import '../domain/transcript_track.dart';
import 'sidecar_subtitle_discovery.dart';
import 'transcript_timeline_parse.dart';
import 'youtube_caption_fetcher.dart';

part 'transcript_repository_auto_translate.dart';
part 'transcript_repository_cloud_fetch.dart';
part 'transcript_repository_lines.dart';
part 'transcript_repository_resolve.dart';
part 'transcript_repository_shared.dart';
part 'transcript_repository_subtitle_import.dart';
part 'transcript_repository_tracks.dart';
part 'transcript_repository_youtube_fetch.dart';
part 'transcript_repository_youtube_worker_cache.dart';

/// Owns transcript rows for a media target: watching tracks, resolving the
/// primary transcript on open, fetching cloud / YouTube transcripts,
/// importing subtitles, and managing active tracks.
class TranscriptRepository {
  TranscriptRepository(
    this._db, [
    this._transcriptApi,
    this._youtubeTranscripts,
    this._youtubeFetcher,
  ]);

  final AppDatabase _db;
  final TranscriptApi? _transcriptApi;
  final YoutubeTranscriptsClient? _youtubeTranscripts;
  final YoutubeCaptionFetcher? _youtubeFetcher;

  final Map<String, _LinesCacheEntry> _linesCache = {};

  // ---
  // Lines cache + reactive watches
  // ---

  /// Decodes [row.timelineJson] with memoization on `(id, timelineJsonHash)`.
  ///
  /// The hash-on-content key avoids re-decoding when an unrelated Drift table
  /// bump shifts the row's `updatedAt` without changing `timelineJson`.
  List<TranscriptLine> linesForRow(TranscriptRow row) => _linesForRow(row);

  /// Reactive lines for the active primary (shadow-reading) transcript.
  Stream<List<TranscriptLine>> watchPrimaryLines(String mediaId) =>
      _watchLines(mediaId, primary: true);

  /// Reactive lines for the active secondary (translation) transcript.
  Stream<List<TranscriptLine>> watchSecondaryLines(String mediaId) =>
      _watchLines(mediaId, primary: false);

  Future<TranscriptRow?> primaryTranscriptRowForMedia(String mediaId) =>
      _primaryTranscriptRowForMedia(mediaId);

  Stream<List<TranscriptTrack>> watchTracks(String mediaId) =>
      _watchTracks(mediaId);

  // ---
  // Open-time resolution
  // ---

  /// Orchestrates transcript resolution when media is opened.
  ///
  /// 1. Ensures a primary transcript when tracks exist.
  /// 2. Imports adjacent sidecar `.srt` / `.vtt` for local files.
  /// 3. Optionally fetches cloud / YouTube transcripts when [fetchCloud].
  ///
  /// [nativeLanguage] / [learningLanguage] are forwarded to the YouTube
  /// branch so the post-fetch primary picker can prefer tracks matching the
  /// video's content language first, then the user's learning language,
  /// then fall back to source priority.
  Future<TranscriptResolveResult> resolveOnOpen(
    String mediaId, {
    bool forceCloud = false,
    bool fetchCloud = true,
    String? nativeLanguage,
    String? learningLanguage,
  }) => _resolveOnOpen(
    mediaId,
    forceCloud: forceCloud,
    fetchCloud: fetchCloud,
    nativeLanguage: nativeLanguage,
    learningLanguage: learningLanguage,
  );

  // ---
  // Cloud / YouTube fetch
  // ---

  /// Fetches transcripts from the Enjoy API and upserts them locally.
  ///
  /// When [force] is false, skips if this target was already fetched once
  /// ([TranscriptFetchStates]). On success, marks fetch state. Errors are
  /// logged and persisted as `error` when possible.
  Future<TranscriptCloudFetchResult> fetchCloudTranscripts(
    String mediaId, {
    bool force = false,
    String? nativeLanguage,
    String? learningLanguage,
  }) => _fetchCloudTranscripts(
    mediaId,
    force: force,
    nativeLanguage: nativeLanguage,
    learningLanguage: learningLanguage,
  );

  // ---
  // Track / session management
  // ---

  /// Persists a generated `source: 'ai'` transcript for [mediaId] +
  /// [language] using a deterministic row id so re-generation upserts
  /// in place (SC-004 / FR-010).
  ///
  /// When [activateAsPrimary] is true (default), the new track is set
  /// as the session primary (FR-021). The prior `label` is preserved
  /// across re-generations so the user keeps a familiar name (FR-022).
  /// Returns the row id, or null when the media id cannot be resolved.
  Future<String?> upsertAsrGeneratedTrack({
    required String mediaId,
    required String language,
    required List<TranscriptLine> lines,
    String? label,
    bool activateAsPrimary = true,
  }) => _upsertAsrGeneratedTrack(
    mediaId: mediaId,
    language: language,
    lines: lines,
    label: label,
    activateAsPrimary: activateAsPrimary,
  );

  Future<void> setActiveTranscript(String mediaId, String transcriptId) =>
      _setActiveTranscript(mediaId, transcriptId);

  Future<void> setSecondaryTranscript(String mediaId, String? transcriptId) =>
      _setSecondaryTranscript(mediaId, transcriptId);

  Future<void> deleteTranscript(String transcriptId) =>
      _deleteTranscript(transcriptId);

  Future<TranscriptRow?> transcriptRowById(String transcriptId) =>
      _transcriptRowById(transcriptId);

  /// Replaces [timelineJson] on an existing primary row in place.
  ///
  /// Preserves id, source, language, label, and target. Returns false when
  /// the row is missing.
  Future<bool> replaceTimeline({
    required String transcriptId,
    required List<TranscriptLine> lines,
  }) => _replaceTimeline(transcriptId: transcriptId, lines: lines);

  // ---
  // Subtitle import
  // ---

  /// Imports a user-supplied `.srt` / `.vtt` file as a `source: user` track.
  Future<void> importSubtitle({
    required String mediaId,
    required XFile file,
    required String language,
    String? label,
  }) => _importSubtitle(
    mediaId: mediaId,
    file: file,
    language: language,
    label: label,
  );

  /// Extracts embedded subtitle streams via ffmpeg; stored as `source: user`.
  ///
  /// Returns the number of new/updated transcript rows written.
  ///
  /// [playerSubtitleTracks] may be empty: subtitle streams are then discovered
  /// via `ffmpeg -i` (see [EmbeddedSubtitleService.extractTracks]).
  Future<int> extractEmbeddedTracks({
    required String mediaId,
    required String sourceUri,
    List<mk.SubtitleTrack> playerSubtitleTracks = const [],
  }) => _extractEmbeddedTracks(
    mediaId: mediaId,
    sourceUri: sourceUri,
    playerSubtitleTracks: playerSubtitleTracks,
  );

  // ---
  // Auto-translate track management
  // ---

  /// Ensures a durable `source: ai` track exists with a timing skeleton for
  /// auto-translate. Returns the track id, or null when the target is unknown.
  ///
  /// When a non-stale AI track already exists for the same primary, its
  /// translated texts are **preserved** (no rewrite). Stale tracks are rebuilt
  /// as an empty skeleton so mismatched bilingual pairs are never shown.
  Future<String?> ensureAutoTranslateTrack({
    required String mediaId,
    required String primaryTranscriptId,
    required String targetLanguage,
    required List<TranscriptLine> primaryLines,
  }) => _ensureAutoTranslateTrack(
    mediaId: mediaId,
    primaryTranscriptId: primaryTranscriptId,
    targetLanguage: targetLanguage,
    primaryLines: primaryLines,
  );

  /// Writes one translated line into the AI track timeline.
  Future<void> updateAutoTranslateLineText({
    required String aiTranscriptId,
    required int lineIndex,
    required String text,
    String? sourceKey,
  }) => _updateAutoTranslateLineText(
    aiTranscriptId: aiTranscriptId,
    lineIndex: lineIndex,
    text: text,
    sourceKey: sourceKey,
  );

  /// Whether the AI track is out of sync with the current primary transcript.
  bool isAutoTranslateTrackStale({
    required TranscriptRow aiRow,
    required String primaryId,
    required List<TranscriptLine> primaryLines,
  }) => _isAutoTranslateTrackStale(
    aiRow: aiRow,
    primaryId: primaryId,
    primaryLines: primaryLines,
  );
}
