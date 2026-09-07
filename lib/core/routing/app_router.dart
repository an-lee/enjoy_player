/// go_router configuration with persistent shell (mini player).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import 'package:enjoy_player/core/analytics/analytics.dart';
import 'package:enjoy_player/core/analytics/analytics_provider.dart';
import 'package:enjoy_player/core/player/player_surface_overlay_coordinator.dart';
import 'package:enjoy_player/core/player/player_surface_overlay_navigator_observer.dart';
import 'package:enjoy_player/core/routing/auth_redirect.dart';
import 'package:enjoy_player/core/routing/auth_router_tick.dart';
import 'package:enjoy_player/core/routing/not_found_screen.dart';
import 'package:enjoy_player/core/window/desktop_window.dart';
import 'package:enjoy_player/features/ai/presentation/ai_playground_screen.dart';
import 'package:enjoy_player/features/ai/presentation/settings/ai_providers_screen.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/craft/presentation/craft_history_screen.dart';
import 'package:enjoy_player/features/craft/presentation/craft_screen.dart';
import 'package:enjoy_player/features/auth/presentation/profile_edit_screen.dart';
import 'package:enjoy_player/features/auth/presentation/profile_preferences_screen.dart';
import 'package:enjoy_player/features/auth/presentation/profile_screen.dart';
import 'package:enjoy_player/features/credits/presentation/credits_usage_screen.dart';
import 'package:enjoy_player/features/auth/presentation/sign_in_screen.dart';
import 'package:enjoy_player/core/routing/library_source.dart';
import 'package:enjoy_player/features/discover/presentation/channel_feed_screen.dart';
import 'package:enjoy_player/features/discover/presentation/discover_screen.dart';
import 'package:enjoy_player/features/library/presentation/home_screen.dart';
import 'package:enjoy_player/features/library/presentation/library_screen.dart';
import 'package:enjoy_player/features/player/application/leave_player_route_observer.dart';
import 'package:enjoy_player/features/player/application/leave_player_session.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/player_launch_request.dart';
import 'package:enjoy_player/features/player/presentation/expanded_player_screen.dart';
import 'package:enjoy_player/features/player/presentation/root_shell.dart';
import 'package:enjoy_player/features/player/presentation/youtube_login_screen.dart';
import 'package:enjoy_player/features/settings/presentation/hotkeys_settings_screen.dart';
import 'package:enjoy_player/features/settings/presentation/settings_screen.dart';
import 'package:enjoy_player/features/settings/presentation/sync_status_screen.dart';
import 'package:enjoy_player/features/subscription/presentation/subscription_screen.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_session.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_review_session_screen.dart';
import 'package:enjoy_player/features/vocabulary/presentation/vocabulary_screen.dart';

part 'app_router.g.dart';

/// Nested navigator owned by the app [ShellRoute] (profile pushes, sheets).
final GlobalKey<NavigatorState> enjoyShellNavigatorKey =
    GlobalKey<NavigatorState>(debugLabel: 'shell');

CustomTransitionPage<void> _shellPage({
  required LocalKey key,
  required Widget child,
}) {
  return CustomTransitionPage<void>(
    key: key,
    child: child,
    transitionsBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(
        parent: animation,
        curve: Curves.easeOutCubic,
      );
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.02),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 180),
    reverseTransitionDuration: const Duration(milliseconds: 140),
  );
}

@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  final authTick = ref.watch(authRouterTickProvider);
  PlayerSurfaceOverlayCoordinator coordinator() =>
      ref.read(playerSurfaceOverlayCoordinatorProvider.notifier);
  // One observer per navigator — Flutter binds each observer to a single
  // Navigator (root vs shell).
  final rootOverlayObserver = PlayerSurfaceOverlayNavigatorObserver(
    coordinator: coordinator,
  );
  final shellOverlayObserver = PlayerSurfaceOverlayNavigatorObserver(
    coordinator: coordinator,
  );
  // Leave-player teardown (spec 044). Player routes only mount on the shell
  // navigator, so that is the only navigator carrying this observer. The
  // callback fires while the navigator is applying the transition, and
  // clear() publishes session state — defer it out of the build phase.
  final leavePlayerObserver = LeavePlayerRouteObserver(
    onLeftPlayerRoute: () =>
        scheduleMicrotask(() => unawaited(clearLivePlaybackSession(ref))),
  );
  // Screen autocapture (spec 046, research D6): one observer per navigator —
  // root- and shell-level navigators each report their own pushes. The
  // instance resolves to the no-op wherever analytics is inert, and vendor
  // setup/opt-out state is honored inside the facade.
  final rootScreenObserver = AnalyticsScreenObserver(
    ref.read(analyticsProvider),
  );
  final shellScreenObserver = AnalyticsScreenObserver(
    ref.read(analyticsProvider),
  );
  final router = GoRouter(
    initialLocation: '/',
    refreshListenable: authTick,
    observers: [rootOverlayObserver, rootScreenObserver],
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
    redirect: (context, state) {
      // A stray `/callback` is go_router's view of an auto-forwarded
      // enjoyplayer://auth/callback deep link (see isNativeAuthCallbackArtifact
      // doc). Treat it like landing on home while AuthDeepLinkListener
      // finishes the token exchange, rather than showing "Page not found".
      final loc = isNativeAuthCallbackArtifact(state.matchedLocation)
          ? '/'
          : state.matchedLocation;

      if (kReleaseMode && loc.startsWith('/settings/ai-playground')) {
        return '/settings';
      }
      if (loc.startsWith('/settings/keyboard') && !isDesktop) {
        return '/settings';
      }
      if (loc == '/cloud' || loc.startsWith('/cloud/')) {
        return libraryRouteForSource(LibrarySource.cloud);
      }
      if (loc == '/settings' &&
          state.uri.queryParameters['section'] == 'keyboard') {
        return isDesktop ? '/settings/keyboard' : null;
      }

      final auth = ref.read(authCtrlProvider);
      return resolveAuthRedirect(matchedLocation: loc, auth: auth);
    },
    routes: [
      GoRoute(
        name: 'sign-in',
        path: '/sign-in',
        builder: (context, state) => const SignInScreen(),
        routes: [
          GoRoute(
            name: 'sign-in-email',
            path: 'email',
            builder: (context, state) => const EmailEntryScreen(),
          ),
        ],
      ),
      ShellRoute(
        navigatorKey: enjoyShellNavigatorKey,
        observers: [
          shellOverlayObserver,
          leavePlayerObserver,
          shellScreenObserver,
        ],
        builder: (context, state, child) => RootShell(child: child),
        routes: [
          GoRoute(
            name: 'home',
            path: '/',
            pageBuilder: (context, state) => _shellPage(
              key: const ValueKey<String>('shell-home'),
              child: const HomeScreen(),
            ),
          ),
          GoRoute(
            name: 'discover',
            path: '/discover',
            pageBuilder: (context, state) => _shellPage(
              key: const ValueKey<String>('shell-discover'),
              child: const DiscoverScreen(),
            ),
            routes: [
              GoRoute(
                name: 'discover-channel',
                path: 'channel/:channelId',
                builder: (context, state) {
                  final channelId = state.pathParameters['channelId']!;
                  return ChannelFeedScreen(channelId: channelId);
                },
              ),
            ],
          ),
          GoRoute(
            name: 'library',
            path: '/library',
            pageBuilder: (context, state) => _shellPage(
              key: const ValueKey<String>('shell-library'),
              child: const LibraryScreen(),
            ),
          ),
          GoRoute(
            path: '/player/:mediaId',
            pageBuilder: (context, state) {
              final id = state.pathParameters['mediaId']!;
              final launch = PlayerLaunchRequest.fromUri(
                state.uri,
                mediaId: id,
              );
              return CustomTransitionPage<void>(
                // Keep the player page identity stable across `/player/:id`
                // changes. Windows WebView platform views are fragile when
                // rapidly destroyed/recreated; reusing the page lets the
                // YouTube engine navigate the existing WebView instead.
                key: const ValueKey('player-page'),
                // Carried on RouteSettings.name so the leave-player route
                // observer can recognise the page; the key above already pins
                // identity.
                name: state.matchedLocation,
                child: ExpandedPlayerScreen(launch: launch),
                transitionsBuilder:
                    (context, animation, secondaryAnimation, child) {
                      return FadeTransition(
                        opacity: CurvedAnimation(
                          parent: animation,
                          curve: Curves.easeOutCubic,
                        ),
                        child: child,
                      );
                    },
                transitionDuration: const Duration(milliseconds: 220),
                reverseTransitionDuration: const Duration(milliseconds: 180),
              );
            },
          ),
          GoRoute(
            name: 'youtube-login',
            path: '/youtube/login',
            builder: (context, state) => const YoutubeLoginScreen(),
          ),
          GoRoute(
            name: 'craft',
            path: '/craft',
            builder: (context, state) => const CraftScreen(),
          ),
          GoRoute(
            name: 'craft-history',
            path: '/craft/history',
            builder: (context, state) => const CraftHistoryScreen(),
          ),
          GoRoute(
            name: 'settings',
            path: '/settings',
            builder: (context, state) => const SettingsScreen(),
          ),
          GoRoute(
            name: 'settings-sync',
            path: '/settings/sync',
            builder: (context, state) => const SyncStatusScreen(),
          ),
          GoRoute(
            name: 'settings-keyboard',
            path: '/settings/keyboard',
            builder: (context, state) => const HotkeysSettingsScreen(),
          ),
          GoRoute(
            name: 'settings-ai-providers',
            path: '/settings/ai-providers',
            builder: (context, state) => const AiProvidersScreen(),
          ),
          GoRoute(
            name: 'settings-ai-playground',
            path: '/settings/ai-playground',
            builder: (context, state) => const AiPlaygroundScreen(),
          ),
          GoRoute(
            name: 'profile',
            path: '/profile',
            pageBuilder: (context, state) => _shellPage(
              key: const ValueKey<String>('shell-profile'),
              child: const ProfileScreen(),
            ),
            routes: [
              GoRoute(
                name: 'profile-edit',
                path: 'edit',
                builder: (context, state) => const ProfileEditScreen(),
              ),
              GoRoute(
                name: 'profile-preferences',
                path: 'preferences',
                builder: (context, state) => const ProfilePreferencesScreen(),
              ),
            ],
          ),
          GoRoute(
            name: 'credits',
            path: '/credits',
            builder: (context, state) => const CreditsUsageScreen(),
          ),
          GoRoute(
            name: 'subscription',
            path: '/subscription',
            builder: (context, state) => const SubscriptionScreen(),
          ),
          GoRoute(
            name: 'vocabulary',
            path: '/vocabulary',
            builder: (context, state) => const VocabularyScreen(),
          ),
          GoRoute(
            name: 'vocabulary-review',
            path: '/vocabulary/review',
            onExit: (context, state) {
              // Clear while the route context is still mounted — not in
              // State.dispose (ref / watch notify is unsafe during unmount).
              final session = ProviderScope.containerOf(
                context,
              ).read(vocabularyReviewSessionProvider.notifier);
              if (session.hasActiveSession) {
                session.clear();
              }
              return true;
            },
            builder: (context, state) => const VocabularyReviewSessionScreen(),
          ),
        ],
      ),
    ],
  );

  // Mid-launch safety net: YouTube readiness can block for seconds, so an
  // open can resolve *after* the learner already left `/player/` (#654). No
  // route transition follows, so [leavePlayerObserver] never sees it — the
  // session appearing off-route is the event to watch here. clear() bumps the
  // open generation, which makes every later step of the launch bail.
  ref.listen<bool>(
    playerControllerProvider.select((session) => session != null),
    (previous, sessionActive) {
      if (!sessionActive) return;
      if (router.state.uri.path.startsWith('/player/')) return;
      scheduleMicrotask(() => unawaited(clearLivePlaybackSession(ref)));
    },
  );
  return router;
}
