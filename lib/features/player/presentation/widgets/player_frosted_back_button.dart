/// Circular frosted collapse control matching OpenDesign player `.p-back`.
library;

import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';

class PlayerFrostedBackButton extends StatelessWidget {
  const PlayerFrostedBackButton({
    required this.onPressed,
    this.iconColor = Colors.white,
    super.key,
  });

  final VoidCallback onPressed;
  final Color iconColor;

  static const double _size = 38;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: MaterialLocalizations.of(context).backButtonTooltip,
      child: Material(
        color: Colors.black.withValues(alpha: 0.45),
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: SizedBox(
              width: _size,
              height: _size,
              child: Icon(
                Icons.keyboard_arrow_down_rounded,
                color: iconColor,
                size: 20,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
