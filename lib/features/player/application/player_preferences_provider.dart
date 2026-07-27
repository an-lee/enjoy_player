/// Persisted volume / speed / repeat (maps web persisted settings).
library;

import 'dart:async';
import 'dart:convert';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../data/db/app_database_provider.dart';
import '../domain/player_settings.dart';
import 'player_engine_provider.dart';

part 'player_preferences_provider.g.dart';

const playerPreferencesStorageKey = 'player_preferences_v1';

@Riverpod(keepAlive: true)
class PlayerPreferencesCtrl extends _$PlayerPreferencesCtrl {
  /// Last audible level used when restoring from mute (not persisted).
  double _lastNonZeroVolume = 1;

  @override
  PlayerPreferences build() {
    unawaited(Future<void>.microtask(_hydrate));
    return PlayerPreferences.defaults;
  }

  Future<void> _hydrate() async {
    final db = ref.read(appDatabaseProvider);
    final raw = await db.settingsDao.getValue(playerPreferencesStorageKey);
    if (raw == null) return;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      final repeatIdx = (map['repeat'] as int?) ?? 0;
      state = PlayerPreferences(
        volume: ((map['volume'] as num?)?.toDouble() ?? 1).clamp(0, 1),
        playbackRate: ((map['rate'] as num?)?.toDouble() ?? 1).clamp(0.25, 2),
        repeatMode:
            RepeatMode.values[repeatIdx.clamp(0, RepeatMode.values.length - 1)],
        videoTranscriptSplitWidthPx: (map['splitPx'] as num?)?.toDouble(),
      );
      final v = state.volume;
      _lastNonZeroVolume = v > 0.01 ? v : 1;
      await applyCurrentToEngine();
    } catch (_) {
      /* ignore corrupt prefs */
    }
  }

  Future<void> _persist() async {
    final db = ref.read(appDatabaseProvider);
    await db.settingsDao.setValue(
      playerPreferencesStorageKey,
      jsonEncode({
        'volume': state.volume,
        'rate': state.playbackRate,
        'repeat': state.repeatMode.index,
        if (state.videoTranscriptSplitWidthPx != null)
          'splitPx': state.videoTranscriptSplitWidthPx,
      }),
    );
  }

  Future<void> applyCurrentToEngine() async {
    final engine = ref.read(playerEngineProvider);
    await engine.setVolumeNormalized(state.volume);
    await engine.setRate(state.playbackRate);
  }

  Future<void> setVolume(double v) async {
    final clamped = v.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(volume: clamped);
    if (clamped > 0.01) {
      _lastNonZeroVolume = clamped;
    }
    await _persist();
    await applyCurrentToEngine();
  }

  /// Updates volume state + engine **without** persisting to Drift — for
  /// use during slider drag so each tick is cheap. Call [setVolume] on
  /// `onChangeEnd` to persist the final value (issue #470).
  Future<void> setVolumeTransient(double v) async {
    final clamped = v.clamp(0.0, 1.0).toDouble();
    state = state.copyWith(volume: clamped);
    if (clamped > 0.01) {
      _lastNonZeroVolume = clamped;
    }
    final engine = ref.read(playerEngineProvider);
    await engine.setVolumeNormalized(clamped);
  }

  Future<void> toggleMute() async {
    if (state.volume <= 0.01) {
      await setVolume(_lastNonZeroVolume.clamp(0.05, 1.0).toDouble());
    } else {
      _lastNonZeroVolume = state.volume;
      await setVolume(0);
    }
  }

  Future<void> setPlaybackRate(double r) async {
    state = state.copyWith(playbackRate: r.clamp(0.25, 2));
    await _persist();
    await applyCurrentToEngine();
  }

  Future<void> setRepeatMode(RepeatMode m) async {
    state = state.copyWith(repeatMode: m);
    await _persist();
  }

  /// Persists the video + transcript side-by-side split width (logical px).
  Future<void> setVideoTranscriptSplitWidthPx(double? widthPx) async {
    state = widthPx == null
        ? state.copyWith(clearVideoTranscriptSplitWidthPx: true)
        : state.copyWith(videoTranscriptSplitWidthPx: widthPx);
    await _persist();
  }
}
