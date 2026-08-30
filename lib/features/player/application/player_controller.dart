/// Owns [PlaybackSession] state and orchestrates [PlayerEngine] + side services.
library;

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/platform/linux_platform_availability.dart';
import 'package:enjoy_player/features/library/application/library_repository_provider.dart';
import 'package:enjoy_player/features/player/application/completion_loop.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_rev.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_open_coordinator.dart';
import 'package:enjoy_player/features/player/application/player_position_tracker.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/domain/echo_window.dart';
import 'package:enjoy_player/features/player/domain/open_media_options.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/domain/player_launch_request.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'open_media_provider.dart';
import 'playback_session_persister.dart';

part 'player_controller.g.dart';

/// Deterministic end-of-media completion loop (ADR-0044).
///
/// Mirrors the generation-counter + single-flight pattern from
/// [EchoEnforcer._epoch] / [_openGeneration]: the transport drives itself off
/// `await`ed completion futures instead of polling the position stream, and
/// every in-flight await captures a generation id so a stale completion from a
/// previous media (or a duplicate `completed` event from mpv) is a no-op.
@Riverpod(keepAlive: true)
class PlayerController extends _$PlayerController implements PlayerOpenHost {
  /// Real engine (null until first open, or [PlayerEngine] tests override).
  PlayerEngine? _ownedEngine;

  late final PlayerPositionTracker _positionTracker = PlayerPositionTracker(
    ref: ref,
    getEngine: () => activeEngine,
    getSession: () => state,
    setSession: (next) => state = next,
    currentOpenGeneration: () => _openGeneration,
  );

  /// Incremented on each [openMedia] call; stale async work bails out.
  int _openGeneration = 0;

  /// True between [openMedia] bumping [_openGeneration] and the session being
  /// published (or the open failing): `state` is still `null`, so this is the
  /// only signal that an engine swap is already coordinated and in flight.
  /// [warmYoutubeSurface] consults it — issue #657.
  bool _openInFlight = false;

  /// Deterministic end-of-media loop (ADR-0044). Owns the playback
  /// generation counter, the cancelable `completed` await, and the repeat
  /// decision — see [CompletionLoop].
  late final CompletionLoop _completionLoop = CompletionLoop(
    engine: () => activeEngine,
    activeMediaId: () => state?.mediaId,
    isDisposed: () => _disposed,
    repeatMode: () => ref.read(playerPreferencesCtrlProvider).repeatMode,
    echoSnapshot: () {
      final echo = ref.read(echoModeProvider);
      return (active: echo.active, startTimeSeconds: echo.startTimeSeconds);
    },
  );

  bool _disposed = false;

  /// Native (mpv) teardown future, captured so an explicit caller (tests, a
  /// future logout flow) can await disposal. Riverpod's `ref.onDispose` is
  /// synchronous and does NOT await it, so the keepAlive provider must not be
  /// invalidated without coordinating teardown (ADR-0003 / ADR-0015).
  Future<void> _teardown = Future<void>.value();

  Future<void> get teardown => _teardown;

  @override
  int get openGeneration => _openGeneration;

  @override
  bool isOpenStale(int gen) => gen != _openGeneration;

  @override
  PlayerEngine? get ownedEngine => _ownedEngine;

  @override
  set ownedEngine(PlayerEngine? engine) => _ownedEngine = engine;

  @override
  PlaybackSession? get session => state;

  @override
  set session(PlaybackSession? next) => state = next;

  @override
  PlayerPositionTracker get positionTracker => _positionTracker;

  @override
  PlayerEngine get activeEngine {
    final testDouble = ref.read(playerEngineTestDoubleProvider);
    if (testDouble != null) return testDouble;
    _ensureDefaultMediaKitEngine();
    return _ownedEngine!;
  }

  /// Allocates [MediaKitPlayerEngine] once when local/URL playback needs it.
  /// Kept out of [build] so YouTube-only opens and headless tests avoid
  /// [MediaKit.ensureInitialized] until a non-YouTube engine is required.
  void _ensureDefaultMediaKitEngine() {
    if (_ownedEngine != null) return;
    if (ref.read(playerEngineTestDoubleProvider) != null) return;
    _ownedEngine = MediaKitPlayerEngine();
    // Host watches [playerEngineRevProvider], not ownedEngine. Defer the bump
    // so we never notify during another provider's build.
    unawaited(
      Future<void>.microtask(() {
        if (_disposed) return;
        ref.read(playerEngineRevProvider.notifier).bump();
      }),
    );
  }

  PlayerEngine get engine => activeEngine;

  @override
  PlaybackSession? build() {
    // Captured here (not read inside onDispose) — Riverpod forbids Ref use
    // during life-cycles.
    final persister = ref.read(playbackSessionPersisterProvider);
    ref.onDispose(() {
      // Captured so [teardown] can be awaited; Riverpod itself does not await
      // onDispose, but the [_disposed] guard makes re-entrant disposal a no-op
      // and the sequenced awaits keep mpv teardown off the hot path.
      _teardown = _disposeResources(persister);
    });

    return null;
  }

  /// Sequenced, reentrancy-guarded teardown: cancel persistence, the position
  /// tracker (which resets echo enforcement), the completion loop, then the
  /// owned engine. Safe to call more than once.
  Future<void> _disposeResources(PlaybackSessionPersister persister) async {
    if (_disposed) return;
    _disposed = true;
    _completionLoop.bump();
    persister.cancel();
    await _positionTracker.cancel();
    await _ownedEngine?.dispose();
  }

  Future<void> relocateAndOpen(String mediaId, XFile picked) async {
    final lib = ref.read(mediaLibraryRepositoryProvider);
    await lib.relocateLocalFile(mediaId: mediaId, picked: picked);
    state = null;
    await openMedia(mediaId);
    ref.invalidate(openMediaActionProvider(mediaId));
    ref.invalidate(
      openMediaLaunchProvider(PlayerLaunchRequest(mediaId: mediaId)),
    );
  }

  Future<void> openMedia(
    String mediaId, {
    OpenMediaOptions options = OpenMediaOptions.defaults,
  }) async {
    if (state?.mediaId == mediaId) {
      // Same media already open — still honor explicit launches that must
      // clear restored echo before the caller seeks.
      if (!options.restoreEcho) {
        ref.read(echoModeProvider.notifier).deactivate();
      }
      // Still bump library updatedAt so Home "Recent media" reflects this open.
      unawaited(
        ref.read(mediaLibraryRepositoryProvider).touchMediaUpdatedAt(mediaId),
      );
      return;
    }

    final gen = ++_openGeneration;
    // Marked before the first await so a speculative [warmYoutubeSurface] that
    // lands inside this window sees the open that is already coordinating the
    // engine (issue #657).
    _openInFlight = true;
    _completionLoop.bump();

    try {
      await runPlayerOpenGuarded(
        this,
        ref,
        mediaId,
        options: options,
        onFailureResetSession: () {
          if (gen == _openGeneration) {
            state = null;
          }
        },
      );
    } finally {
      // Only a still-current open clears the flag — an open superseded by a
      // newer one must not report "idle" while that newer one is still running.
      if (gen == _openGeneration) {
        _openInFlight = false;
      }
    }

    // Start the deterministic completion loop for the new playback stint
    // (ADR-0044). Only when the open actually landed (state's mediaId matches
    // and the generation is still current).
    if (!_disposed && gen == _openGeneration && state?.mediaId == mediaId) {
      _completionLoop.arm();
      // Promote to Home "Recent media" even if playback is still starting.
      unawaited(
        ref.read(mediaLibraryRepositoryProvider).touchMediaUpdatedAt(mediaId),
      );
    }
  }

  Future<void> seekTo(
    Duration target, {
    EchoWindow? echoWindowForSeekClamp,
  }) async {
    // Invalidate any in-flight completion await so a stale `completed` event
    // from mpv (fired before the seek took effect) cannot trigger a stray
    // repeat/advance (ADR-0044 edge case).
    _completionLoop.bump();
    final echo = ref.read(echoModeProvider);
    final seconds = secondsFromDuration(target);
    final routing = decideSeekRouting(echoActive: echo.active);
    switch (routing) {
      case SeekThroughEcho():
        await _positionTracker.echoEnforcer.clampAndSeek(
          seconds,
          override: echoWindowForSeekClamp,
        );
      case SeekDirect():
        await activeEngine.seek(durationFromSeconds(seconds));
    }
    // Re-arm the completion loop for the post-seek playback stint.
    _completionLoop.arm();
  }

  Future<void> seekToSeconds(
    double seconds, {
    EchoWindow? echoWindowForSeekClamp,
  }) async {
    await seekTo(
      durationFromSeconds(seconds),
      echoWindowForSeekClamp: echoWindowForSeekClamp,
    );
  }

  Future<void> togglePlay() async {
    await activeEngine.playOrPause();
    // Re-arm the loop in case playback was resumed from a completed state
    // (no-op if the loop is already active).
    _completionLoop.arm();
  }

  Future<void> play() async {
    await activeEngine.play();
    // If the completion loop has ended (e.g. RepeatMode.none and the media
    // completed), start a fresh loop so repeat/stop behavior is active for the
    // new playback stint (ADR-0044).
    _completionLoop.arm();
  }

  Future<void> clear({bool keepVideoSurface = false}) async {
    _completionLoop.bump();
    await _positionTracker.cancel();

    final current = state;
    final persister = ref.read(playbackSessionPersisterProvider);
    if (current != null) {
      await persister.flush(
        mediaId: current.mediaId,
        dexieTargetType: current.dexieTargetType,
        session: current,
      );
    } else {
      persister.cancel();
    }

    _openGeneration++;
    // Clear invalidates any open still in flight, so drop the flag too — that
    // open's `finally` skips the reset (its generation is stale) and the latch
    // would otherwise disable speculative warming for the rest of the session
    // (issue #657).
    _openInFlight = false;

    final engine = activeEngine;

    ref.read(echoModeProvider.notifier).deactivate();
    ref.read(transcriptBlurModeProvider.notifier).deactivate();
    state = null;

    // WebView engines idle and keep their process alive across clear; native
    // engines stop — the policy lives behind the engine seam (issue #595).
    await engine.teardownAfterClear(keepSurfaceMounted: keepVideoSurface);
  }

  void warmYoutubeSurface() {
    if (ref.read(playerEngineTestDoubleProvider) != null) return;
    // ADR-0048: on Linux the YouTube engine has no inappwebview backend and
    // can never mount — do not install or warm it from feed scrolling.
    if (youTubeEngineOptedOutHere) return;
    // Issue #657: warming is best-effort pre-work for a *possible* YouTube
    // open, so it must never disturb a live engine. Disposing MediaKit outside
    // the open path wedges the native mpv event pump (every later open then
    // hangs on the loading skeleton), and swapping `_ownedEngine` while an open
    // is in flight replaces the engine that open is about to drive — without
    // generation coordination there is nothing to undo it.
    if (_disposed || state != null || _openInFlight) return;

    final owned = _ownedEngine;
    if (owned != null && owned.supportsYouTubePlayback) {
      owned.warmVideoSurface();
      return;
    }
    if (owned != null) {
      // An idle MediaKit engine (cleared session, parked surface) is still
      // alive. Keep it — only the open path swaps engines, and it does so with
      // generation coordination ([ensureEngineForPlayableSource]). A
      // speculative warm that disposed mpv here would buy a WebView we may
      // never use and leave the next local open rebuilding against a wedged
      // pump (2026-08-29 field report).
      return;
    }
    // Genuinely no engine yet — install the YouTube one. Bump before warming
    // (ADR-0057) so PlayerSurfaceHost keys a stage for the new engine.
    _ownedEngine = YoutubePlayerEngine();
    ref.read(playerEngineRevProvider.notifier).bump();
    _ownedEngine!.warmVideoSurface();
  }

  void abandonPendingOpen() {
    _openGeneration++;
    _completionLoop.bump();
  }

  /// Called by [PlayerMetadataService] after lazy title/thumbnail refresh.
  void applySessionPatch(PlaybackSession patched) {
    if (state?.mediaId != patched.mediaId) return;
    state = patched;
  }
}
