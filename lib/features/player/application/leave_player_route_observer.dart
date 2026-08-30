/// Reports when the last `/player/` route leaves a navigator's stack.
library;

import 'package:flutter/widgets.dart';

/// [NavigatorObserver] that fires [onLeftPlayerRoute] when the observed
/// navigator stops hosting a `/player/` route.
///
/// This is the leave-player teardown trigger (spec 044). Driving it from the
/// shell's `LayoutBuilder` re-fired the teardown on every rebuild that
/// happened to hold the "off player + live session" condition, and only stayed
/// safe because `clear()` bumps the open generation. A route transition is the
/// actual event, so observe it.
///
/// One observer per navigator — Flutter binds an observer to a single
/// `Navigator`, the same constraint
/// `PlayerSurfaceOverlayNavigatorObserver` documents. Player routes only ever
/// mount on the shell navigator (every `/player/:mediaId` route is a child of
/// the app `ShellRoute`), so only that navigator carries one.
class LeavePlayerRouteObserver extends NavigatorObserver {
  LeavePlayerRouteObserver({required this.onLeftPlayerRoute});

  /// Called once per transition that removes the last player route.
  ///
  /// The callback runs while the navigator is applying the transition, so
  /// implementations must not publish provider state synchronously — defer it.
  final void Function() onLeftPlayerRoute;

  int _playerRoutes = 0;

  /// Whether the observed navigator currently hosts a `/player/` route.
  bool get isHostingPlayerRoute => _playerRoutes > 0;

  @override
  void didPush(Route<dynamic> route, Route<dynamic>? previousRoute) {
    if (isPlayerRoute(route)) _playerRoutes++;
  }

  @override
  void didPop(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _playerRouteRemoved(route);
  }

  @override
  void didRemove(Route<dynamic> route, Route<dynamic>? previousRoute) {
    _playerRouteRemoved(route);
  }

  @override
  void didReplace({Route<dynamic>? newRoute, Route<dynamic>? oldRoute}) {
    if (oldRoute != null) _playerRouteRemoved(oldRoute);
    if (newRoute != null && isPlayerRoute(newRoute)) _playerRoutes++;
  }

  void _playerRouteRemoved(Route<dynamic> route) {
    if (!isPlayerRoute(route)) return;
    _playerRoutes--;
    if (_playerRoutes > 0) return;
    _playerRoutes = 0;
    onLeftPlayerRoute();
  }
}

/// Whether [route] was built for a `/player/:mediaId` location.
///
/// go_router copies the page's `name` into `RouteSettings.name`. Default
/// pages get the matched location, but the player page is a
/// `CustomTransitionPage` built with an explicit `name: state.matchedLocation`
/// (`app_router.dart`) — its `ValueKey` pins page identity, not its name, so
/// the name is free to carry the location for this check.
bool isPlayerRoute(Route<dynamic> route) =>
    route.settings.name?.startsWith('/player/') ?? false;
