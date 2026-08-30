/// Debounced persistence of playback position + echo fields to [EchoSessionDao].
library;

import 'dart:async';

import 'package:drift/drift.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/logging/log.dart';
import '../../../data/db/app_database.dart';
import '../../../data/db/app_database_provider.dart';
import '../../transcript/application/transcript_blur_mode_provider.dart';
import '../domain/echo_window.dart';
import '../domain/playback_session.dart';
import 'echo_mode_provider.dart';

final _persisterLog = logNamed('PlaybackSessionPersister');

/// Debounce window for coalescing rapid position updates into one DB write.
const int kPlaybackSessionDebounceMs = 450;

/// Upper bound on how long a position update can stay unwritten, regardless of
/// debounce. The position tracker emits on a 400 ms grid, so at 1× the 450 ms
/// debounce would otherwise be re-armed forever and never fire during
/// continuous playback — and at 2× the emit cadence (200 ms) is even faster.
/// Forcing a flush once pending data is older than this guarantees a crash
/// never loses more than ~2 s of progress (issue #280, P9).
const int kMaxPendingPositionAgeMs = 2000;

class PlaybackSessionPersister {
  PlaybackSessionPersister(this._ref);

  final Ref _ref;
  Timer? _debounce;

  /// When the current run of pending (unflushed) updates started, or `null`
  /// when nothing is pending. Drives the max-age forced flush.
  DateTime? _pendingSince;

  /// Schedules a write using [session] for timing fields and **fresh** echo state
  /// at flush time (avoids echo segment reverting in DB when debounce captures a
  /// snapshot from before [EchoMode.activate], e.g. after tapping another cue).
  ///
  /// Coalesces rapid updates with a [kPlaybackSessionDebounceMs] debounce, but
  /// forces a flush once pending data is older than [kMaxPendingPositionAgeMs]
  /// so progress survives a mid-playback crash at any playback rate.
  void schedule({
    required String mediaId,
    required String dexieTargetType,
    required PlaybackSession session,
  }) {
    final now = DateTime.now();
    _pendingSince ??= now;
    final pendingForMs = now.difference(_pendingSince!).inMilliseconds;
    if (pendingForMs >= kMaxPendingPositionAgeMs) {
      _debounce?.cancel();
      _debounce = null;
      _pendingSince = null;
      unawaited(
        _flushGuarded(
          mediaId: mediaId,
          dexieTargetType: dexieTargetType,
          session: session,
        ),
      );
      return;
    }

    _debounce?.cancel();
    _debounce = Timer(
      const Duration(milliseconds: kPlaybackSessionDebounceMs),
      () {
        _debounce = null;
        _pendingSince = null;
        unawaited(
          _flushGuarded(
            mediaId: mediaId,
            dexieTargetType: dexieTargetType,
            session: session,
          ),
        );
      },
    );
  }

  /// Flushes any pending debounced write synchronously (best-effort).
  ///
  /// [PlayerController.clear] calls this before [cancel] so swipe-to-dismiss
  /// does not lose the last 450 ms of position updates. `runPlayerOpen` calls
  /// it for the previous session before the new media's echo/blur restore
  /// overwrites the live providers, so a stale timer cannot write the new
  /// media's echo window into the old media's row (issue #653).
  Future<void> flush({
    required String mediaId,
    required String dexieTargetType,
    required PlaybackSession session,
  }) async {
    final timer = _debounce;
    if (timer == null) return;
    timer.cancel();
    _debounce = null;
    _pendingSince = null;
    await _flush(
      mediaId: mediaId,
      dexieTargetType: dexieTargetType,
      session: session,
    );
  }

  /// Cancels any pending debounce and writes [session] (+ fresh echo/blur)
  /// immediately. Used when practice toggles must survive a quick media switch.
  Future<void> writeNow({
    required String mediaId,
    required String dexieTargetType,
    required PlaybackSession session,
  }) async {
    _debounce?.cancel();
    _debounce = null;
    _pendingSince = null;
    await _flush(
      mediaId: mediaId,
      dexieTargetType: dexieTargetType,
      session: session,
    );
  }

  /// Background flush (debounce / max-age paths) that swallows + logs Drift
  /// errors so a single DB throw can't surface as an uncaught async exception
  /// and stall the periodic write (issue #279, M7). Explicit [flush] /
  /// [writeNow] call [_flush] directly so their callers observe real errors.
  Future<void> _flushGuarded({
    required String mediaId,
    required String dexieTargetType,
    required PlaybackSession session,
  }) async {
    try {
      await _flush(
        mediaId: mediaId,
        dexieTargetType: dexieTargetType,
        session: session,
      );
    } catch (e, st) {
      _persisterLog.warning('background playback session flush failed', e, st);
    }
  }

  Future<void> _flush({
    required String mediaId,
    required String dexieTargetType,
    required PlaybackSession session,
  }) async {
    final echo = _ref.read(echoModeProvider);
    final blurActive = _ref.read(transcriptBlurModeProvider);
    final db = _ref.read(appDatabaseProvider);
    final existing = await db.echoSessionDao.getOrCreateLatestForTarget(
      dexieTargetType,
      mediaId,
    );
    final now = DateTime.now();
    await db.echoSessionDao.upsert(
      existing.copyWith(
        currentTimeMs: msFromSeconds(session.currentTimeSeconds),
        currentSegmentIndex: session.currentSegmentIndex,
        echoActive: echo.active,
        echoStartLine: echo.startLineIndex,
        echoEndLine: echo.endLineIndex,
        echoStartMs: echo.active
            ? Value(msFromSeconds(echo.startTimeSeconds))
            : const Value(null),
        echoEndMs: echo.active
            ? Value(msFromSeconds(echo.endTimeSeconds))
            : const Value(null),
        blurActive: blurActive,
        lastActiveAt: now,
        updatedAt: now,
        transcriptId: const Value.absent(),
        secondaryTranscriptId: const Value.absent(),
      ),
    );
  }

  void cancel() {
    _debounce?.cancel();
    _debounce = null;
    _pendingSince = null;
  }

  void dispose() => cancel();
}

final playbackSessionPersisterProvider = Provider<PlaybackSessionPersister>((
  ref,
) {
  final p = PlaybackSessionPersister(ref);
  ref.onDispose(p.dispose);
  return p;
});
