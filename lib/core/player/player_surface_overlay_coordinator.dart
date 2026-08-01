/// Coordinates parking the permanent player surface while transient overlays show.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Tracks transient overlays (dialogs, sheets, menus, snackbars) that must not
/// be covered by the permanent [PlayerSurfaceHost] platform view.
///
/// Native surfaces (WebView2, media_kit) can paint above Flutter overlays even
/// when those overlays sit higher in the widget tree. Parking the surface
/// off-screen while any token is held keeps notices/modals visible on every
/// platform without disposing the engine.
///
/// Hover/[MouseRegion] handlers that rebuild when the surface parks must use
/// `runOutsideMouseTracker` (see `mouse_tracker_safe.dart`) so desktop does
/// not trip `!_debugDuringDeviceUpdate`.
class PlayerSurfaceOverlayCoordinator extends Notifier<Set<Object>> {
  @override
  Set<Object> build() => const <Object>{};

  /// Whether the host should ignore the attached target and park off-screen.
  bool get shouldPark => state.isNotEmpty;

  /// Acquire a hold while an overlay is visible. Call [release] with the same
  /// token when the overlay closes.
  Object acquire([String reason = 'overlay']) {
    final token = Object();
    state = {...state, token};
    return token;
  }

  void release(Object token) {
    if (!state.contains(token)) return;
    final next = {...state}..remove(token);
    state = next;
  }

  /// Test helper: drop every hold.
  void clear() {
    if (state.isEmpty) return;
    state = const <Object>{};
  }
}

final playerSurfaceOverlayCoordinatorProvider =
    NotifierProvider<PlayerSurfaceOverlayCoordinator, Set<Object>>(
      PlayerSurfaceOverlayCoordinator.new,
    );

/// Convenience: park when any overlay token is held.
final playerSurfaceShouldParkForOverlayProvider = Provider<bool>((ref) {
  return ref.watch(playerSurfaceOverlayCoordinatorProvider).isNotEmpty;
});
