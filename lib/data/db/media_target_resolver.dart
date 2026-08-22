/// Resolve weapp-style `TargetType` from a library item id (video vs audio row).
library;

import 'dart:typed_data';

import 'package:enjoy_player/core/utils/youtube_video_identity.dart';
import 'package:enjoy_player/data/files/local_uri_trust.dart';
import 'package:enjoy_player/data/files/security_scoped_bookmark.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';

import 'app_database.dart';
import 'media_registry.dart';

Future<String?> dexieTargetTypeForId(AppDatabase db, String id) =>
    MediaRegistry(db).dexieTargetTypeForId(id);

/// Same resolution as [PlayerController.openMedia] — returns structured source.
Future<PlayableSource?> resolvePlayableSource(
  AppDatabase db,
  String mediaId,
) async {
  final video = await db.videoDao.getById(mediaId);
  final audio = video == null ? await db.audioDao.getById(mediaId) : null;
  if (video == null && audio == null) return null;

  if (video != null) {
    final ytId = youtubePlaybackVideoId(
      provider: video.provider,
      vid: video.vid,
      mediaUrl: video.mediaUrl,
      source: video.source,
    );
    if (ytId != null) {
      return YoutubePlayableSource(ytId);
    }
  }

  // Local-first (ADR-0013 / ADR-0050): prefer a trusted on-disk file over
  // metadata `mediaUrl`. Synced rows often keep both; opening an unplayable
  // remote URL while a good local file exists leaves the player stuck loading.
  final local = video?.localUri ?? audio?.localUri;
  final bookmark = video?.bookmarkData ?? audio?.bookmarkData;

  // If we have a macOS security-scoped bookmark, prefer the resolved
  // path it yields over the persisted [localUri] string — the file may
  // have moved between launches. [resolvePlayableSourceFromBookmark]
  // also starts the security-scoped access grant and returns a source
  // whose [LocalFilePlayableSource.scopeToken] must be released by the
  // engine before the next open / on dispose (ADR-0060).
  if (bookmark != null && bookmark.isNotEmpty) {
    final source = await resolvePlayableSourceFromBookmark(
      bookmark: bookmark,
      fallbackLocalUri: local,
      storedSize: video?.size ?? audio?.size,
      storedMtimeMs: video?.localMtimeMs ?? audio?.localMtimeMs,
    );
    if (source != null) return source;
    // Bookmark resolution failed (file gone, scope denied, etc.) — fall
    // through to the legacy localUri path below; if that also fails, the
    // outer caller will see a `MediaNeedsRelocateException` if the row
    // has a fingerprint, or `null` otherwise.
  }

  final trusted = await localUriTrusted(
    localUri: local,
    storedSize: video?.size ?? audio?.size,
    storedMtimeMs: video?.localMtimeMs ?? audio?.localMtimeMs,
  );
  if (trusted) {
    return LocalFilePlayableSource(local!);
  }
  final netUri = video?.mediaUrl ?? audio?.mediaUrl;
  if (netUri != null && netUri.isNotEmpty) {
    return RemoteUrlPlayableSource(netUri);
  }
  return null;
}

/// Same resolution as [PlayerController.openMedia] — for subtitle extraction, etc.
Future<String?> resolvePlayableSourceUri(AppDatabase db, String mediaId) async {
  final video = await db.videoDao.getById(mediaId);
  final audio = video == null ? await db.audioDao.getById(mediaId) : null;
  if (video == null && audio == null) return null;

  if (video != null) {
    final ytId = youtubePlaybackVideoId(
      provider: video.provider,
      vid: video.vid,
      mediaUrl: video.mediaUrl,
      source: video.source,
    );
    if (ytId != null) {
      return null;
    }
  }

  final local = video?.localUri ?? audio?.localUri;
  final bookmark = video?.bookmarkData ?? audio?.bookmarkData;

  // Mirror [resolvePlayableSource]'s preference: if we have a bookmark,
  // its resolved path is authoritative even when [local] has drifted.
  // We can't hold a security scope here (this is used by side-channel
  // consumers that don't manage the engine), so we only return the path —
  // callers should have already started a scope via [resolvePlayableSource]
  // if they need to read.
  if (bookmark != null && bookmark.isNotEmpty) {
    final resolved = await SecurityScopedBookmarkChannel.resolveBookmark(
      bookmark,
    );
    if (resolved != null) {
      // Release immediately; we have no engine here to own the token.
      await SecurityScopedBookmarkChannel.releaseBookmark(resolved.token);
      return resolved.path;
    }
  }

  final trusted = await localUriTrusted(
    localUri: local,
    storedSize: video?.size ?? audio?.size,
    storedMtimeMs: video?.localMtimeMs ?? audio?.localMtimeMs,
  );
  if (trusted) {
    return local;
  }
  final netUri = video?.mediaUrl ?? audio?.mediaUrl;
  if (netUri != null && netUri.isNotEmpty) {
    return netUri;
  }
  return null;
}

/// Resolves [bookmark] and starts the security-scoped access grant. When
/// resolution succeeds, returns a [LocalFilePlayableSource] whose
/// [LocalFilePlayableSource.scopeToken] must be released by the engine
/// before the next `open()` or on `dispose()`. When resolution fails,
/// returns `null` so the caller can fall back to the legacy [localUri]
/// path (or ultimately surface a `MediaNeedsRelocateException`).
Future<LocalFilePlayableSource?> resolvePlayableSourceFromBookmark({
  required Uint8List bookmark,
  required String? fallbackLocalUri,
  required int? storedSize,
  required int? storedMtimeMs,
}) async {
  final resolved = await SecurityScopedBookmarkChannel.resolveBookmark(
    bookmark,
  );
  if (resolved == null) return null;
  // Sanity-check the resolved path against the stored trust metadata
  // before handing it to media_kit. If the bookmark silently re-pointed
  // to a different file, we'd rather show the locate screen than play
  // unrelated bytes.
  final trusted = await localUriTrusted(
    localUri: resolved.path,
    storedSize: storedSize,
    storedMtimeMs: storedMtimeMs,
  );
  if (!trusted) {
    await SecurityScopedBookmarkChannel.releaseBookmark(resolved.token);
    return null;
  }
  return LocalFilePlayableSource(resolved.path, scopeToken: resolved.token);
}
