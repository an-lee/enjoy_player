/// Position/duration stream subscriptions, echo enforcement, and session persistence.
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/application/echo_enforcer.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/word_loop_enforcer.dart';
import 'package:enjoy_player/features/player/application/position_buckets.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/application/word_practice_session.dart';
import 'playback_session_persister.dart';

final _positionLog = logNamed('PlayerPositionTracker');

/// Manages engine position/duration listeners for one open generation.
///
/// Echo *enforcement* runs on every position event via [_echoEnforcer]
/// (single-flight inside); the heavy session emit + persistence stays on the
/// 400 ms bucket so the recorded clip window lines up across runs.
class PlayerPositionTracker {
  PlayerPositionTracker({
    required this.ref,
    required this.getEngine,
    required this.getSession,
    required this.setSession,
    required this.currentOpenGeneration,
  });

  final Ref ref;
  final PlayerEngine Function() getEngine;
  final PlaybackSession? Function() getSession;
  final void Function(PlaybackSession? next) setSession;
  final int Function() currentOpenGeneration;

  late final EchoEnforcer _echoEnforcer = EchoEnforcer(
    ref: ref,
    getEngine: getEngine,
    getSession: getSession,
    getLines: () {
      final mediaId = getSession()?.mediaId;
      if (mediaId == null) return null;
      return ref.read(transcriptLinesForMediaProvider(mediaId)).value;
    },
  );

  late final WordLoopEnforcer _wordLoopEnforcer = WordLoopEnforcer(
    ref: ref,
    getEngine: getEngine,
    getSession: getSession,
  );

  /// The single-flight echo enforcement coordinator. [PlayerController.seekTo]
  /// routes the proactive seek clamp through here so it serializes against the
  /// reactive per-tick path.
  EchoEnforcer get echoEnforcer => _echoEnforcer;

  int? _subscribedGeneration;
  String? _subscribedMediaId;

  StreamSubscription<Duration>? _positionSub;
  StreamSubscription<Duration>? _durationSub;
  int? _lastPositionEmitBucket;

  Future<void> cancel() async {
    await _positionSub?.cancel();
    await _durationSub?.cancel();
    _positionSub = null;
    _durationSub = null;
    _lastPositionEmitBucket = null;
    // Release the enforcement slot and neutralize any in-flight op so a
    // pending pause-and-rewind can't seek a stale engine or block the next
    // media's enforcement.
    _echoEnforcer.reset();
    _wordLoopEnforcer.reset();
    final mediaId = _subscribedMediaId;
    _subscribedMediaId = null;
    if (mediaId != null &&
        ref.mounted &&
        ref.exists(wordPracticeSessionProvider(mediaId))) {
      ref.read(wordPracticeSessionProvider(mediaId).notifier).clearAll();
    }
  }

  void subscribe({
    required int openGeneration,
    required String mediaId,
    required String dexieTargetType,
    required MediaKind kind,
    required VideoRow? video,
    required AudioRow? audio,
  }) {
    _subscribedGeneration = openGeneration;
    _subscribedMediaId = mediaId;
    _lastPositionEmitBucket = null;

    const positionBucketMs = kPositionBucketSessionEmitMs;
    _positionSub = getEngine().position.listen(
      (pos) {
        if (_subscribedGeneration != currentOpenGeneration()) return;
        final seconds = pos.inMilliseconds / 1000.0;

        // Echo enforcement runs on every position event — the decision is cheap
        // and this is what keeps pause-and-rewind within ~50 ms of the segment
        // end. Single-flight inside the enforcer drops concurrent ticks.
        // Guarded so a single engine error cannot surface as an uncaught async
        // exception and stall enforcement for the rest of the session (M7).
        unawaited(() async {
          try {
            final skipEcho = await _wordLoopEnforcer.enforceTick(
              pos.inMilliseconds,
            );
            if (skipEcho) return;
            await _echoEnforcer.enforceTick(seconds);
          } catch (e, st) {
            _positionLog.warning('loop/echo enforcement tick failed', e, st);
          }
        }());

        // Heavy session emit + persistence stays on the 400 ms bucket (or fires
        // immediately on a detected seek) so the recorded clip window lines up.
        final bucket = pos.inMilliseconds ~/ positionBucketMs;
        final prevSec = getSession()?.currentTimeSeconds;
        final likelySeek =
            prevSec != null &&
            (seconds - prevSec).abs() > kLikelySeekDeltaSeconds;
        if (!likelySeek && bucket == _lastPositionEmitBucket) {
          return;
        }
        _lastPositionEmitBucket = bucket;

        setSession(
          getSession()?.copyWith(
            currentTimeSeconds: seconds,
            lastActiveAt: DateTime.now(),
          ),
        );
        final s = getSession();
        if (s != null) {
          ref
              .read(playbackSessionPersisterProvider)
              .schedule(
                mediaId: mediaId,
                dexieTargetType: dexieTargetType,
                session: s,
              );
        }
      },
      onError: (Object e, StackTrace st) {
        _positionLog.warning('engine position stream errored', e, st);
      },
    );

    _durationSub = getEngine().duration.listen(
      (d) async {
        if (_subscribedGeneration != currentOpenGeneration()) return;
        if (d <= Duration.zero) return;
        final newSec = d.inMilliseconds / 1000.0;
        final prevSec = getSession()?.durationSeconds;
        if (prevSec != null &&
            (newSec - prevSec).abs() < kDurationEpsilonSeconds) {
          return;
        }
        final sec = d.inMilliseconds ~/ 1000;
        setSession(getSession()?.copyWith(durationSeconds: newSec));
        final db = ref.read(appDatabaseProvider);
        if (kind == MediaKind.video &&
            video != null &&
            video.durationSeconds == 0) {
          await db.videoDao.insertRow(
            video.copyWith(durationSeconds: sec, updatedAt: DateTime.now()),
          );
        } else if (kind == MediaKind.audio &&
            audio != null &&
            audio.durationSeconds == 0) {
          await db.audioDao.insertRow(
            audio.copyWith(durationSeconds: sec, updatedAt: DateTime.now()),
          );
        }
      },
      onError: (Object e, StackTrace st) {
        _positionLog.warning('engine duration stream errored', e, st);
      },
    );
  }
}
