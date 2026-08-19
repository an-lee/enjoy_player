library;

import 'package:flutter/material.dart';

class LoadingIcon extends StatelessWidget {
  const LoadingIcon({
    super.key,
    this.size = 18,
    this.strokeWidth = 2,
    this.color,
    this.value,
  });

  final double size;
  final double strokeWidth;
  final Color? color;

  /// When non-null, draws a determinate spinner (`0…1`).
  final double? value;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CircularProgressIndicator(
        strokeWidth: strokeWidth,
        color: color,
        value: value,
      ),
    );
  }
}
