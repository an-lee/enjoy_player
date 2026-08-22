/// One seam over the `videos` / `audios` table split (issue #593).
///
/// The library persists media in two sibling tables, but callers think in
/// terms of a single `Media`. [MediaRegistry] hides the video-then-audio
/// probe and the row→[Media] mapping so the branch exists once — callers and
/// tests cross the same interface instead of re-probing both DAOs (ADR-0002
/// keeps the queries in the data layer).
library;

import 'package:enjoy_player/features/library/domain/media.dart';

import 'app_database.dart';

/// Maps a [VideoRow] to the UI-facing domain [Media].
Media mediaFromVideo(VideoRow row) => mediaFromLibraryRow(
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
  syncStatus: row.syncStatus,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
);

/// Maps an [AudioRow] to the UI-facing domain [Media].
Media mediaFromAudio(AudioRow row) => mediaFromLibraryRow(
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
  syncStatus: row.syncStatus,
  createdAt: row.createdAt,
  updatedAt: row.updatedAt,
);

Media mediaFromLibraryRow({
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
  String? syncStatus,
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
    syncStatus: syncStatus,
    createdAt: createdAt,
    updatedAt: updatedAt,
  );
}

/// Unified lookup over the `videos` / `audios` split.
///
/// Video wins when the same id exists in both tables (defensive; production
/// never inserts one id into both — see `media_target_resolver_test.dart`).
class MediaRegistry {
  const MediaRegistry(this._db);

  final AppDatabase _db;

  Future<({VideoRow? video, AudioRow? audio})> _probe(String id) async {
    final video = await _db.videoDao.getById(id);
    final audio = video == null ? await _db.audioDao.getById(id) : null;
    return (video: video, audio: audio);
  }

  /// The media with [id] as a domain [Media], or `null` when neither table
  /// holds it.
  Future<Media?> getById(String id) async {
    final hit = await _probe(id);
    final video = hit.video;
    if (video != null) return mediaFromVideo(video);
    final audio = hit.audio;
    if (audio != null) return mediaFromAudio(audio);
    return null;
  }

  /// Which table holds [id], or `null` when neither does.
  Future<MediaKind?> kindOf(String id) async {
    final hit = await _probe(id);
    if (hit.video != null) return MediaKind.video;
    if (hit.audio != null) return MediaKind.audio;
    return null;
  }

  /// Weapp / Dexie `TargetType` for [id] (`'Video'` | `'Audio'`), or `null`.
  Future<String?> dexieTargetTypeForId(String id) async =>
      (await kindOf(id))?.dexieTargetType;

  /// The on-disk `localUri` of the row holding [id], or `null` when the row
  /// is missing or has no local file reference.
  Future<String?> localUriOf(String id) async {
    final hit = await _probe(id);
    return hit.video?.localUri ?? hit.audio?.localUri;
  }
}
