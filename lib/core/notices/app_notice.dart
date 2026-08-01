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
      late final bool showCloseIcon;

      switch (kind) {
        case _AppNoticeKind.success:
          backgroundColor = cs.primaryContainer;
          foregroundColor = cs.onPrimaryContainer;
          icon = Icons.check_circle_rounded;
          duration = const Duration(seconds: 3);
          showCloseIcon = false;
        case _AppNoticeKind.error:
          backgroundColor = cs.errorContainer;
          foregroundColor = cs.onErrorContainer;
          icon = Icons.error_rounded;
          duration = const Duration(seconds: 5);
          showCloseIcon = true;
        case _AppNoticeKind.info:
          backgroundColor = cs.surfaceContainerHigh;
          foregroundColor = cs.onSurface;
          icon = Icons.info_rounded;
          duration = const Duration(seconds: 3);
          showCloseIcon = false;
        case _AppNoticeKind.warning:
          backgroundColor = cs.tertiaryContainer;
          foregroundColor = cs.onTertiaryContainer;
          icon = Icons.warning_rounded;
          duration = const Duration(seconds: 4);
          showCloseIcon = true;
      }

      if (kind == _AppNoticeKind.error || kind == _AppNoticeKind.warning) {
        m.clearSnackBars();
      }

      final mq = MediaQuery.of(context);
      final shellExtra = RootShellBottomInset.clearanceOf(context);
      final horizontal = tokens?.space16 ?? 16.0;
      final bottomPad =
          mq.padding.bottom + shellExtra + (tokens?.space16 ?? 16.0);
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
          showCloseIcon: showCloseIcon,
          closeIconColor: foregroundColor,
          duration: duration,
          action: action,
          margin: EdgeInsets.fromLTRB(sideMargin, 0, sideMargin, bottomPad),
          content: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(icon, color: foregroundColor, size: 22),
              SizedBox(width: tokens?.space12 ?? 12),
              Expanded(child: Text(message, style: textStyle)),
            ],
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
