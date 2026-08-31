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

/// Typed, theme-aware SnackBars for lightweight feedback.
abstract final class AppNotice {
  static void success(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) => _show(context, _AppNoticeKind.success, message, action: action);

  static void error(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) => _show(context, _AppNoticeKind.error, message, action: action);

  static void info(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) => _show(context, _AppNoticeKind.info, message, action: action);

  /// Partial failures, warnings, or attention-worthy non-errors.
  static void warning(
    BuildContext context,
    String message, {
    SnackBarAction? action,
  }) => _show(context, _AppNoticeKind.warning, message, action: action);

  static void _show(
    BuildContext context,
    _AppNoticeKind kind,
    String message, {
    SnackBarAction? action,
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
      final tokens = theme.extension<EnjoyThemeTokens>();

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
      final horizontal = tokens?.space16 ?? 16.0;
      // padding.bottom can exceed the physical safe inset when an ancestor
      // Scaffold reports an over-tall bottomNavigationBar (extendBody feeds
      // max(padding, bottomWidgetsHeight) into the body MediaQuery). Clamp to
      // viewPadding so a leaked inset can never push the notice off screen —
      // a floating SnackBar taller than the screen aborts every layout.
      final safeBottom = math.min(mq.padding.bottom, mq.viewPadding.bottom);
      final bottomPad = safeBottom + shellExtra + (tokens?.space16 ?? 16.0);
      final maxW = mq.size.width;
      final innerMax = math.max(0.0, maxW - horizontal * 2);
      final snackMaxWidth = maxW >= 600 && innerMax > 0
          ? math.min(520.0, innerMax)
          : null;
      final sideMargin = snackMaxWidth != null
          ? math.max(horizontal, (maxW - snackMaxWidth) / 2)
          : horizontal;

      final radius = tokens?.radiusXl ?? 16.0;
      final elevation = tokens?.elevationSheet ?? 3.0;

      final textStyle = theme.textTheme.bodyMedium?.copyWith(
        color: foregroundColor,
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
          // Both the action and the dismiss button are laid out by
          // [_AppNoticeBody] instead of SnackBar's own slots: once the built-in
          // action is wider than `actionOverflowThreshold` (25% of the bar by
          // default) Flutter moves it onto its own row and still reserves 40%
          // of the width beside the message, which squeezed the
          // credits-exhausted copy into a ~60% column on phones.
          showCloseIcon: false,
          duration: duration,
          // SnackBar infers `persist` from `action != null`; the action now
          // lives in the body, so actionable notices opt in explicitly and keep
          // waiting for the user instead of timing out.
          persist: action != null,
          margin: EdgeInsets.fromLTRB(sideMargin, 0, sideMargin, bottomPad),
          content: _AppNoticeBody(
            icon: icon,
            message: message,
            textStyle: textStyle,
            foregroundColor: foregroundColor,
            gap: tokens?.space12 ?? 12,
            action: action,
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

/// Notice body: semantic icon, full-width message, and an optional trailing
/// row with the action and the dismiss button.
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
    required this.gap,
    this.action,
    this.onDismiss,
  });

  final IconData icon;
  final String message;
  final TextStyle? textStyle;
  final Color foregroundColor;
  final double gap;
  final SnackBarAction? action;
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    final tokens = Theme.of(context).extension<EnjoyThemeTokens>();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: foregroundColor, size: 22),
            SizedBox(width: gap),
            Expanded(child: Text(message, style: textStyle)),
          ],
        ),
        if (action != null || onDismiss != null)
          Padding(
            padding: EdgeInsets.only(top: tokens?.space4 ?? 4),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                if (action != null)
                  // Flexible so a long localized label shrinks with the bar
                  // instead of overflowing it; the dismiss button stays whole.
                  Flexible(
                    // Layout only: [SnackBarAction] resolves its own label
                    // color and keeps its one-shot + auto-dismiss behaviour.
                    // The horizontal padding replaces the margin SnackBar used
                    // to add around its own action slot.
                    child: TextButtonTheme(
                      data: TextButtonThemeData(
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.symmetric(
                            horizontal: tokens?.space8 ?? 8,
                          ),
                        ),
                      ),
                      child: action!,
                    ),
                  ),
                if (onDismiss != null)
                  IconButton(
                    tooltip: MaterialLocalizations.of(context).closeButtonLabel,
                    onPressed: onDismiss,
                    icon: const Icon(Icons.close),
                    iconSize: 22,
                    color: foregroundColor,
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints.tightFor(
                      width: 40,
                      height: 40,
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}
