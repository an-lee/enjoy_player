/// Swaps [PlayerEngine] implementation for YouTube vs local/URL (ADR-0015).
library;

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/platform/linux_platform_availability.dart';
import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_constants.dart';
import 'package:enjoy_player/features/player/domain/playable_source.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine_rev.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';

final _bindLog = logNamed('PlayerEngineBinding');

/// Ensures [_ownedEngine] matches [playable] (YouTube vs MediaKit), bumping
/// [playerEngineRevProvider] when the implementation changes.
///
/// Returns `true` when a new engine was installed (first local open or a
/// YouTube ↔ MediaKit swap). Returns `false` when the owned engine already
/// matches, a test double is installed, or the open generation went stale.
///
/// [openGeneration] must match [currentOpenGeneration] before and after each
/// async step so concurrent [openMedia] calls cannot dispose another call's
/// engine mid-flight.
///
/// Per ADR-0057, the permanent [PlayerSurfaceHost] keys its stage by engine
/// identity. We must **swap + bump first** so the host drops the old
/// `buildVideoStage`, then wait for that surface to detach, *then* allow
/// MediaKit to allocate mpv — never construct [Player] while InAppWebView
/// is still tearing down (2026-08-30 field report: local audio after YouTube
/// stuck on the loading skeleton; back + reopen recovered because the
/// second open skipped the swap).
///
/// The first local/URL open also installs [MediaKitPlayerEngine] and bumps
/// so [PlayerSurfaceHost] can mount `Video` before decode starts. Creating
/// [VideoController] with no [Video] widget binds a native texture that stays
/// black on Windows/Android until a later layout.
Future<bool> ensureEngineForPlayableSource(
  Ref ref, {
  required PlayableSource playable,
  required int openGeneration,
  required int Function() currentOpenGeneration,
  required PlayerEngine? Function() getOwnedEngine,
  required void Function(PlayerEngine? next) setOwnedEngine,
}) async {
  if (ref.read(playerEngineTestDoubleProvider) != null) return false;
  if (currentOpenGeneration() != openGeneration) return false;

  final wantYt = playable is YoutubePlayableSource;
  final owned = getOwnedEngine();
  final haveYt = owned?.supportsYouTubePlayback ?? false;

  // ADR-0048 defense in depth: no WebView backend exists on opted-out
  // platforms, so a YouTube engine can never mount. Installing one would
  // dispose the live MediaKit engine (and its native mpv player) for
  // nothing — the 2026-08-29 field report traced every later audio open
  // hanging on the loading skeleton back to exactly that swap. The open
  // coordinator gates YouTube opens before this call; callers that open the
  // source anyway fail with the typed unavailable exception.
  if (wantYt && youTubeEngineOptedOutHere) return false;

  if (owned != null && haveYt == wantYt) return false;
  if (currentOpenGeneration() != openGeneration) return false;

  final next = wantYt ? YoutubePlayerEngine() : MediaKitPlayerEngine();
  setOwnedEngine(next);
  ref.read(playerEngineRevProvider.notifier).bump();
  // Let PlayerSurfaceHost drop the old ObjectKey stage before teardown.
  // MediaKit must not allocate [Player] yet — [prepareNativeBackend] runs
  // only after the prior surface has detached.
  await Future<void>.delayed(Duration.zero);
  if (currentOpenGeneration() != openGeneration) {
    await next.dispose();
    return false;
  }
  if (owned != null) {
    try {
      await owned.awaitSurfaceDetached().timeout(kEngineSurfaceDetachTimeout);
    } on TimeoutException {
      _bindLog.warning(
        'prior engine surface detach timed out after '
        '$kEngineSurfaceDetachTimeout; continuing swap',
      );
    }
    await Future<void>.delayed(kEngineSurfaceSettleDelay);
    if (currentOpenGeneration() != openGeneration) {
      await next.dispose();
      return false;
    }
    // Do not await dispose on the open path. YouTube closeStreams can hang
    // for seconds while listeners drain (2026-08-30 Android: 5 s skeleton
    // on a 4 s local file — the log was this exact timeout). The new
    // engine is already installed; a leaked old teardown beats a spinner.
    unawaited(owned.dispose());
  }
  if (currentOpenGeneration() != openGeneration) {
    await next.dispose();
    return false;
  }
  next.prepareNativeBackend();
  // Second bump: MediaKit Video may now mount (loading stage already has a
  // target). First bump only dropped the YouTube WebView.
  ref.read(playerEngineRevProvider.notifier).bump();
  return true;
}

/// Replaces a wedged local/URL engine with a fresh [MediaKitPlayerEngine].
///
/// The timed-out `open` on [getOwnedEngine] is still in flight — do not
/// await its dispose. No-op when a test double is installed so unit tests
/// retry the same fake.
Future<void> replaceWedgedLocalEngine(
  Ref ref, {
  required PlayerEngine? Function() getOwnedEngine,
  required void Function(PlayerEngine? next) setOwnedEngine,
}) async {
  if (ref.read(playerEngineTestDoubleProvider) != null) return;
  final old = getOwnedEngine();
  if (old == null || old.supportsYouTubePlayback) return;
  final next = MediaKitPlayerEngine();
  next.prepareNativeBackend();
  setOwnedEngine(next);
  ref.read(playerEngineRevProvider.notifier).bump();
  unawaited(old.dispose());
}
