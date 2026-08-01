/// Parks the player surface for navigator [PopupRoute]s (dialogs, sheets, menus).
library;

import 'package:flutter/widgets.dart';

import 'package:enjoy_player/core/player/player_surface_overlay_coordinator.dart';

/// [NavigatorObserver] that acquires/releases overlay tokens for [PopupRoute]s.
///
/// Attach one instance per navigator (root and shell). Do not share a single
/// observer across navigators — Flutter binds each observer to one [Navigator].
class PlayerSurfaceOverlayNavigatorObserver extends NavigatorObserver {
  PlayerSurfaceOverlayNavigatorObserver({required this.coordinator});

  /// Lazy accessor so the observer can be created when the router is built.
  final PlayerSurfaceOverlayCoordinator Function() coordinator;

  final Map<Route<dynamic>, Object> _tokens = <Route<dynamic>, Object>{};

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _acquireIfPopup(route);
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _release(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _release(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _release(oldRoute);
    if (newRoute != null) _acquireIfPopup(newRoute);
  }

  void _acquireIfPopup(Route<dynamic> route) {
    if (route is! PopupRoute<dynamic>) return;
    if (_tokens.containsKey(route)) return;
    _tokens[route] = coordinator().acquire('popup');
  }

  void _release(Route<dynamic> route) {
    final token = _tokens.remove(route);
    if (token != null) coordinator().release(token);
  }
}
