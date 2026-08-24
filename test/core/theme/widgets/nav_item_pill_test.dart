import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/nav_item_pill.dart';

Widget _harness(Widget child) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return MaterialApp(
    theme: ThemeData(
      colorScheme: scheme,
      extensions: [EnjoyThemeTokens.build(scheme)],
    ),
    home: Scaffold(body: child),
  );
}

void main() {
  group('NavItemPill', () {
    testWidgets('renders the label and the unselected icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          NavItemPill(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
            selected: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Home'), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.home_rounded), findsNothing);
    });

    testWidgets('uses selectedIcon when selected', (tester) async {
      await tester.pumpWidget(
        _harness(
          NavItemPill(
            icon: Icons.home_outlined,
            selectedIcon: Icons.home_rounded,
            label: 'Home',
            selected: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.home_rounded), findsOneWidget);
      expect(find.byIcon(Icons.home_outlined), findsNothing);
    });

    testWidgets('falls back to icon when selectedIcon is null', (tester) async {
      await tester.pumpWidget(
        _harness(
          NavItemPill(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: true,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Only one icon should be present and it should be the one we passed.
      expect(find.byIcon(Icons.settings_outlined), findsOneWidget);
    });

    testWidgets('iconSize is honored on the rendered Icon', (tester) async {
      await tester.pumpWidget(
        _harness(
          NavItemPill(
            icon: Icons.settings_outlined,
            label: 'Settings',
            selected: false,
            iconSize: 28,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final icon = tester.widget<Icon>(find.byIcon(Icons.settings_outlined));
      expect(icon.size, 28);
    });

    testWidgets('forwards maxLines + overflow to the label Text', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          SizedBox(
            width: 80,
            child: NavItemPill(
              icon: Icons.settings_outlined,
              label: 'A longer label than the available width',
              selected: false,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final text = tester.widget<Text>(
        find.text('A longer label than the available width'),
      );
      expect(text.maxLines, 1);
      expect(text.overflow, TextOverflow.ellipsis);
    });

    testWidgets('invokes onTap and triggers Haptics.selection on press', (
      tester,
    ) async {
      var taps = 0;
      await tester.pumpWidget(
        _harness(
          NavItemPill(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: false,
            onTap: () => taps++,
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byType(NavItemPill));
      await tester.pumpAndSettle();

      expect(taps, 1);
      // Haptics.selection runs through HapticFeedback.selectionClick on the
      // current platform; just confirm no exception escapes the tap path.
      expect(tester.takeException(), isNull);
    });

    testWidgets('shows a focus ring only when focused and not selected', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          NavItemPill(
            icon: Icons.home_outlined,
            label: 'Home',
            selected: false,
            onTap: () {},
          ),
        ),
      );
      await tester.pumpAndSettle();

      final materialFinder = find.descendant(
        of: find.byType(NavItemPill),
        matching: find.byType(Material),
      );
      RoundedRectangleBorder shapeOf() =>
          tester.widget<Material>(materialFinder).shape
              as RoundedRectangleBorder;

      // No ring before focus.
      expect(shapeOf().side, BorderSide.none);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pumpAndSettle();
      expect(shapeOf().side, isNot(BorderSide.none));
    });

    testWidgets(
      'does not draw the focus ring when selected, even while focused',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            NavItemPill(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              selected: true,
              onTap: () {},
            ),
          ),
        );
        await tester.pumpAndSettle();

        final materialFinder = find.descendant(
          of: find.byType(NavItemPill),
          matching: find.byType(Material),
        );
        RoundedRectangleBorder shapeOf() =>
            tester.widget<Material>(materialFinder).shape
                as RoundedRectangleBorder;

        await tester.sendKeyEvent(LogicalKeyboardKey.tab);
        await tester.pumpAndSettle();
        expect(shapeOf().side, BorderSide.none);
      },
    );

    testWidgets('renders selected pill in light theme', (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7B61FF),
        brightness: Brightness.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            extensions: [EnjoyThemeTokens.build(scheme)],
          ),
          home: Scaffold(
            body: NavItemPill(
              icon: Icons.home_outlined,
              selectedIcon: Icons.home_rounded,
              label: 'Home',
              selected: true,
              onTap: () {},
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Home'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
