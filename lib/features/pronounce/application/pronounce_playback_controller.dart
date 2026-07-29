/// App-wide single pronounce playback session.
library;

import 'dart:async';
import 'dart:collection';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_audio_engine.dart';
import 'package:enjoy_player/features/pronounce/application/pronounce_service.dart';
import 'package:enjoy_player/features/pronounce/domain/pronounce_target.dart';

part 'pronounce_playback_controller.g.dart';

const _kUrlCacheMax = 32;

@Riverpod(keepAlive: true)
class PronouncePlaybackController extends _$PronouncePlaybackController {
  static final _log = logNamed('Pronounce');

  PronounceAudioEngine? _engine;
  StreamSubscription<void>? _completeSub;
  int _generation = 0;
  final LinkedHashMap<String, String> _urlCache = LinkedHashMap();

  /// Override in tests via [PronouncePlaybackController.new] is not available;
  /// use [debugEngineFactory] before first play.
  static PronounceAudioEngine Function()? debugEngineFactory;

  @override
  PronouncePlaybackState build() {
    ref.onDispose(() {
      unawaited(_tearDown());
    });
    return const PronouncePlaybackState.idle();
  }

  PronounceAudioEngine _ensureEngine() {
    final existing = _engine;
    if (existing != null) return existing;
    final created = debugEngineFactory?.call() ?? AudioplayersPronounceEngine();
    _engine = created;
    _completeSub = created.onComplete.listen((_) {
      if (state.isPlaying) {
        state = const PronouncePlaybackState.idle();
      }
    });
    return created;
  }

  Future<void> _tearDown() async {
    _generation++;
    await _completeSub?.cancel();
    _completeSub = null;
    await _engine?.dispose();
    _engine = null;
    _urlCache.clear();
  }

  void _putCache(String key, String url) {
    _urlCache.remove(key);
    _urlCache[key] = url;
    while (_urlCache.length > _kUrlCacheMax) {
      _urlCache.remove(_urlCache.keys.first);
    }
  }

  /// Tap-to-play / tap-to-stop for [target].
  Future<void> play(PronounceTarget target) async {
    if (state.isPlayingFor(target) || state.isLoadingFor(target)) {
      await stop();
      return;
    }

    final gen = ++_generation;
    await _engine?.stop();

    state = PronouncePlaybackState(
      phase: PronouncePlaybackPhase.loading,
      target: target,
    );

    try {
      var url = _urlCache[target.cacheKey];
      if (url == null) {
        final result = await ref
            .read(pronounceServiceProvider)
            .pronounce(text: target.text, locale: target.resolvedLocale);
        if (gen != _generation || !ref.mounted) return;
        url = result.audioUrl;
        if (url.isEmpty) {
          throw const NetworkFailure('Empty pronunciation audio URL');
        }
        _putCache(target.cacheKey, url);
      }

      if (gen != _generation || !ref.mounted) return;

      final engine = _ensureEngine();
      await engine.playUrl(url);
      if (gen != _generation || !ref.mounted) {
        await engine.stop();
        return;
      }
      state = PronouncePlaybackState(
        phase: PronouncePlaybackPhase.playing,
        target: target,
      );
    } on AppFailure catch (e) {
      if (gen != _generation || !ref.mounted) return;
      _log.info('pronounce failed: $e');
      state = PronouncePlaybackState(
        phase: PronouncePlaybackPhase.error,
        target: target,
        errorMessage: e.message,
      );
      // Return to idle so the control is tappable again.
      state = const PronouncePlaybackState.idle();
      rethrow;
    } on Object catch (e, st) {
      if (gen != _generation || !ref.mounted) return;
      _log.warning('pronounce unexpected error', e, st);
      state = const PronouncePlaybackState.idle();
      throw NetworkFailure(e.toString());
    }
  }

  Future<void> stop() async {
    _generation++;
    await _engine?.stop();
    if (!ref.mounted) return;
    state = const PronouncePlaybackState.idle();
  }
}
