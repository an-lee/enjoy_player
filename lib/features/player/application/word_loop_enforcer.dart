/// Single-flight wrap of one timed word's media window.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/domain/echo_window.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/domain/word_loop.dart';
import 'package:enjoy_player/features/transcript/application/word_practice_session.dart';

final _log = logNamed('WordLoopEnforcer');

/// Returns true when echo pause-and-rewind should be skipped this tick.
class WordLoopEnforcer {
  WordLoopEnforcer({
    required this.ref,
    required this.getEngine,
    required this.getSession,
  });

  final Ref ref;
  final PlayerEngine Function() getEngine;
  final PlaybackSession? Function() getSession;

  int _epoch = 0;
  Future<void>? _inFlight;

  /// Reactive wrap. Returns whether echo enforcement should skip this tick.
  Future<bool> enforceTick(int positionMs) async {
    final mediaId = getSession()?.mediaId;
    if (mediaId == null) return false;
    if (!ref.exists(wordPracticeSessionProvider(mediaId))) return false;
    final loop = ref.read(wordPracticeSessionProvider(mediaId));
    if (!loop.isLooping) return false;

    final echo = ref.read(echoModeProvider);
    if (echo.active &&
        loop.loopLineIndex != null &&
        (loop.loopLineIndex! < echo.startLineIndex ||
            loop.loopLineIndex! > echo.endLineIndex)) {
      ref.read(wordPracticeSessionProvider(mediaId).notifier).clearLoop();
      return false;
    }

    final decision = decideWordLoopTick(
      positionMs: positionMs,
      startMs: loop.loopStartMs!,
      endMs: loop.loopEndMs!,
    );
    switch (decision) {
      case WordLoopTickDecision.ok:
        return true;
      case WordLoopTickDecision.cancel:
        ref.read(wordPracticeSessionProvider(mediaId).notifier).clearLoop();
        return false;
      case WordLoopTickDecision.wrap:
        if (_inFlight != null) return true;
        final epoch = _epoch;
        final startMs = loop.loopStartMs!;
        final future = _seek(startMs, epoch);
        _inFlight = future;
        try {
          await future;
        } catch (e, st) {
          _log.warning('word loop wrap failed', e, st);
        } finally {
          if (_inFlight == future) _inFlight = null;
        }
        return true;
    }
  }

  /// Neutralizes any in-flight wrap. Must not read [Ref] or [getSession] —
  /// [PlayerPositionTracker.cancel] also runs from `PlayerController` dispose.
  void reset() {
    _epoch++;
    _inFlight = null;
  }

  Future<void> _seek(int startMs, int epoch) async {
    if (_epoch != epoch) return;
    await getEngine().seek(durationFromSeconds(startMs / 1000.0));
    if (_epoch != epoch) return;
    await getEngine().play();
  }
}
