import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/app_background.dart';

Widget _harness(ThemeData theme, Widget child) {
  return MaterialApp(
    theme: theme,
    home: Scaffold(body: child),
  );
}

ThemeData _theme(Brightness brightness) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: brightness,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    extensions: [EnjoyThemeTokens.build(scheme)],
  );
}

void main() {
  group('AppBackground', () {
    testWidgets('wraps child in a LinearGradient in dark mode', (tester) async {
      await tester.pumpWidget(
        _harness(
          _theme(Brightness.dark),
          const AppBackground(child: Text('inside')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('inside'), findsOneWidget);
      // The decorated box's decoration is a BoxDecoration wrapping a
      // LinearGradient.
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppBackground),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect(box.decoration, isA<BoxDecoration>());
      expect((box.decoration as BoxDecoration).gradient, isA<LinearGradient>());
    });

    testWidgets('wraps child in a LinearGradient in light mode', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          _theme(Brightness.light),
          const AppBackground(child: Text('inside')),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(AppBackground),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).gradient, isA<LinearGradient>());
    });
  });

  group('PlayerAmbientBackdrop', () {
    testWidgets('passes child through unchanged when accentColor is null', (
      tester,
    ) async {
      const key = ValueKey('child');
      await tester.pumpWidget(
        _harness(
          _theme(Brightness.dark),
          const PlayerAmbientBackdrop(child: Text('inside', key: key)),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(key), findsOneWidget);
      // No Stack is created when accentColor is null.
      expect(
        find.descendant(
          of: find.byType(PlayerAmbientBackdrop),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
    });

    testWidgets('renders a radial tint overlay when accentColor is provided', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          _theme(Brightness.dark),
          const PlayerAmbientBackdrop(
            accentColor: Color(0xFFFF7F50),
            intensity: 0.10,
            child: Text('inside'),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final box = tester.widget<DecoratedBox>(
        find.descendant(
          of: find.byType(PlayerAmbientBackdrop),
          matching: find.byType(DecoratedBox),
        ),
      );
      expect((box.decoration as BoxDecoration).gradient, isA<RadialGradient>());
      expect(find.text('inside'), findsOneWidget);
    });
  });
}
