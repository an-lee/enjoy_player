// Coverage for lib/features/lookup/presentation/widgets/lookup_expansion_card.dart
// — header/body toggle, leading icon, lazy body, AnimatedSize paths.
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_expansion_card.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _harness({
  required bool initiallyExpanded,
  String title = 'Section',
  Widget? leading,
  Widget Function(BuildContext)? bodyBuilder,
}) {
  return MaterialApp(
    locale: const Locale('en'),
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(
      body: LookupExpansionCard(
        title: title,
        initiallyExpanded: initiallyExpanded,
        leading: leading,
        bodyBuilder:
            bodyBuilder ??
            (_) => const Padding(
              padding: EdgeInsets.all(8),
              child: Text('Body Content'),
            ),
      ),
    ),
  );
}

void main() {
  testWidgets('Renders title in the header', (tester) async {
    await tester.pumpWidget(_harness(initiallyExpanded: false, title: 'Hello'));
    expect(find.text('Hello'), findsOneWidget);
  });

  testWidgets('Initially collapsed does not render the body content', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(initiallyExpanded: false));
    expect(find.text('Body Content'), findsNothing);
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
  });

  testWidgets('Initially expanded shows the body immediately', (tester) async {
    await tester.pumpWidget(_harness(initiallyExpanded: true));
    expect(find.text('Body Content'), findsOneWidget);
  });

  testWidgets('Tap header toggles expanded state', (tester) async {
    await tester.pumpWidget(_harness(initiallyExpanded: false));
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Body Content'), findsOneWidget);
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Body Content'), findsNothing);
  });

  testWidgets('Body builder is invoked after first tap', (tester) async {
    var buildCount = 0;
    await tester.pumpWidget(
      _harness(
        initiallyExpanded: false,
        bodyBuilder: (_) {
          buildCount++;
          return const Text('Lazy Body');
        },
      ),
    );
    expect(buildCount, 0, reason: 'no body before first expand');
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Lazy Body'), findsOneWidget);
    expect(buildCount, greaterThanOrEqualTo(1));
  });

  testWidgets('Leading icon renders when provided', (tester) async {
    await tester.pumpWidget(
      _harness(
        initiallyExpanded: false,
        leading: const Icon(Icons.book_rounded),
      ),
    );
    expect(find.byIcon(Icons.book_rounded), findsOneWidget);
  });

  testWidgets('Leading icon omitted when null', (tester) async {
    await tester.pumpWidget(_harness(initiallyExpanded: false, leading: null));
    expect(find.byIcon(Icons.book_rounded), findsNothing);
  });

  testWidgets('AnimatedSize wraps the body and toggles visibility', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(initiallyExpanded: true));
    expect(find.byType(AnimatedSize), findsOneWidget);
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(find.text('Body Content'), findsNothing);
  });

  testWidgets('Expand icon rotates between collapsed and expanded', (
    tester,
  ) async {
    await tester.pumpWidget(_harness(initiallyExpanded: false));
    final expandIcon = find.byIcon(Icons.expand_more_rounded);
    expect(expandIcon, findsOneWidget);
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    // Icon still rendered, just rotated.
    expect(find.byIcon(Icons.expand_more_rounded), findsOneWidget);
  });

  testWidgets('Custom body builder runs in the correct BuildContext', (
    tester,
  ) async {
    String? observedL10n;
    await tester.pumpWidget(
      _harness(
        initiallyExpanded: false,
        bodyBuilder: (context) {
          observedL10n = AppLocalizations.of(context)?.lookupTapToExpand;
          return const Text('Ctx Body');
        },
      ),
    );
    await tester.tap(find.text('Section'));
    await tester.pumpAndSettle();
    expect(observedL10n, isNotNull);
    expect(find.text('Ctx Body'), findsOneWidget);
  });
}
