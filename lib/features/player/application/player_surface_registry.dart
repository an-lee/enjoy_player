/// Registry for the permanent [PlayerSurfaceHost] viewport target.
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Overlay chrome drawn above the native video surface inside the host stack.
typedef PlayerSurfaceOverlayBuilder = Widget Function(BuildContext context);

/// One active viewport that the shell [PlayerSurfaceHost] should follow.
final class PlayerSurfaceAttachment {
  const PlayerSurfaceAttachment({
    required this.id,
    required this.owner,
    required this.offset,
    required this.size,
    this.overlayBuilder,
  });

  final String id;
  final Object owner;
  final Offset offset;
  final Size size;
  final PlayerSurfaceOverlayBuilder? overlayBuilder;
}

/// Keep-alive registry: at most one surface target is active.
class PlayerSurfaceRegistry extends Notifier<PlayerSurfaceAttachment?> {
  @override
  PlayerSurfaceAttachment? build() => null;

  void attach(PlayerSurfaceAttachment attachment) {
    state = attachment;
  }

  /// Refreshes [id]'s attachment in place.
  ///
  /// Geometry and overlay arguments default to "keep what is stored", so
  /// passing `overlayBuilder: null` does **not** clear the chrome — a target
  /// that no longer draws an overlay must call [detach] (or pass
  /// [clearOverlay]) instead. Same-id targets are re-attached by
  /// [PlayerSurfaceTarget._sync], which always supplies its current builder.
  void update({
    required String id,
    Offset? offset,
    Size? size,
    PlayerSurfaceOverlayBuilder? overlayBuilder,
    bool clearOverlay = false,
  }) {
    final cur = state;
    if (cur == null || cur.id != id) return;
    final nextOffset = offset ?? cur.offset;
    final nextSize = size ?? cur.size;
    final nextOverlay = clearOverlay
        ? null
        : (overlayBuilder ?? cur.overlayBuilder);
    if (nextOffset == cur.offset &&
        nextSize == cur.size &&
        identical(nextOverlay, cur.overlayBuilder)) {
      return;
    }
    state = PlayerSurfaceAttachment(
      id: cur.id,
      owner: cur.owner,
      offset: nextOffset,
      size: nextSize,
      overlayBuilder: nextOverlay,
    );
  }

  void detach(String id, Object owner) {
    if (state case final attachment?
        when attachment.id == id && identical(attachment.owner, owner)) {
      state = null;
    }
  }
}

final playerSurfaceRegistryProvider =
    NotifierProvider<PlayerSurfaceRegistry, PlayerSurfaceAttachment?>(
      PlayerSurfaceRegistry.new,
    );

/// Stable target ids used across the app.
abstract final class PlayerSurfaceIds {
  static const vocabularyClip = 'vocabulary.clip';
  static const expandedPlayer = 'player.expanded';

  /// YouTube open-in-flight viewport only. Local/URL loading uses
  /// [expandedPlayer] so the media_kit texture is not parked mid-open.
  static const expandedPlayerLoading = 'player.expanded.loading';
}
