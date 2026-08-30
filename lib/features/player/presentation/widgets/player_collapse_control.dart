/// The player's always-visible collapse control (ADR-0085).
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/features/player/application/player_collapse.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_frosted_back_button.dart';

/// Frosted `.p-back` circle that pops the expanded player back to its origin
/// route.
///
/// The three host layouts (video stage overlay, audio layout, loading-stage
/// chrome) differ only in how the button is inset and whether a toolbar-sized
/// slot / safe-area inset is reserved for it, so those knobs cover every call
/// site — there is exactly one collapse control implementation.
class PlayerCollapseControl extends ConsumerWidget {
  const PlayerCollapseControl({
    this.inset = const EdgeInsets.only(left: 8, top: 8),
    this.reserveToolbarHeight = false,
    this.useSafeArea = false,
    super.key,
  });

  /// Loading / minimal-chrome shape: the control is the only element of a
  /// `kToolbarHeight` title bar, so it is centered in that slot and insets
  /// horizontally only ([reserveToolbarHeight] centering already accounts for
  /// the vertical position).
  const PlayerCollapseControl.loadingChrome({
    this.useSafeArea = false,
    super.key,
  }) : inset = const EdgeInsets.only(left: 8),
       reserveToolbarHeight = true;

  /// Padding around the frosted button inside its alignment slot.
  ///
  /// Defaults to the on-stage inset (8 px from the top-left corner); hosts
  /// that need to clear a status bar or a neighbouring inset pass their own.
  final EdgeInsetsGeometry inset;

  /// When true, reserves a `kToolbarHeight` slot and centers the button in it
  /// (the loading / minimal-chrome shape, where the control is the only
  /// element of a title bar). When false the button is pinned to the
  /// top-left of the enclosing [Stack] — the on-stage shape.
  final bool reserveToolbarHeight;

  /// When true, wraps the control in a top-only [SafeArea] so it clears the
  /// status bar on phones.
  final bool useSafeArea;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    Widget content = Padding(
      padding: inset,
      child: PlayerFrostedBackButton(
        onPressed: () => unawaited(collapseExpandedPlayer(ref, context)),
      ),
    );
    content = reserveToolbarHeight
        ? SizedBox(
            height: kToolbarHeight,
            child: Align(alignment: Alignment.centerLeft, child: content),
          )
        : Align(alignment: Alignment.topLeft, child: content);
    if (!useSafeArea) return content;
    return SafeArea(bottom: false, left: false, right: false, child: content);
  }
}
