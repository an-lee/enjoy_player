/// Crafted Audio Cloud Sync: uploads crafted audio binaries to cloud
/// storage so the same audio is playable from any signed-in device.
///
/// Mirrors the web app's `attachMediaBlobToPayload` flow
/// (`~/projects/enjoy/apps/web/src/db/services/sync-upload-helpers.ts:72`).
/// Only acts on rows where `provider == 'craft'`. Imported user files and
/// YouTube downloads are explicitly skipped.
library;

import 'dart:typed_data';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/api/services/direct_uploads_api.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/file_storage.dart';

final _log = logNamed('craft.cloud_upload');

/// MIME type for a [fileUri] by extension. Defaults to `audio/mpeg`.
String _contentTypeFor(String fileUri) {
  final lower = fileUri.toLowerCase();
  if (lower.endsWith('.wav')) return 'audio/wav';
  if (lower.endsWith('.mp3')) return 'audio/mpeg';
  if (lower.endsWith('.m4a') || lower.endsWith('.mp4')) return 'audio/mp4';
  if (lower.endsWith('.ogg')) return 'audio/ogg';
  if (lower.endsWith('.flac')) return 'audio/flac';
  return 'audio/mpeg';
}

/// Extension (without the leading dot) for a [fileUri]. Defaults to `mp3`.
String _extensionFor(String fileUri) {
  final dot = fileUri.lastIndexOf('.');
  if (dot == -1 || dot == fileUri.length - 1) return 'mp3';
  return fileUri.substring(dot + 1);
}

/// Encapsulates "upload the bytes for a crafted audio row to cloud
/// storage and return the Active Storage `signedId`".
///
/// Idempotent:
/// - Returns `null` for non-crafted rows.
/// - Returns `null` when the row already has a populated `mediaUrl`.
/// - Returns `null` when the local file cannot be read.
///
/// Caller (typically [SyncUploadService]) sends the returned `signedId`
/// in the JSON payload of `POST /api/v1/mine/audios` so the server can
/// attach the blob to the audio model and persist a `mediaUrl`.
class CraftAudioCloudUploader {
  CraftAudioCloudUploader({
    required this._fileStorage,
    required this._directUploadsApi,
  });

  final FileStorage _fileStorage;
  final DirectUploadsApi _directUploadsApi;

  /// Reads the row's app-managed [AudioRow.localUri] off the main isolate
  /// and uploads the bytes to Active Storage via a direct-upload dance.
  ///
  /// Returns the `signedId` on success; `null` when nothing should be
  /// uploaded (non-crafted, already synced, missing local file, zero-byte
  /// file, etc.).
  ///
  /// Rethrows any [Object] thrown by [DirectUploadsApi.uploadBlob] so the
  /// sync queue can retry the upload on the next drain. Without this, a
  /// transient network failure during the direct-upload POST would leave
  /// the row stamped `syncStatus: 'synced'` by the subsequent metadata
  /// upload, never retrying the binary upload — and other devices would
  /// never receive the crafted audio (see ADR-0081 §Consequences).
  Future<String?> uploadIfNeeded(AudioRow row) async {
    if (row.provider != 'craft') return null;
    if (row.localUri == null || row.localUri!.isEmpty) return null;
    if (row.mediaUrl != null && row.mediaUrl!.isNotEmpty) return null;

    final mediaId = row.id;
    final sizeBytes = row.size ?? 0;
    _log.fine(
      () =>
          'craft_audio_upload_attempt media_id=$mediaId '
          'size_bytes=$sizeBytes md5=${row.md5 ?? "<none>"}',
    );

    final Uint8List? bytes;
    try {
      bytes = await _fileStorage.readAppManagedMedia(row.localUri);
    } on Object catch (e, st) {
      _log.warning(
        () =>
            'craft_audio_upload_failure media_id=$mediaId '
            'error=read_failed will_retry=${row.syncStatus == "pending"}',
        e,
        st,
      );
      return null;
    }
    if (bytes == null) {
      _log.fine(
        () =>
            'craft_audio_upload_skipped media_id=$mediaId reason=missing_local',
      );
      return null;
    }
    if (bytes.isEmpty) {
      _log.fine(
        () => 'craft_audio_upload_skipped media_id=$mediaId reason=zero_length',
      );
      return null;
    }

    final ext = _extensionFor(row.localUri!);
    final contentType = _contentTypeFor(row.localUri!);
    final md5Prefix = (row.md5 != null && row.md5!.isNotEmpty)
        ? row.md5!.substring(0, row.md5!.length < 8 ? row.md5!.length : 8)
        : 'unknown';
    final filename = 'craft-$md5Prefix.$ext';

    final stopwatch = Stopwatch()..start();
    final signedId = await _directUploadsApi.uploadBlob(
      bytes: bytes,
      filename: filename,
      contentType: contentType,
    );
    stopwatch.stop();
    _log.info(
      () =>
          'craft_audio_upload_success media_id=$mediaId '
          'duration_ms=${stopwatch.elapsedMilliseconds} '
          'signed_id=${_shorten(signedId)}',
    );
    return signedId;
  }

  static String _shorten(String signedId) {
    if (signedId.length <= 12) return signedId;
    return '${signedId.substring(0, 6)}…${signedId.substring(signedId.length - 4)}';
  }
}
