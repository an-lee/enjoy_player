/// Download owned cloud media to a temp file so FFmpeg stays local on every OS.
library;

import 'dart:io';

import 'package:forced_alignment/forced_alignment.dart';
import 'package:http/http.dart' as http;
import 'package:path/path.dart' as p;

import 'package:enjoy_player/core/logging/log.dart';

final _log = logNamed('audio.httpDownload');

/// Thrown when an HTTP(S) media URL cannot be materialized for FFmpeg.
final class HttpMediaDownloadException implements Exception {
  const HttpMediaDownloadException(this.message);
  final String message;

  @override
  String toString() => 'HttpMediaDownloadException($message)';
}

/// GET [url] to a unique temp file. Uses Dart HTTP (same TLS as the rest of
/// the app) so Android/iOS/macOS FFmpegKit and Windows/Linux CLI ffmpeg never
/// have to speak HTTPS themselves.
///
/// Returns the local file path. Caller must [deleteDownloadedHttpMedia].
Future<String> downloadHttpMediaToTemp(
  String url, {
  http.Client? client,
  AlignmentCancelToken? cancel,
}) async {
  final uri = Uri.tryParse(url);
  if (uri == null || !(uri.isScheme('http') || uri.isScheme('https'))) {
    throw HttpMediaDownloadException('not an HTTP(S) URL: $url');
  }
  if (cancel?.isCancelled ?? false) {
    throw const HttpMediaDownloadException('cancelled');
  }

  final ownedClient = client == null;
  final httpClient = client ?? http.Client();
  if (ownedClient) {
    cancel?.onCancel(httpClient.close);
  }

  Directory? dir;
  try {
    final request = http.Request('GET', uri);
    final response = await httpClient.send(request);
    if (cancel?.isCancelled ?? false) {
      throw const HttpMediaDownloadException('cancelled');
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw HttpMediaDownloadException(
        'download failed (${response.statusCode})',
      );
    }

    dir = await Directory.systemTemp.createTemp('enjoy_media_');
    final ext = p.extension(uri.path);
    final file = File(p.join(dir.path, 'media${ext.isEmpty ? '.bin' : ext}'));
    final sink = file.openWrite();
    try {
      await response.stream.pipe(sink);
    } finally {
      await sink.close();
    }
    if (cancel?.isCancelled ?? false) {
      throw const HttpMediaDownloadException('cancelled');
    }
    if (!file.existsSync() || file.lengthSync() <= 0) {
      throw const HttpMediaDownloadException('download was empty');
    }
    _log.info('downloaded ${file.lengthSync()} bytes for FFmpeg');
    return file.path;
  } on HttpMediaDownloadException {
    if (dir != null) {
      await _deleteTempDir(dir);
    }
    rethrow;
  } on Object catch (e, st) {
    _log.fine('HTTP media download failed', e, st);
    if (dir != null) {
      await _deleteTempDir(dir);
    }
    if (cancel?.isCancelled ?? false) {
      throw const HttpMediaDownloadException('cancelled');
    }
    throw HttpMediaDownloadException('download failed: $e');
  } finally {
    if (ownedClient) {
      httpClient.close();
    }
  }
}

/// Deletes the temp directory created by [downloadHttpMediaToTemp].
Future<void> deleteDownloadedHttpMedia(String path) async {
  await _deleteTempDir(File(path).parent);
}

Future<void> _deleteTempDir(Directory parent) async {
  try {
    if (!p.basename(parent.path).startsWith('enjoy_media_')) return;
    if (parent.existsSync()) {
      await parent.delete(recursive: true);
    }
  } on Object catch (_) {}
}
