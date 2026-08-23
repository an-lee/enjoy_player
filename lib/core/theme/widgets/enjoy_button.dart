/// Primary action buttons with consistent haptics and token-aware sizing.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

enum EnjoyButtonVariant { primary, secondary, soft, ghost, destructive }

class EnjoyButton extends StatelessWidget {
  const EnjoyButton._({
    super.key,
    required this.variant,
    required this.onPressed,
    this.icon,
    required this.child,
  });

  factory EnjoyButton.primary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.primary,
    onPressed: onPressed,
    icon: icon,
    key: key,
    child: child,
  );

  factory EnjoyButton.secondary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.secondary,
    onPressed: onPressed,
    icon: icon,
    key: key,
    child: child,
  );

  /// Soft translucent background with primary color foreground.
  factory EnjoyButton.soft({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.soft,
    onPressed: onPressed,
    icon: icon,
    key: key,
    child: child,
  );

  factory EnjoyButton.ghost({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.ghost,
    onPressed: onPressed,
    icon: icon,
    key: key,
    child: child,
  );

  factory EnjoyButton.destructive({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.destructive,
    onPressed: onPressed,
    icon: icon,
    key: key,
    child: child,
  );

  final EnjoyButtonVariant variant;
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;

  void _handleTap(BuildContext context) {
    if (onPressed == null) return;
    Haptics.selection(context);
    onPressed!();
  }

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;

    final label = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 18),
              SizedBox(width: t.space8),
              Flexible(child: child),
            ],
          )
        : child;

    switch (variant) {
      case EnjoyButtonVariant.primary:
        return FilledButton(
          onPressed: onPressed == null ? null : () => _handleTap(context),
          child: label,
        );
      case EnjoyButtonVariant.secondary:
        return FilledButton.tonal(
          onPressed: onPressed == null ? null : () => _handleTap(context),
          child: label,
        );
      case EnjoyButtonVariant.soft:
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: t.accentSoft,
            foregroundColor: cs.primary,
          ),
          onPressed: onPressed == null ? null : () => _handleTap(context),
          child: label,
        );
      case EnjoyButtonVariant.ghost:
        return TextButton(
          onPressed: onPressed == null ? null : () => _handleTap(context),
          child: label,
        );
      case EnjoyButtonVariant.destructive:
        return FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: cs.error,
            foregroundColor: cs.onError,
          ),
          onPressed: onPressed == null ? null : () => _handleTap(context),
          child: label,
        );
    }
  }
}
