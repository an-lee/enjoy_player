/// Application shell: adaptive navigation + page stack + player-route transport.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/notices/root_shell_bottom_inset.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/app_background.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_bottom_nav.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_chrome_icon.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_showcase_host.dart';
import 'package:enjoy_player/features/subscription/presentation/tier_reconcile_host.dart';
import 'package:enjoy_player/features/sync/application/sync_controller.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

import '../application/player_controller.dart';
import 'widgets/app_sidebar.dart';
import 'widgets/global_transport_bar.dart';
import 'widgets/player_surface_host.dart';

class RootShell extends ConsumerStatefulWidget {
  const RootShell({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<RootShell> createState() => _RootShellState();
}

class _RootShellState extends ConsumerState<RootShell> {
  int _navIndexForPath(String path) {
    if (path.startsWith('/profile') || path.startsWith('/settings')) return 3;
    if (path.startsWith('/library') || path.startsWith('/cloud')) return 2;
    if (path.startsWith('/discover')) return 1;
    return 0;
  }

  void _goNavIndex(BuildContext context, int index) {
    switch (index) {
      case 0:
        context.go('/');
        return;
      case 1:
        context.go('/discover');
        return;
      case 2:
        context.go('/library');
        return;
      case 3:
        context.go('/profile');
        return;
      default:
        context.go('/');
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.watch(syncCtrlProvider);
    ref.watch(discoverFeedRefreshSchedulerProvider);
    final sessionActive = ref.watch(
      playerControllerProvider.select((s) => s != null),
    );
    final updateBadge = ref.watch(updateAvailableBadgeProvider);
    final l10n = AppLocalizations.of(context)!;
    final path = GoRouterState.of(context).uri.path;
    final onPlayer = path.startsWith('/player/');
    // Immersive flashcard review: hide shell chrome (sidebar / bottom nav)
    // while `/vocabulary/review` is active — same path-flag family as
    // `/player/` nav hiding (specs/033-immersive-flashcard-review).
    final onReview = path.startsWith('/vocabulary/review');

    return OnboardingShowcaseHost(
      child: TierReconcileHost(
        child: AppBackground(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final tokens = EnjoyThemeTokens.of(context);
              final useSidebar =
                  constraints.maxWidth >= tokens.breakpointRail &&
                  !onPlayer &&
                  !onReview;

              final bottomNav = (!useSidebar && !onPlayer && !onReview)
                  ? EnjoyBottomNav(
                      selectedIndex: _navIndexForPath(path),
                      onDestinationSelected: (i) => _goNavIndex(context, i),
                      destinations: [
                        EnjoyBottomNavDestination(
                          icon: Icons.home_outlined,
                          selectedIcon: Icons.home_rounded,
                          iconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.home,
                          ),
                          selectedIconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.home,
                          ),
                          label: l10n.homeTitle,
                        ),
                        EnjoyBottomNavDestination(
                          icon: Icons.explore_outlined,
                          selectedIcon: Icons.explore_rounded,
                          iconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.compass,
                          ),
                          selectedIconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.compass,
                          ),
                          label: l10n.discoverTitle,
                        ),
                        EnjoyBottomNavDestination(
                          icon: Icons.collections_bookmark_outlined,
                          selectedIcon: Icons.collections_bookmark_rounded,
                          iconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.library,
                          ),
                          selectedIconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.library,
                          ),
                          label: l10n.libraryTitle,
                        ),
                        EnjoyBottomNavDestination(
                          icon: Icons.person_outlined,
                          selectedIcon: Icons.person_rounded,
                          iconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.user,
                          ),
                          selectedIconWidget: const EnjoyChromeIcon(
                            EnjoyChromeGlyph.user,
                          ),
                          label: l10n.profileTitle,
                          showBadge: updateBadge,
                          semanticsLabel: updateBadge
                              ? '${l10n.profileTitle}, ${l10n.updateAvailableBadgeSemantics}'
                              : null,
                        ),
                      ],
                    )
                  : null;

              /// `/player/...` nests a [Scaffold] inside the route. Keeping transport in a
              /// [Column] + [Expanded] sibling can yield **zero** body height on some mobile
              /// frames (nested scaffold / safe-area constraint propagation), which pins the
              /// bar under the status bar and hides video + transcript. [Scaffold] reserves
              /// space via [bottomNavigationBar] instead.
              final playerWithTransport = sessionActive && onPlayer;

              // Leaving the player tears the live session down in
              // [LeavePlayerRouteObserver] (registered on the shell navigator
              // in `app_router.dart`) — never from a build: a build-posted
              // teardown re-fires on every rebuild that still holds the
              // condition, and only stayed safe because clear() bumps the
              // open generation.

              final bottomClearance = !useSidebar && !onPlayer && !onReview
                  ? rootShellBottomNavClearance(context)
                  : 0.0;

              Widget mobileShellScaffold() {
                if (playerWithTransport) {
                  // Same floating treatment as [EnjoyBottomNav]: transparent
                  // scaffold + [extendBody] so transcript / [AppBackground]
                  // show around (and through) the glass capsule. Native video
                  // stays in the upper [PlayerSurfaceTarget] stage, not in this
                  // bottom slot (ADR-0066 parks the surface for overlays).
                  return Scaffold(
                    backgroundColor: Colors.transparent,
                    extendBody: true,
                    body: SafeArea(
                      bottom: false,
                      child: SizedBox.expand(child: widget.child),
                    ),
                    bottomNavigationBar: Material(
                      type: MaterialType.transparency,
                      child: SafeArea(
                        top: false,
                        left: false,
                        right: false,
                        minimum: EdgeInsets.fromLTRB(
                          tokens.space16,
                          tokens.space4,
                          tokens.space16,
                          tokens.space12,
                        ),
                        child: const GlobalTransportBar(),
                      ),
                    ),
                  );
                }
                // Transparent + [extendBody] so [AppBackground] and page content
                // show around (and through) the floating glass capsule. Do not
                // wrap the nav in a [Column] inside [SafeArea] — that paints an
                // opaque home-indicator tray behind the bar.
                return Scaffold(
                  backgroundColor: Colors.transparent,
                  extendBody: bottomNav != null,
                  body: SafeArea(
                    bottom: false,
                    child: Padding(
                      key: const ValueKey<String>('root-shell-content'),
                      padding: EdgeInsets.only(bottom: bottomClearance),
                      child: widget.child,
                    ),
                  ),
                  bottomNavigationBar: bottomNav == null
                      ? null
                      : Material(
                          type: MaterialType.transparency,
                          child: bottomNav,
                        ),
                );
              }

              final shell = useSidebar
                  ? RootShellBottomInset(
                      bottomClearance: bottomClearance,
                      child: Scaffold(
                        backgroundColor: Colors.transparent,
                        body: SafeArea(
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Semantics(
                                container: true,
                                label: l10n.navMainLabel,
                                child: const AppSidebar(),
                              ),
                              Expanded(child: widget.child),
                            ],
                          ),
                        ),
                      ),
                    )
                  : RootShellBottomInset(
                      bottomClearance: bottomClearance,
                      child: mobileShellScaffold(),
                    );

              // Permanent video/WebView surface — follows PlayerSurfaceTarget.
              // Park while `/youtube/login` is open: that route pushes above the
              // player page (target stays attached) but this host paints above
              // the whole shell, so an unparked stage covers the login WebView.
              // Overlays (dialogs/sheets/snackbars, ADR-0066) are handled inside
              // [PlayerSurfaceHost] — watching the coordinator here used to
              // rebuild the whole shell (nav, sidebar, both scaffolds) on every
              // dialog/sheet/notice token change (issue #663).
              final parkForYoutubeLogin = path.startsWith('/youtube/login');
              return Stack(
                fit: StackFit.expand,
                children: [
                  shell,
                  PlayerSurfaceHost(forcePark: parkForYoutubeLogin),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
