/// Material 3 in-app notices (SnackBars) with semantic styling and shell-aware margins.
library;

import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/core/notices/root_shell_bottom_inset.dart';
import 'package:enjoy_player/core/player/player_surface_overlay_coordinator.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

final _log = logNamed('AppNotice');

/// Root [ScaffoldMessenger] so notices work from any [BuildContext] (e.g. hotkeys).
final GlobalKey<ScaffoldMessengerState> appScaffoldMessengerKey =
    GlobalKey<ScaffoldMessengerState>();

enum _AppNoticeKind { success, error, info, warning }

/// An action button rendered inside the notice body.
///
/// Deliberately not [SnackBarAction]: SnackBar's own action slot squeezes the
/// message (see the note in [AppNotice._show]), and its label can neither
/// ellipsize nor take the notice palette. The body renders the button itself;
/// pressing it once fires [AppNoticeAction.onPressed] and dismisses the
/// notice, like [SnackBarAction].
typedef AppNoticeAction = ({String label, VoidCallback onPressed});

/// Typed, theme-aware SnackBars for lightweight feedback.
abstract final class AppNotice {
  static void success(
    BuildContext context,
    String message, {
    AppNoticeAction? action,
  }) => _show(context, _AppNoticeKind.success, message, action: action);

  static void error(
    BuildContext context,
    String message, {
    AppNoticeAction? action,
  }) => _show(context, _AppNoticeKind.error, message, action: action);

  static void info(
    BuildContext context,
    String message, {
    AppNoticeAction? action,
  }) => _show(context, _AppNoticeKind.info, message, action: action);

  /// Partial failures, warnings, or attention-worthy non-errors.
  static void warning(
    BuildContext context,
    String message, {
    AppNoticeAction? action,
  }) => _show(context, _AppNoticeKind.warning, message, action: action);

  static void _show(
    BuildContext context,
    _AppNoticeKind kind,
    String message, {
    AppNoticeAction? action,
  }) {
    if (!context.mounted) return;
    if (appScaffoldMessengerKey.currentState == null &&
        ScaffoldMessenger.maybeOf(context) == null) {
      _log.warning(
        'AppNotice skipped: no ScaffoldMessenger (global key unset and '
        'ScaffoldMessenger.maybeOf(context) is null)',
      );
      return;
    }

    if (kind == _AppNoticeKind.success || kind == _AppNoticeKind.info) {
      Haptics.success(context);
    } else {
      Haptics.warning(context);
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!context.mounted) return;
      final m =
          appScaffoldMessengerKey.currentState ??
          ScaffoldMessenger.maybeOf(context);
      if (m == null) {
        _log.warning(
          'AppNotice skipped after frame: ScaffoldMessenger no longer available',
        );
        return;
      }

      final theme = Theme.of(context);
      final cs = theme.colorScheme;
      final tokens = EnjoyThemeTokens.of(context);

      late final Color backgroundColor;
      late final Color foregroundColor;
      late final IconData icon;
      late final Duration duration;
      late final bool wantsDismiss;

      switch (kind) {
        case _AppNoticeKind.success:
          backgroundColor = cs.primaryContainer;
          foregroundColor = cs.onPrimaryContainer;
          icon = Icons.check_circle_rounded;
          duration = const Duration(seconds: 3);
          wantsDismiss = false;
        case _AppNoticeKind.error:
          backgroundColor = cs.errorContainer;
          foregroundColor = cs.onErrorContainer;
          icon = Icons.error_rounded;
          duration = const Duration(seconds: 5);
          wantsDismiss = true;
        case _AppNoticeKind.info:
          backgroundColor = cs.surfaceContainerHigh;
          foregroundColor = cs.onSurface;
          icon = Icons.info_rounded;
          duration = const Duration(seconds: 3);
          wantsDismiss = false;
        case _AppNoticeKind.warning:
          backgroundColor = cs.tertiaryContainer;
          foregroundColor = cs.onTertiaryContainer;
          icon = Icons.warning_rounded;
          duration = const Duration(seconds: 4);
          wantsDismiss = true;
      }

      if (kind == _AppNoticeKind.error || kind == _AppNoticeKind.warning) {
        m.clearSnackBars();
      }

      final mq = MediaQuery.of(context);
      final shellExtra = RootShellBottomInset.clearanceOf(context);
      final horizontal = tokens.space16;
      // padding.bottom can exceed the physical safe inset when an ancestor
      // Scaffold reports an over-tall bottomNavigationBar (extendBody feeds
      // max(padding, bottomWidgetsHeight) into the body MediaQuery). Clamp to
      // viewPadding so a leaked inset can never push the notice off screen —
      // a floating SnackBar taller than the screen aborts every layout.
      final safeBottom = math.min(mq.padding.bottom, mq.viewPadding.bottom);
      final bottomPad = safeBottom + shellExtra + tokens.space16;
      final maxW = mq.size.width;
      final innerMax = math.max(0.0, maxW - horizontal * 2);
      final snackMaxWidth = maxW >= 600 && innerMax > 0
          ? math.min(520.0, innerMax)
          : null;
      final sideMargin = snackMaxWidth != null
          ? math.max(horizontal, (maxW - snackMaxWidth) / 2)
          : horizontal;

      final radius = tokens.radiusXl;
      final elevation = tokens.elevationSheet;

      final textStyle = theme.textTheme.bodyMedium?.copyWith(
        color: foregroundColor,
      );

      // One-shot like [SnackBarAction]: fire once, then dismiss.
      var actionTriggered = false;
      final bodyAction = action == null
          ? null
          : (
              label: action.label,
              onPressed: () {
                if (actionTriggered) return;
                actionTriggered = true;
                action.onPressed();
                m.hideCurrentSnackBar(reason: SnackBarClosedReason.action);
              },
            );

      // Park the permanent player surface while the snackbar is visible so
      // WebView2 / media_kit platform views cannot cover the notice (ADR-0066).
      final overlayHold = _acquireOverlayHold(context);

      final controller = m.showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          elevation: elevation,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radius),
          ),
          backgroundColor: backgroundColor,
          duration: duration,
          // SnackBar infers `persist` from `action != null`; the action now
          // lives in the body, so actionable notices opt in explicitly and
          // keep waiting for the user instead of timing out.
          persist: action != null,
          margin: EdgeInsets.fromLTRB(sideMargin, 0, sideMargin, bottomPad),
          // The action and the dismiss button are laid out by
          // [_AppNoticeBody] instead of SnackBar's own slots: once the
          // built-in action is wider than `actionOverflowThreshold` (25% of
          // the bar by default) Flutter moves it onto its own row and still
          // reserves 40% of the width beside the message, which squeezed the
          // credits-exhausted copy into a ~60% column on phones. Padding is
          // owned here too, so the SDK's vertical padding wraps the message
          // row only and never stacks around the trailing action row.
          padding: EdgeInsets.symmetric(horizontal: tokens.space16),
          content: _AppNoticeBody(
            icon: icon,
            message: message,
            textStyle: textStyle,
            foregroundColor: foregroundColor,
            action: bodyAction,
            onDismiss: wantsDismiss
                ? () => m.hideCurrentSnackBar(
                    reason: SnackBarClosedReason.dismiss,
                  )
                : null,
          ),
        ),
      );

      if (overlayHold != null) {
        unawaited(controller.closed.whenComplete(overlayHold.release));
      }
    });
  }

  /// Captures the Riverpod container at show-time so release still works after
  /// the calling [BuildContext] unmounts.
  static ({VoidCallback release})? _acquireOverlayHold(BuildContext context) {
    try {
      final container = ProviderScope.containerOf(context, listen: false);
      final coordinator = container.read(
        playerSurfaceOverlayCoordinatorProvider.notifier,
      );
      final token = coordinator.acquire('notice');
      return (release: () => coordinator.release(token));
    } on Object {
      // No ProviderScope (e.g. isolated widget tests) — snackbar still shows.
      return null;
    }
  }
}

/// Notice body: semantic icon and a full-width message. The dismiss button
/// rides inline with the message while it is alone (SnackBar's own geometry),
/// and moves into a trailing row beside the action otherwise — minus the 40%
/// width reserve [SnackBar] hard-codes for overflowing actions.
///
/// Laid out here rather than through [SnackBar.action] /
/// [SnackBar.showCloseIcon] so the message always owns the bar's full inner
/// width — see the note in [AppNotice._show].
class _AppNoticeBody extends StatelessWidget {
  const _AppNoticeBody({
    required this.icon,
    required this.message,
    required this.textStyle,
    required this.foregroundColor,
    this.action,
    this.onDismiss,
  });

  final IconData icon;
  final String message;
  final TextStyle? textStyle;
  final Color foregroundColor;
  final AppNoticeAction? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = EnjoyThemeTokens.of(context);
    final action = this.action;
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: foregroundColor, size: 22),
            SizedBox(width: tokens.space12),
            Expanded(
              // Vertical rhythm matches SnackBar's own single-line padding, so
              // a dismiss-only notice is exactly as tall as the default
              // layout it replaced.
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Text(message, style: textStyle),
              ),
            ),
            if (action == null && onDismiss != null) _dismissButton(context),
          ],
        ),
        if (action != null)
          Padding(
            padding: EdgeInsets.only(top: tokens.space4, bottom: 14),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                // Flexible + maxLines so a long localized label ellipsizes
                // instead of wrapping the button or overflowing the bar.
                Flexible(
                  child: TextButton(
                    style: TextButton.styleFrom(
                      foregroundColor: foregroundColor,
                      padding: EdgeInsets.symmetric(horizontal: tokens.space8),
                    ),
                    onPressed: action.onPressed,
                    child: Text(
                      action.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                if (onDismiss != null) _dismissButton(context),
              ],
            ),
          ),
      ],
    );
  }

  /// Same affordance as SnackBar's built-in close icon: SDK semantics key,
  /// 24dp glyph, `closeButtonTooltip`, and the default 48dp tap target.
  Widget _dismissButton(BuildContext context) => IconButton(
    key: StandardComponentType.closeButton.key,
    tooltip: MaterialLocalizations.of(context).closeButtonTooltip,
    onPressed: onDismiss,
    icon: const Icon(Icons.close),
    iconSize: 24,
    color: foregroundColor,
  );
}
