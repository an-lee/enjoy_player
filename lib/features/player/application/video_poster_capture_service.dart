/// Best-effort JPEG poster from [PlayerEngine.screenshot] for local video rows.
library;

import 'dart:async';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/utils/local_thumbnail.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/files/video_poster_extract.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';

final _log = logNamed('VideoPosterCapture');

class VideoPosterCaptureService {
  VideoPosterCaptureService(this._ref);

  final Ref _ref;

  void scheduleCapture({
    required String mediaId,
    required VideoRow video,
    required int restoredPositionMs,
    required int gen,
    required int Function() currentOpenGeneration,
    required String? Function() currentSessionMediaId,
    required double? Function() sessionDurationSeconds,
    required PlayerEngine activeEngine,
    required void Function(String absoluteThumbPath) onSessionThumbnail,
  }) {
    if (isRemoteThumbnailUrl(video.thumbnailUrl)) return;
    if (localThumbnailFile(video.thumbnailUrl) != null) return;

    unawaited(
      captureAndPersist(
        mediaId: mediaId,
        video: video,
        restoredPositionMs: restoredPositionMs,
        gen: gen,
        currentOpenGeneration: currentOpenGeneration,
        currentSessionMediaId: currentSessionMediaId,
        sessionDurationSeconds: sessionDurationSeconds,
        activeEngine: activeEngine,
        onSessionThumbnail: onSessionThumbnail,
      ),
    );
  }

  Future<void> captureAndPersist({
    required String mediaId,
    required VideoRow video,
    required int restoredPositionMs,
    required int gen,
    required int Function() currentOpenGeneration,
    required String? Function() currentSessionMediaId,
    required double? Function() sessionDurationSeconds,
    required PlayerEngine activeEngine,
    required void Function(String absoluteThumbPath) onSessionThumbnail,
  }) async {
    var soughtForPoster = false;
    try {
      // Opening at position 0 while echo is active makes the capture seek (and
      // the seek-back-to-zero below) fight the live enforcer: the seek is
      // corrected back into the echo window, so the wrong frame is captured and
      // playback is paused / churned right after open (issue #659). Skip — a
      // later open without echo still captures the poster.
      if (restoredPositionMs == 0 && _ref.read(echoModeProvider).active) return;

      await Future<void>.delayed(const Duration(milliseconds: 450));
      if (gen != currentOpenGeneration()) return;
      if (currentSessionMediaId() != mediaId) return;

      final sessionDur = sessionDurationSeconds();
      final durSec = video.durationSeconds > 0
          ? video.durationSeconds
          : (sessionDur != null && sessionDur > 0 ? sessionDur.floor() : 0);

      final posterSeconds = posterSeekSeconds(durSec > 0 ? durSec : null);
      final posterMs = (posterSeconds * 1000).round();

      final needSeekToPoster = restoredPositionMs == 0 && posterMs > 0;
      if (needSeekToPoster) {
        soughtForPoster = true;
        await activeEngine.seek(Duration(milliseconds: posterMs));
        await Future<void>.delayed(const Duration(milliseconds: 350));
        if (gen != currentOpenGeneration()) return;
        if (currentSessionMediaId() != mediaId) return;
      }

      final bytes = await activeEngine.screenshot(format: 'image/jpeg');
      if (bytes == null || bytes.isEmpty) return;
      if (gen != currentOpenGeneration()) return;

      final db = _ref.read(appDatabaseProvider);
      final latest = await db.videoDao.getById(mediaId);
      if (latest == null) return;
      if (isRemoteThumbnailUrl(latest.thumbnailUrl)) return;
      if (localThumbnailFile(latest.thumbnailUrl) != null) return;

      final outPath = await videoThumbnailPathForContentHash(
        posterStorageKeyHexForVideo(latest),
      );
      final f = File(outPath);
      await f.writeAsBytes(bytes, flush: true);
      final absoluteThumb = f.absolute.path;
      await db.videoDao.updateLocalThumbnail(mediaId, absoluteThumb);

      if (gen == currentOpenGeneration() &&
          currentSessionMediaId() == mediaId) {
        onSessionThumbnail(absoluteThumb);
      }
    } on Object catch (e, st) {
      _log.fine('video poster capture failed', e, st);
    } finally {
      if (soughtForPoster && gen == currentOpenGeneration()) {
        try {
          await activeEngine.seek(Duration.zero);
        } on Object catch (e, st) {
          _log.warning(
            'video poster capture failed to restore seek-zero position',
            e,
            st,
          );
        }
      }
    }
  }
}

/// Injectable [VideoPosterCaptureService] for [PlayerController].
final videoPosterCaptureServiceProvider = Provider<VideoPosterCaptureService>((
  ref,
) {
  return VideoPosterCaptureService(ref);
});
