/// Shared 16:9 open-in-flight portal for the local and YouTube loading stages.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/features/player/application/player_surface_registry.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';

/// 16:9 portal target shown while [openMedia] is in flight.
///
/// Both loading stages share this scaffolding — top-only safe area, a 16:9
/// stage, and a [PlayerSurfaceTarget] claiming a chrome viewport so the
/// loading → player hand-off never parks (unmounts) the native surface. Only
/// the claimed id, the enabled gate, the overlay chrome, and the poster child
/// differ, which is exactly what the parameters cover.
class PlayerLoadingStage extends StatelessWidget {
  const PlayerLoadingStage({
    required this.surfaceId,
    required this.child,
    this.enabled = true,
    this.overlayBuilder,
    super.key,
  });

  static const double aspectWidth = 16;
  static const double aspectHeight = 9;

  /// Chrome viewport id the stage claims. Local/URL open reuses
  /// [PlayerSurfaceIds.expandedPlayer] so media_kit's Texture is not parked
  /// mid-open; YouTube claims [PlayerSurfaceIds.expandedPlayerLoading].
  final String surfaceId;

  /// When false, detaches the target so the host parks (or hides) the surface.
  final bool enabled;

  /// Chrome drawn above the native surface inside the host stack.
  final PlayerSurfaceOverlayBuilder? overlayBuilder;

  /// Poster / thumbnail content behind the portal surface.
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: true,
      bottom: false,
      left: false,
      right: false,
      child: AspectRatio(
        aspectRatio: aspectWidth / aspectHeight,
        child: PlayerSurfaceTarget(
          id: surfaceId,
          enabled: enabled,
          overlayBuilder: overlayBuilder,
          child: child,
        ),
      ),
    );
  }
}
