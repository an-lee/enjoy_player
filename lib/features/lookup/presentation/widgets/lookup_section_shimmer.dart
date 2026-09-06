/// Shimmer placeholder rows for lookup sheet async sections.
library;

import 'package:flutter/material.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';

class LookupSectionShimmer extends StatelessWidget {
  const LookupSectionShimmer({super.key});

  @override
  Widget build(BuildContext context) {
    final t = EnjoyThemeTokens.of(context);
    final tt = Theme.of(context).textTheme;

    return Padding(
      padding: EdgeInsets.symmetric(vertical: t.space4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Skeleton.line(
            width: 180,
            height: (tt.titleLarge?.fontSize ?? 22) - 2,
          ),
          SizedBox(height: t.space12),
          Skeleton.line(width: 120, height: tt.labelMedium?.fontSize ?? 12),
          SizedBox(height: t.space8),
          for (var i = 0; i < 3; i++) ...[
            Skeleton.line(
              width: i == 2 ? 220.0 : double.infinity,
              height: tt.bodyMedium?.fontSize ?? 14,
            ),
            SizedBox(height: t.space8),
          ],
          Skeleton.line(width: 260, height: tt.bodySmall?.fontSize ?? 12),
        ],
      ),
    );
  }
}
