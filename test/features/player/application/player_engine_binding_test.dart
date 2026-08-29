import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_binding.dart';
import 'package:enjoy_player/features/player/application/player_engine_rev.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Ref _refOf(ProviderContainer container) {
  late Ref captured;
  container.read(
    Provider<int>((ref) {
      captured = ref;
      return 0;
    }),
  );
  return captured;
}

void main() {
  test('first local open installs MediaKit and bumps engine rev', () async {
    final container = ProviderContainer();
    addTearDown(container.dispose);
    final ref = _refOf(container);

    PlayerEngine? owned;
    var gen = 1;
    final revBefore = container.read(playerEngineRevProvider);

    await ensureEngineForPlayableSource(
      ref,
      playable: const LocalFilePlayableSource('file:///tmp/a.mp4'),
      openGeneration: gen,
      currentOpenGeneration: () => gen,
      getOwnedEngine: () => owned,
      setOwnedEngine: (next) => owned = next,
    );

    expect(owned, isA<MediaKitPlayerEngine>());
    expect(owned!.keepSurfaceWhenParked, isFalse);
    expect(container.read(playerEngineRevProvider), revBefore + 1);

    await owned!.dispose();
  });

  test(
    'local open with MediaKit already owned does not bump or replace',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = _refOf(container);

      final existing = MediaKitPlayerEngine();
      addTearDown(existing.dispose);
      PlayerEngine? owned = existing;
      var gen = 1;
      final revBefore = container.read(playerEngineRevProvider);

      await ensureEngineForPlayableSource(
        ref,
        playable: const LocalFilePlayableSource('file:///tmp/a.mp4'),
        openGeneration: gen,
        currentOpenGeneration: () => gen,
        getOwnedEngine: () => owned,
        setOwnedEngine: (next) => owned = next,
      );

      expect(owned, same(existing));
      expect(container.read(playerEngineRevProvider), revBefore);
    },
  );

  test(
    'YouTube to MediaKit swap installs MediaKit, bumps, and disposes YouTube',
    () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = _refOf(container);

      final youtube = YoutubePlayerEngine();
      PlayerEngine? owned = youtube;
      var gen = 1;
      final revBefore = container.read(playerEngineRevProvider);

      await ensureEngineForPlayableSource(
        ref,
        playable: const LocalFilePlayableSource('file:///tmp/a.mp4'),
        openGeneration: gen,
        currentOpenGeneration: () => gen,
        getOwnedEngine: () => owned,
        setOwnedEngine: (next) => owned = next,
      );

      expect(owned, isA<MediaKitPlayerEngine>());
      expect(owned, isNot(same(youtube)));
      expect(container.read(playerEngineRevProvider), revBefore + 1);

      await owned?.dispose();
    },
  );

  test(
    'opted-out Linux never swaps the live MediaKit engine for YouTube',
    () async {
      // 2026-08-29 field report regression guard: the Linux YouTube open used
      // to swap in YoutubePlayerEngine (disposing the live MediaKit/mpv
      // player); the open then threw, and every later audio open rebuilt
      // MediaKit against a wedged native layer — infinite loading. The open
      // coordinator now gates before this call; the binding itself must stay
      // a no-op for YouTube sources on opted-out platforms as well.
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      addTearDown(() => debugDefaultTargetPlatformOverride = null);

      final container = ProviderContainer();
      addTearDown(container.dispose);
      final ref = _refOf(container);

      final existing = MediaKitPlayerEngine();
      addTearDown(existing.dispose);
      PlayerEngine? owned = existing;
      var gen = 1;
      final revBefore = container.read(playerEngineRevProvider);

      await ensureEngineForPlayableSource(
        ref,
        playable: const YoutubePlayableSource('dQw4w9WgXcQ'),
        openGeneration: gen,
        currentOpenGeneration: () => gen,
        getOwnedEngine: () => owned,
        setOwnedEngine: (next) => owned = next,
      );

      expect(owned, same(existing));
      expect(container.read(playerEngineRevProvider), revBefore);
    },
  );
}
