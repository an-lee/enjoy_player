/// Engine identity → video stage mapping for the surface host (issue #664).
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/features/player/application/engines/youtube/youtube_player_engine.dart';
import 'package:enjoy_player/features/player/application/player_engine.dart';
import 'package:enjoy_player/features/player/presentation/widgets/media_kit_video_stage.dart';
import 'package:enjoy_player/features/player/presentation/widgets/youtube_video_stage.dart';

/// Builds the video stage widget the surface host mounts for [engine].
typedef PlayerStageBuilder =
    Widget Function(
      PlayerEngine engine, {
      required double maxWidth,
      required double maxHeight,
    });

/// The production engine → stage mapping.
///
/// Building widgets is a presentation concern, so the mapping lives here next
/// to the stages instead of on [PlayerEngine]. Along with the stage widgets
/// themselves and the engine construction sites (`PlayerController`,
/// `PlayerEngineBinding`) this is the only code allowed to name a concrete
/// engine class — call sites elsewhere keep using [PlayerEngine] capabilities
/// (issue #595 engine-kind erasure). ADR-0057 remounting is untouched: the
/// host still keys the whole slot by engine identity, so a swap drops the old
/// stage before the old engine tears down.
Widget buildPlayerVideoStage(
  PlayerEngine engine, {
  required double maxWidth,
  required double maxHeight,
}) {
  if (engine is MediaKitPlayerEngine) {
    return MediaKitVideoStage(
      engine: engine,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }
  if (engine is YoutubePlayerEngine) {
    return YoutubeVideoStage(
      engine: engine,
      maxWidth: maxWidth,
      maxHeight: maxHeight,
    );
  }
  // Test double (no native surface of its own) — mount nothing.
  return const SizedBox.shrink();
}
