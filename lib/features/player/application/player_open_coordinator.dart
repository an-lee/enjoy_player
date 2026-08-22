/// Orchestrates [PlayerController.openMedia] resolve → engine → session publish.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/playback_open_resolver.dart';
import 'package:enjoy_player/features/player/application/player_engine_binding.dart';
import 'package:enjoy_player/features/player/application/player_open_side_effects.dart';
import 'package:enjoy_player/features/player/application/player_position_tracker.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/application/video_poster_capture_service.dart';
import 'package:enjoy_player/features/player/domain/media_relocate_exception.dart';
import 'package:enjoy_player/features/player/domain/open_media_options.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';

final _openLog = logNamed('PlayerOpenCoordinator');

/// Host surface [runPlayerOpen] needs from [PlayerController].
abstract interface class PlayerOpenHost {
  int get openGeneration;
  bool isOpenStale(int gen);
  PlayerEngine get activeEngine;
  PlayerEngine? get ownedEngine;
  set ownedEngine(PlayerEngine? engine);
  PlaybackSession? get session;
  set session(PlaybackSession? next);
  PlayerPositionTracker get positionTracker;
}

Future<void> runPlayerOpen(
  PlayerOpenHost host,
  Ref ref,
  String mediaId, {
  OpenMediaOptions options = OpenMediaOptions.defaults,
}) async {
  final gen = host.openGeneration;

  final db = ref.read(appDatabaseProvider);
  final resolved = await resolvePlaybackOpen(db, mediaId);
  if (resolved == null) {
    // Do not silently succeed — ExpandedPlayerScreen would stay on the
    // loading skeleton forever (open completes, session never publishes).
    throw StateError('No playable source for media $mediaId');
  }
  if (host.isOpenStale(gen)) return;

  final video = resolved.video;
  final audio = resolved.audio;
  final kind = resolved.kind;
  final dexie = resolved.dexieTargetType;
  final title = resolved.title;
  final playable = resolved.playable;

  schedulePlayerOpenSideEffects(
    ref,
    openGeneration: gen,
    isStale: () => host.isOpenStale(gen),
    mediaId: mediaId,
    dexieTargetType: dexie,
  );

  await ensureEngineForPlayableSource(
    ref,
    playable: playable,
    openGeneration: gen,
    currentOpenGeneration: () => host.openGeneration,
    getOwnedEngine: () => host.ownedEngine,
    setOwnedEngine: (e) => host.ownedEngine = e,
  );
  if (host.isOpenStale(gen)) return;

  final engine = host.activeEngine;

  final thumb = resolved.thumbnailUrl;
  final language = resolved.language;
  final durationSec = resolved.durationSeconds;

  String? openPosterUrl;
  if (playable is YoutubePlayableSource) {
    openPosterUrl = remoteThumbnailForCard(
      thumb,
      youtubeVideoId: playable.videoId,
      mediaUrl: video?.mediaUrl,
    );
  }
  engine.markOpenTimingStart();
  engine.setPosterUrl(openPosterUrl);
  engine.warmVideoSurface();

  await host.positionTracker.cancel();

  await engine.open(playable);
  if (host.isOpenStale(gen)) {
    try {
      await engine.stop();
    } catch (_) {
      // Engine may have been disposed by a new open generation; best-effort.
    }
    return;
  }

  if (engine.supportsSubtitleDisabling) {
    await engine.disableRenderedSubtitles();
    if (host.isOpenStale(gen)) return;
  }

  await ref.read(playerPreferencesCtrlProvider.notifier).applyCurrentToEngine();
  if (host.isOpenStale(gen)) return;

  final persisted = await db.echoSessionDao.getLatestForTarget(dexie, mediaId);
  if (host.isOpenStale(gen)) return;

  final posMs = options.restorePosition ? (persisted?.currentTimeMs ?? 0) : 0;
  if (posMs > 0) {
    await engine.seek(Duration(milliseconds: posMs));
  }
  if (host.isOpenStale(gen)) return;

  if (options.restoreEcho && persisted != null && persisted.echoActive) {
    ref
        .read(echoModeProvider.notifier)
        .restoreFromSession(
          startLine: persisted.echoStartLine,
          endLine: persisted.echoEndLine,
          echoStartMs: persisted.echoStartMs ?? 0,
          echoEndMs: persisted.echoEndMs ?? 0,
        );
  } else {
    ref.read(echoModeProvider.notifier).deactivate();
  }
  ref
      .read(transcriptBlurModeProvider.notifier)
      .restoreFromSession(
        options.restoreEcho ? (persisted?.blurActive ?? false) : false,
      );
  if (host.isOpenStale(gen)) return;

  final now = DateTime.now();
  // [PlaybackSession.startedAt] is the wall-clock time this playback stint
  // began. It is set on every successful [openMedia] (including re-open after
  // [PlayerController.clear]); it is not preserved across clear → re-open.
  host.session = PlaybackSession(
    mediaId: mediaId,
    dexieTargetType: dexie,
    mediaType: kind.storageValue,
    mediaTitle: title,
    thumbnailUrl: thumb,
    durationSeconds: durationSec > 0 ? durationSec.toDouble() : posMs / 1000.0,
    currentTimeSeconds: posMs / 1000.0,
    currentSegmentIndex: options.restorePosition
        ? (persisted?.currentSegmentIndex ?? -1)
        : -1,
    language: language,
    startedAt: now,
    lastActiveAt: now,
  );

  if (host.isOpenStale(gen)) return;
  host.positionTracker.subscribe(
    openGeneration: gen,
    mediaId: mediaId,
    dexieTargetType: dexie,
    kind: kind,
    video: video,
    audio: audio,
  );

  if (playable is YoutubePlayableSource) {
    scheduleYoutubeMetadataRefresh(ref, mediaId: mediaId, openGeneration: gen);
  }

  if (kind == MediaKind.video &&
      video != null &&
      engine.supportsVideoPosterCapture) {
    ref
        .read(videoPosterCaptureServiceProvider)
        .scheduleCapture(
          mediaId: mediaId,
          video: video,
          restoredPositionMs: posMs,
          gen: gen,
          currentOpenGeneration: () => host.openGeneration,
          currentSessionMediaId: () => host.session?.mediaId,
          sessionDurationSeconds: () => host.session?.durationSeconds,
          activeEngine: engine,
          onSessionThumbnail: (path) {
            host.session = host.session?.copyWith(thumbnailUrl: path);
          },
        );
  }
}

Future<void> runPlayerOpenGuarded(
  PlayerOpenHost host,
  Ref ref,
  String mediaId, {
  required void Function() onFailureResetSession,
  OpenMediaOptions options = OpenMediaOptions.defaults,
}) async {
  try {
    await runPlayerOpen(host, ref, mediaId, options: options);
  } on MediaNeedsRelocateException catch (e, st) {
    onFailureResetSession();
    // Expected when a path-linked file moved — UI shows LocateMediaScreen.
    _openLog.info('openMedia needs relocate for $mediaId', e, st);
    rethrow;
  } on Object catch (e, st) {
    onFailureResetSession();
    _openLog.severe('openMedia failed for $mediaId', e, st);
    rethrow;
  }
}
