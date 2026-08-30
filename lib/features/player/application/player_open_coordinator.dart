/// Orchestrates [PlayerController.openMedia] resolve → engine → session publish.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/platform/linux_platform_availability.dart';
import 'package:enjoy_player/core/utils/remote_thumbnail_url.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_constants.dart';
import 'package:enjoy_player/features/player/application/playback_open_resolver.dart';
import 'package:enjoy_player/features/player/application/playback_session_persister.dart';
import 'package:enjoy_player/features/player/application/player_engine_binding.dart';
import 'package:enjoy_player/features/player/application/player_open_side_effects.dart';
import 'package:enjoy_player/features/player/application/player_position_tracker.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/application/video_poster_capture_service.dart';
import 'package:enjoy_player/features/player/domain/media_relocate_exception.dart';
import 'package:enjoy_player/features/player/domain/open_media_options.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/domain/youtube_playback_unavailable_exception.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';

final _openLog = logNamed('PlayerOpenCoordinator');

/// Runs [step] bounded by [limit]; a timeout is logged and swallowed so a
/// wedged engine command cannot hold the open (and the loading screen)
/// hostage.
Future<void> runBoundedEngineStep(
  String what,
  Future<void> Function() step, {
  Duration limit = kEngineCommandTimeout,
  void Function(String message)? logWarning,
}) async {
  final warn = logWarning ?? _openLog.warning;
  try {
    await step().timeout(limit);
  } on TimeoutException {
    warn(
      '$what timed out after $limit (engine event pump wedged?); '
      'continuing without it',
    );
  }
}

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
  Duration openTimeout = kEngineOpenTimeout,
  Duration engineCommandTimeout = kEngineCommandTimeout,
}) async {
  final gen = host.openGeneration;

  // Flush the previous media's pending debounced write while its echo/blur
  // state is still live in the providers. The restore below replaces that
  // state with the NEW media's values; a stale debounce/max-age timer firing
  // afterwards would write the new media's echo window + blur flag into the
  // old media's row (issue #653).
  final previous = host.session;
  final persister = ref.read(playbackSessionPersisterProvider);
  if (previous != null) {
    try {
      await persister.flush(
        mediaId: previous.mediaId,
        dexieTargetType: previous.dexieTargetType,
        session: previous,
      );
    } catch (e, st) {
      // Best-effort: opening the new media must not fail because the
      // previous media's trailing position write hit the DB.
      _openLog.warning('flushing previous playback session failed', e, st);
    }
  } else {
    persister.cancel();
  }

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

  // ADR-0048: Linux has no YouTube WebView backend, so the open can never
  // proceed. Fail with the typed exception BEFORE any engine swap — the
  // swap would dispose the live MediaKit engine (and its native mpv
  // player) to install a YouTube engine that can never mount, and after it
  // every later local/URL open rebuilds MediaKit against a wedged native
  // event pump: `engine.open` never completes and the player screen stays
  // on the loading skeleton forever (2026-08-29 field report).
  if (playable is YoutubePlayableSource && youTubeEngineOptedOutHere) {
    throw const YouTubePlaybackUnavailableException.linuxOptedOut();
  }

  schedulePlayerOpenSideEffects(
    ref,
    openGeneration: gen,
    isStale: () => host.isOpenStale(gen),
    mediaId: mediaId,
    dexieTargetType: dexie,
  );

  // Drop position listeners before the swap so YouTube closeStreams is
  // not blocked by the tracker still subscribed to the old engine.
  await host.positionTracker.cancel();

  // The swap waits for surface detach, then fire-and-forgets old dispose.
  // Do not wrap it in [engineCommandTimeout] — that would cut off
  // [prepareNativeBackend] and leave MediaKit allocating mpv while the
  // YouTube WebView is still destroying.
  final swapped = await ensureEngineForPlayableSource(
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

  // After a YouTube → MediaKit swap the first `open` races WebView
  // teardown and can hang (2026-08-30: skeleton until back + reopen).
  // Use the short command ceiling for that first attempt, then retry
  // once — reopen works because the native side has settled / a fresh
  // player is installed. A timeout must not fail the open on try 1.
  final firstTimeout = swapped ? engineCommandTimeout : openTimeout;
  try {
    await engine.open(playable).timeout(firstTimeout);
  } on TimeoutException {
    _openLog.warning(
      'engine.open timed out after $firstTimeout for media $mediaId '
      '(${engine.runtimeType}); retrying once',
    );
    await replaceWedgedLocalEngine(
      ref,
      getOwnedEngine: () => host.ownedEngine,
      setOwnedEngine: (e) => host.ownedEngine = e,
    );
    if (host.isOpenStale(gen)) return;
    final retryEngine = host.activeEngine;
    try {
      await retryEngine.open(playable).timeout(openTimeout);
    } on TimeoutException {
      _openLog.severe(
        'engine.open retry timed out after $openTimeout for media $mediaId '
        '(${retryEngine.runtimeType}); invalidating open generation',
      );
      ref.read(playerControllerProvider.notifier).abandonPendingOpen();
      rethrow;
    }
  }
  if (host.isOpenStale(gen)) {
    try {
      await engine.stop();
    } catch (_) {
      // Engine may have been disposed by a new open generation; best-effort.
    }
    return;
  }

  if (engine.supportsSubtitleDisabling) {
    await runBoundedEngineStep(
      'disableRenderedSubtitles',
      engine.disableRenderedSubtitles,
      limit: engineCommandTimeout,
    );
    if (host.isOpenStale(gen)) return;
  }

  await runBoundedEngineStep(
    'applyCurrentToEngine',
    () =>
        ref.read(playerPreferencesCtrlProvider.notifier).applyCurrentToEngine(),
    limit: engineCommandTimeout,
  );
  if (host.isOpenStale(gen)) return;

  final persisted = await db.echoSessionDao.getLatestForTarget(dexie, mediaId);
  if (host.isOpenStale(gen)) return;

  final posMs = options.restorePosition ? (persisted?.currentTimeMs ?? 0) : 0;
  if (posMs > 0) {
    await runBoundedEngineStep(
      'position restore seek',
      () => engine.seek(Duration(milliseconds: posMs)),
      limit: engineCommandTimeout,
    );
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
