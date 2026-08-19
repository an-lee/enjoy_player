/// Owns [PlaybackSession] state and orchestrates [PlayerEngine] + side services.
library;

import 'dart:async';

import 'package:cross_file/cross_file.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/library/application/library_repository_provider.dart';
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
import 'package:enjoy_player/features/player/domain/player_settings.dart';
import 'package:enjoy_player/features/player/domain/transport_decisions.dart';
import 'package:enjoy_player/features/transcript/application/transcript_blur_mode_provider.dart';
import 'open_media_provider.dart';
import 'playback_session_persister.dart';

part 'player_controller.g.dart';

final _log = logNamed('PlayerController');

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

  /// Incremented on every event that invalidates the current playback stint
  /// (openMedia, clear, abandonPendingOpen, user seek). The completion loop
  /// captures this at start and re-checks after every `await` — a stale
  /// completion that observes `gen != _playbackGen` is a no-op (ADR-0044).
  int _playbackGen = 0;

  /// Completer used to cancel the in-flight `completed.first` await when the
  /// generation changes under the loop. Created per-iteration, completed by
  /// [_bumpPlaybackGen], and cleared after the await resolves.
  Completer<void>? _completionCancel;

  /// True while the completion loop is between its top-of-loop gen check and a
  /// `return`. Used by [play] to know whether to start a fresh loop after the
  /// user manually resumes from a completed (RepeatMode.none) media.
  bool _completionLoopActive = false;

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
    _bumpPlaybackGen();
    persister.cancel();
    await _positionTracker.cancel();
    await _ownedEngine?.dispose();
  }

  // ── Deterministic completion loop (ADR-0044) ──────────────────────────────

  /// Bumps [_playbackGen] and cancels any in-flight completion await. Called
  /// on openMedia, clear, abandonPendingOpen, user seek, and disposal — every
  /// event that invalidates "the current playback stint."
  void _bumpPlaybackGen() {
    _playbackGen++;
    _cancelCompletionAwait();
  }

  void _cancelCompletionAwait() {
    final c = _completionCancel;
    _completionCancel = null;
    if (c != null && !c.isCompleted) c.complete();
  }

  /// Starts (or restarts) the completion loop for the current playback stint.
  /// Safe to call unconditionally — if a loop is already running for the
  /// current generation it is a no-op.
  void _startCompletionLoop() {
    if (_disposed) return;
    if (state == null) return;
    if (_completionLoopActive) return;
    unawaited(_runCompletionLoop(_playbackGen));
  }

  /// The deterministic await-completion playback loop.
  ///
  /// Waits for `engine.completed` to fire, then applies the current
  /// [RepeatMode]:
  /// - [RepeatMode.none] — stop the loop (media is at the end; user can
  ///   manually press play to restart).
  /// - [RepeatMode.single] — seek to zero, play, re-await.
  /// - [RepeatMode.segment] — seek to the echo window start, play, re-await.
  ///   Falls back to [RepeatMode.none] when echo is not active.
  ///
  /// Every `await` is followed by a generation re-check so a stale completion
  /// (media switched, user seeked, controller disposed) is a silent no-op.
  Future<void> _runCompletionLoop(int gen) async {
    _completionLoopActive = true;
    try {
      while (gen == _playbackGen && !_disposed) {
        final session = state;
        if (session == null) return;
        if (session.mediaId != state?.mediaId) return;

        final completed = await _awaitCompletionOrCancel(gen);
        if (!completed || gen != _playbackGen || _disposed) return;
        if (state?.mediaId != session.mediaId) return;

        final repeat = ref.read(playerPreferencesCtrlProvider).repeatMode;
        _log.fine('completion fired for ${session.mediaId}; repeat=$repeat');
        switch (repeat) {
          case RepeatMode.none:
            return;
          case RepeatMode.single:
            await _replayFrom(Duration.zero, gen);
            if (gen != _playbackGen || _disposed) return;
          case RepeatMode.segment:
            final echo = ref.read(echoModeProvider);
            if (!echo.active) return;
            await _replayFrom(durationFromSeconds(echo.startTimeSeconds), gen);
            if (gen != _playbackGen || _disposed) return;
        }
      }
    } finally {
      if (gen == _playbackGen) _completionLoopActive = false;
    }
  }

  /// Seeks to [target] and resumes playback after end-of-media. For the
  /// YouTube engine, the internal `playbackCompleted` flag is reset first so
  /// `play()` drives the `<video>` directly instead of reloading the watch
  /// page (which would discard the seek). Late generation changes are caught
  /// by the caller's post-await re-check.
  Future<void> _replayFrom(Duration target, int gen) async {
    final engine = activeEngine;
    if (engine is YoutubePlayerEngine) {
      engine.resetCompletionFlag();
    }
    await engine.seek(target);
    if (gen != _playbackGen || _disposed) return;
    await engine.play();
  }

  /// Races `engine.completed.first` against a cancellation completer that is
  /// completed by [_bumpPlaybackGen]. Returns `true` on real completion,
  /// `false` on cancel / stream close.
  Future<bool> _awaitCompletionOrCancel(int gen) async {
    final engine = activeEngine;
    final completer = Completer<bool>();
    late StreamSubscription<void> sub;

    _completionCancel = Completer<void>();
    final cancel = _completionCancel!;

    void resolve(bool value) {
      if (!completer.isCompleted) completer.complete(value);
    }

    sub = engine.completed.listen(
      (_) => resolve(true),
      onDone: () => resolve(false),
      onError: (Object _, StackTrace _) => resolve(false),
    );

    unawaited(cancel.future.then((_) => resolve(false)));

    try {
      return await completer.future;
    } finally {
      _completionCancel = null;
      await sub.cancel();
    }
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
    _bumpPlaybackGen();

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

    // Start the deterministic completion loop for the new playback stint
    // (ADR-0044). Only when the open actually landed (state's mediaId matches
    // and the generation is still current).
    if (!_disposed && gen == _openGeneration && state?.mediaId == mediaId) {
      _startCompletionLoop();
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
    _bumpPlaybackGen();
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
    _startCompletionLoop();
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
    _startCompletionLoop();
  }

  Future<void> play() async {
    await activeEngine.play();
    // If the completion loop has ended (e.g. RepeatMode.none and the media
    // completed), start a fresh loop so repeat/stop behavior is active for the
    // new playback stint (ADR-0044).
    _startCompletionLoop();
  }

  Future<void> clear({bool keepVideoSurface = false}) async {
    _bumpPlaybackGen();
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

    final engine = activeEngine;
    final ownedEngine = _ownedEngine;
    final isYoutubeEngine =
        ref.read(playerEngineTestDoubleProvider) == null &&
        ownedEngine is YoutubePlayerEngine;

    ref.read(echoModeProvider.notifier).deactivate();
    ref.read(transcriptBlurModeProvider.notifier).deactivate();
    state = null;

    final teardown = decideTeardownPath(isYoutubeEngine: isYoutubeEngine);
    final ytEngine = ownedEngine is YoutubePlayerEngine ? ownedEngine : null;
    switch (teardown) {
      case TeardownIdle():
        await ytEngine!.idleAfterClear(keepMounted: keepVideoSurface);
      case TeardownStop():
        await engine.stop();
    }
  }

  void warmYoutubeSurface() {
    if (ref.read(playerEngineTestDoubleProvider) != null) return;
    final owned = _ownedEngine;
    if (owned is YoutubePlayerEngine) {
      owned.warmVideoSurface();
      return;
    }
    // Swap + bump first (ADR-0057) so PlayerSurfaceHost drops the old stage
    // before the previous engine is disposed.
    _ownedEngine = YoutubePlayerEngine(
      repeatMode: () => ref.read(playerPreferencesCtrlProvider).repeatMode,
    );
    ref.read(playerEngineRevProvider.notifier).bump();
    if (owned != null) {
      unawaited(owned.dispose());
    }
    _ownedEngine!.warmVideoSurface();
  }

  void abandonPendingOpen() {
    _openGeneration++;
    _bumpPlaybackGen();
  }

  /// Called by [PlayerMetadataNotifier] after lazy title/thumbnail refresh.
  void applySessionPatch(PlaybackSession patched) {
    if (state?.mediaId != patched.mediaId) return;
    state = patched;
  }
}
