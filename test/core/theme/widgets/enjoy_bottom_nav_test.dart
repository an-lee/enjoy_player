import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_bottom_nav.dart';

Widget _harness({
  required int selectedIndex,
  required List<EnjoyBottomNavDestination> destinations,
  required ValueChanged<int> onSelected,
}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return MaterialApp(
    theme: ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [EnjoyThemeTokens.build(scheme)],
    ),
    home: Scaffold(
      body: EnjoyBottomNav(
        selectedIndex: selectedIndex,
        onDestinationSelected: onSelected,
        destinations: destinations,
      ),
    ),
  );
}

List<EnjoyBottomNavDestination> _sampleDestinations() {
  return const [
    EnjoyBottomNavDestination(
      icon: Icons.home_outlined,
      selectedIcon: Icons.home_rounded,
      label: 'Home',
    ),
    EnjoyBottomNavDestination(
      icon: Icons.search_outlined,
      selectedIcon: Icons.search_rounded,
      label: 'Search',
    ),
    EnjoyBottomNavDestination(
      icon: Icons.person_outline,
      selectedIcon: Icons.person_rounded,
      label: 'Profile',
      showBadge: true,
    ),
  ];
}

void main() {
  group('EnjoyBottomNavDestination', () {
    test('defaults showBadge to false and semanticsLabel to null', () {
      const dest = EnjoyBottomNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
      );
      expect(dest.showBadge, isFalse);
      expect(dest.semanticsLabel, isNull);
      expect(dest.label, 'Home');
    });

    test('honors explicit showBadge + semanticsLabel', () {
      const dest = EnjoyBottomNavDestination(
        icon: Icons.home_outlined,
        selectedIcon: Icons.home_rounded,
        label: 'Home',
        semanticsLabel: 'Home tab',
        showBadge: true,
      );
      expect(dest.semanticsLabel, 'Home tab');
      expect(dest.showBadge, isTrue);
    });
  });

  group('EnjoyBottomNav', () {
    testWidgets('renders one item per destination', (tester) async {
      await tester.pumpWidget(
        _harness(
          selectedIndex: 0,
          destinations: _sampleDestinations(),
          onSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(EnjoyBottomNav), findsOneWidget);
      expect(find.text('Home'), findsOneWidget);
      expect(find.text('Search'), findsOneWidget);
      expect(find.text('Profile'), findsOneWidget);
    });

    testWidgets('uses selectedIcon for the selected destination', (
      tester,
    ) async {
      await tester.pumpWidget(
        _harness(
          selectedIndex: 1,
          destinations: _sampleDestinations(),
          onSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      // The "Search" destination is selected → its rounded icon should appear.
      expect(find.byIcon(Icons.search_rounded), findsOneWidget);
      expect(find.byIcon(Icons.search_outlined), findsNothing);
      // Other destinations should still be unselected.
      expect(find.byIcon(Icons.home_outlined), findsOneWidget);
      expect(find.byIcon(Icons.person_outline), findsOneWidget);
    });

    testWidgets('invokes onDestinationSelected with the tapped index', (
      tester,
    ) async {
      int? tapped;
      await tester.pumpWidget(
        _harness(
          selectedIndex: 0,
          destinations: _sampleDestinations(),
          onSelected: (i) => tapped = i,
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Profile'));
      await tester.pumpAndSettle();
      expect(tapped, 2);
    });

    testWidgets('draws a badge when showBadge is true', (tester) async {
      await tester.pumpWidget(
        _harness(
          selectedIndex: 0,
          destinations: _sampleDestinations(),
          onSelected: (_) {},
        ),
      );
      await tester.pumpAndSettle();
      // The Profile destination sets showBadge: true — it contributes a small
      // dot container inside its Stack.
      final containers = tester
          .widgetList<Container>(
            find.descendant(
              of: find.byType(EnjoyBottomNav),
              matching: find.byType(Container),
            ),
          )
          .toList();
      final hasDot = containers.any(
        (c) => c.constraints != null && c.constraints!.minWidth == 8,
      );
      expect(hasDot, isTrue);
    });

    testWidgets(
      'selected tab does not overlay a circular marker on the label',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            selectedIndex: 0,
            destinations: _sampleDestinations(),
            onSelected: (_) {},
          ),
        );
        await tester.pumpAndSettle();

        final containers = tester
            .widgetList<Container>(
              find.descendant(
                of: find.byType(EnjoyBottomNav),
                matching: find.byType(Container),
              ),
            )
            .toList();
        final overlayDots = containers.where(
          (c) =>
              c.constraints != null &&
              c.constraints!.minWidth == 4 &&
              c.constraints!.minHeight == 4,
        );
        expect(overlayDots, isEmpty);
      },
    );

    testWidgets(
      'falls back to semanticsLabel -> label for Semantics container',
      (tester) async {
        const customDest = EnjoyBottomNavDestination(
          icon: Icons.settings_outlined,
          selectedIcon: Icons.settings_rounded,
          label: 'Settings',
          semanticsLabel: 'Settings tab',
        );
        await tester.pumpWidget(
          _harness(
            selectedIndex: 0,
            destinations: [customDest],
            onSelected: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        // Resolve the Semantics widget and confirm its label is the override.
        final semantics = tester
            .widgetList<Semantics>(
              find.descendant(
                of: find.byType(EnjoyBottomNav),
                matching: find.byType(Semantics),
              ),
            )
            .toList();
        expect(
          semantics.any((s) => s.properties.label == 'Settings tab'),
          isTrue,
        );
      },
    );

    testWidgets(
      'selectedIndex out of range does not crash and renders all items',
      (tester) async {
        await tester.pumpWidget(
          _harness(
            selectedIndex: 99,
            destinations: _sampleDestinations(),
            onSelected: (_) {},
          ),
        );
        await tester.pumpAndSettle();
        // No destination matches index 99 — none should be styled selected.
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Search'), findsOneWidget);
        expect(find.text('Profile'), findsOneWidget);
      },
    );

    testWidgets('renders in light theme without throwing', (tester) async {
      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7B61FF),
        brightness: Brightness.light,
      );
      await tester.pumpWidget(
        MaterialApp(
          theme: ThemeData(
            colorScheme: scheme,
            useMaterial3: true,
            extensions: [EnjoyThemeTokens.build(scheme)],
          ),
          home: Scaffold(
            body: EnjoyBottomNav(
              selectedIndex: 0,
              onDestinationSelected: (_) {},
              destinations: _sampleDestinations(),
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
