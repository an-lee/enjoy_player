/// Primary action buttons with consistent haptics and token-aware sizing.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/interaction/haptics.dart';
import 'package:enjoy_player/core/theme/colors.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';

enum EnjoyButtonVariant {
  primary,
  secondary,
  soft,
  ghost,
  destructive,
  echo,
  intelligence,
}

enum EnjoyButtonSize { regular, small, large, icon }

class EnjoyButton extends StatelessWidget {
  const EnjoyButton._({
    super.key,
    required this.variant,
    required this.onPressed,
    this.icon,
    required this.child,
    this.size = EnjoyButtonSize.regular,
  });

  factory EnjoyButton.primary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.primary,
    onPressed: onPressed,
    icon: icon,
    size: size,
    key: key,
    child: child,
  );

  factory EnjoyButton.secondary({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.secondary,
    onPressed: onPressed,
    icon: icon,
    size: size,
    key: key,
    child: child,
  );

  /// Soft / quiet translucent background with accent ink foreground.
  factory EnjoyButton.soft({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.soft,
    onPressed: onPressed,
    icon: icon,
    size: size,
    key: key,
    child: child,
  );

  factory EnjoyButton.quiet({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton.soft(
    key: key,
    onPressed: onPressed,
    icon: icon,
    size: size,
    child: child,
  );

  factory EnjoyButton.ghost({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.ghost,
    onPressed: onPressed,
    icon: icon,
    size: size,
    key: key,
    child: child,
  );

  factory EnjoyButton.destructive({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.destructive,
    onPressed: onPressed,
    icon: icon,
    size: size,
    key: key,
    child: child,
  );

  factory EnjoyButton.echo({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.echo,
    onPressed: onPressed,
    icon: icon,
    size: size,
    key: key,
    child: child,
  );

  factory EnjoyButton.intelligence({
    Key? key,
    required VoidCallback? onPressed,
    required Widget child,
    IconData? icon,
    EnjoyButtonSize size = EnjoyButtonSize.regular,
  }) => EnjoyButton._(
    variant: EnjoyButtonVariant.intelligence,
    onPressed: onPressed,
    icon: icon,
    size: size,
    key: key,
    child: child,
  );

  final EnjoyButtonVariant variant;
  final VoidCallback? onPressed;
  final Widget child;
  final IconData? icon;
  final EnjoyButtonSize size;

  void _handleTap(BuildContext context) {
    if (onPressed == null) return;
    Haptics.selection(context);
    onPressed!();
  }

  EdgeInsetsGeometry _padding(EnjoyThemeTokens t) {
    switch (size) {
      case EnjoyButtonSize.small:
        return EdgeInsets.symmetric(horizontal: t.space12, vertical: t.space8);
      case EnjoyButtonSize.large:
        return EdgeInsets.symmetric(horizontal: t.space24, vertical: t.space16);
      case EnjoyButtonSize.icon:
        return EdgeInsets.all(t.space12);
      case EnjoyButtonSize.regular:
        return EdgeInsets.symmetric(horizontal: t.space20, vertical: t.space12);
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final cs = Theme.of(context).colorScheme;
    final iconSize = size == EnjoyButtonSize.small ? 16.0 : 18.0;

    final label = icon != null
        ? Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: iconSize),
              SizedBox(width: t.space8),
              Flexible(child: child),
            ],
          )
        : child;

    final tap = onPressed == null ? null : () => _handleTap(context);
    final padding = _padding(t);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(
        size == EnjoyButtonSize.icon ? t.radiusFull : t.radiusMd,
      ),
    );

    /// Hover/press darkens the *fill*, never the label (prototype rule).
    ButtonStyle overlayOn(Color background, Color foreground) {
      return ButtonStyle(
        backgroundColor: WidgetStateProperty.all(background),
        foregroundColor: WidgetStateProperty.all(foreground),
        overlayColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.pressed)) {
            return Colors.black.withValues(alpha: 0.16);
          }
          if (states.contains(WidgetState.hovered)) {
            return Colors.black.withValues(alpha: 0.10);
          }
          return Colors.transparent;
        }),
        padding: WidgetStateProperty.all(padding),
        shape: WidgetStateProperty.all(shape),
        elevation: WidgetStateProperty.all(0),
        minimumSize: size == EnjoyButtonSize.icon
            ? WidgetStateProperty.all(const Size(44, 44))
            : null,
      );
    }

    switch (variant) {
      case EnjoyButtonVariant.primary:
        return FilledButton(
          onPressed: tap,
          style: overlayOn(cs.primary, cs.onPrimary),
          child: label,
        );
      case EnjoyButtonVariant.secondary:
        return FilledButton(
          onPressed: tap,
          style: overlayOn(cs.surface, cs.onSurface).copyWith(
            side: WidgetStateProperty.all(BorderSide(color: cs.outline)),
          ),
          child: label,
        );
      case EnjoyButtonVariant.soft:
        return FilledButton(
          onPressed: tap,
          style: overlayOn(t.accentSoft, t.accentInk),
          child: label,
        );
      case EnjoyButtonVariant.ghost:
        return TextButton(
          onPressed: tap,
          style: overlayOn(Colors.transparent, cs.onSurface),
          child: label,
        );
      case EnjoyButtonVariant.destructive:
        return FilledButton(
          onPressed: tap,
          style: overlayOn(cs.errorContainer, cs.onErrorContainer),
          child: label,
        );
      case EnjoyButtonVariant.echo:
        return FilledButton(
          onPressed: tap,
          style: overlayOn(t.echoActive, AppColors.onAccent),
          child: label,
        );
      case EnjoyButtonVariant.intelligence:
        return FilledButton(
          onPressed: tap,
          style: overlayOn(cs.secondary, cs.onSecondary),
          child: label,
        );
    }
  }
}
