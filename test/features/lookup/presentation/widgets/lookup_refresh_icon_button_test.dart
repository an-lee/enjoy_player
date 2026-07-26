import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_refresh_icon_button.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _harness({required VoidCallback onPressed, bool isRefreshing = false}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return MaterialApp(
    theme: ThemeData(colorScheme: scheme, useMaterial3: true),
    locale: const Locale('en', 'US'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Builder(
      builder: (context) => Scaffold(
        body: LookupRefreshIconButton(
          l10n: AppLocalizations.of(context)!,
          isRefreshing: isRefreshing,
          onPressed: onPressed,
        ),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the refresh icon and tooltip when idle', (tester) async {
    await tester.pumpWidget(_harness(onPressed: () {}));
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    // Tooltip should be present when not refreshing.
    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.tooltip, isNotNull);
    expect(iconButton.onPressed, isNotNull);
  });

  testWidgets('tapping the button calls onPressed and shows the spinner', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(_harness(onPressed: () => taps++));
    await tester.pumpAndSettle();
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    // First tap fires onPressed immediately and latches the busy state.
    expect(taps, 1);
    expect(find.byIcon(Icons.refresh_rounded), findsNothing);
  });

  testWidgets('button stays disabled while parent reports isRefreshing', (
    tester,
  ) async {
    var taps = 0;
    await tester.pumpWidget(
      _harness(onPressed: () => taps++, isRefreshing: true),
    );
    // LoadingIcon spins forever; do not pumpAndSettle.
    await tester.pump();
    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.onPressed, isNull);
    await tester.tap(find.byType(IconButton));
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets(
    'didUpdateWidget clears the tap latch when isRefreshing flips false',
    (tester) async {
      var taps = 0;
      var refreshing = false;
      Widget build() =>
          _harness(onPressed: () => taps++, isRefreshing: refreshing);
      await tester.pumpWidget(build());
      await tester.pump();
      await tester.tap(find.byType(IconButton));
      await tester.pump();
      expect(taps, 1);
      // Parent reports busy → button disabled, no second tap fires.
      refreshing = true;
      await tester.pumpWidget(build());
      await tester.pump();
      final busy = tester.widget<IconButton>(find.byType(IconButton));
      expect(busy.onPressed, isNull);
      // Parent reports idle again → button re-enabled.
      refreshing = false;
      await tester.pumpWidget(build());
      await tester.pump();
      final idle = tester.widget<IconButton>(find.byType(IconButton));
      expect(idle.onPressed, isNotNull);
      // The icon returns too.
      expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
    },
  );
}
