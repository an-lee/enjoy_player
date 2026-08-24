import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/app_theme.dart';
import 'package:enjoy_player/core/theme/colors.dart';

void main() {
  test('dark overlay uses graphite navigation bar', () {
    final style = enjoySystemUiOverlayStyle(Brightness.dark);
    expect(
      style.systemNavigationBarColor,
      AppColors.surfaceContainerLowestDark,
    );
    expect(style.systemNavigationBarIconBrightness, Brightness.light);
    expect(style.statusBarIconBrightness, Brightness.light);
    expect(style.statusBarColor, Colors.transparent);
  });

  test('light overlay uses paper navigation bar', () {
    final style = enjoySystemUiOverlayStyle(Brightness.light);
    expect(
      style.systemNavigationBarColor,
      AppColors.surfaceContainerLowestLight,
    );
    expect(style.systemNavigationBarIconBrightness, Brightness.dark);
    expect(style.statusBarIconBrightness, Brightness.dark);
    expect(AppColors.surfaceContainerLowestLight, const Color(0xFFF7F6F1));
    expect(AppColors.surfaceContainerLowestDark, const Color(0xFF0D0E14));
  });

  testWidgets('AnnotatedRegion follows Theme brightness', (tester) async {
    late SystemUiOverlayStyle captured;
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            captured = enjoySystemUiOverlayStyle(Theme.of(context).brightness);
            return AnnotatedRegion<SystemUiOverlayStyle>(
              value: captured,
              child: const SizedBox.shrink(),
            );
          },
        ),
      ),
    );
    expect(
      captured.systemNavigationBarColor,
      AppColors.surfaceContainerLowestLight,
    );
    expect(captured.systemNavigationBarIconBrightness, Brightness.dark);
  });
}
