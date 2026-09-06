import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/app_theme.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_button.dart';

Widget _host({required Brightness brightness, required Widget child}) {
  return MaterialApp(
    theme: buildAppTheme(brightness),
    home: Scaffold(body: Center(child: child)),
  );
}

void main() {
  testWidgets('primary button keeps an opaque label in light and dark', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        _host(
          brightness: brightness,
          child: EnjoyButton.primary(onPressed: () {}, child: const Text('Go')),
        ),
      );
      await tester.pumpAndSettle();
      final text = tester.widget<Text>(find.text('Go'));
      expect(text.style?.color, isNull);
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      final fg = button.style?.foregroundColor?.resolve({});
      expect(fg, isNotNull);
      expect(fg!.a, 1.0);
    }
  });

  testWidgets('hover darkens fill overlay without fading the label', (
    tester,
  ) async {
    for (final brightness in [Brightness.light, Brightness.dark]) {
      await tester.pumpWidget(
        _host(
          brightness: brightness,
          child: EnjoyButton.primary(onPressed: () {}, child: const Text('Go')),
        ),
      );
      await tester.pumpAndSettle();
      final button = tester.widget<FilledButton>(find.byType(FilledButton));
      const hovered = {WidgetState.hovered};
      final idleFg = button.style?.foregroundColor?.resolve({});
      final hoverFg = button.style?.foregroundColor?.resolve(hovered);
      expect(idleFg?.a, 1.0);
      expect(hoverFg, idleFg);
      final hoverOverlay = button.style?.overlayColor?.resolve(hovered);
      expect(hoverOverlay, isNotNull);
      expect(hoverOverlay!.a, greaterThan(0));
    }
  });
}
