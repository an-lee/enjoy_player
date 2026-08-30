import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/subscription/presentation/credits_failure_actions.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  Future<void> pumpHarness(
    WidgetTester tester, {
    required CreditsFailure failure,
  }) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: FilledButton(
                onPressed: () => showCreditsFailureNotice(context, failure),
                child: const Text('trigger'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/subscription',
          builder: (context, state) =>
              const Scaffold(body: Text('subscription-page')),
        ),
      ],
    );

    final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
    await tester.pumpWidget(
      MaterialApp.router(
        routerConfig: router,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: ThemeData(
          colorScheme: scheme,
          extensions: [EnjoyThemeTokens.build(scheme)],
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets(
    'envelope-bearing failure shows numbered message and CTA navigates',
    (tester) async {
      await pumpHarness(
        tester,
        failure: CreditsFailure(
          'HTTP 402',
          requiredCredits: 750,
          usedCredits: 800,
          limitCredits: 1000,
          resetAt: DateTime.utc(2026, 8, 31),
        ),
      );

      await tester.tap(find.text('trigger'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Numbered body — never the raw 'HTTP 402' internal string.
      expect(
        find.textContaining('750'),
        findsOneWidget,
        reason: 'message must spell out the required credits',
      );
      expect(find.textContaining('200'), findsOneWidget);
      expect(find.text('HTTP 402'), findsNothing);

      final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
      snackBar.action!.onPressed();
      await tester.pumpAndSettle();

      expect(find.text('subscription-page'), findsOneWidget);
    },
  );

  testWidgets('envelope-less failure falls back to the generic copy', (
    tester,
  ) async {
    await pumpHarness(tester, failure: const CreditsFailure('HTTP 402'));

    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      find.text(l10n.subscriptionCreditsLimitMessageWithPackages),
      findsOneWidget,
    );
    expect(find.text('HTTP 402'), findsNothing);

    final snackBar = tester.widget<SnackBar>(find.byType(SnackBar));
    expect(snackBar.action!.label, l10n.subscriptionViewPlansAndPackages);
  });

  testWidgets('repeated credits failures replace rather than stack (FR-006)', (
    tester,
  ) async {
    await pumpHarness(tester, failure: const CreditsFailure('HTTP 402'));

    // Two failures in a row (e.g. retry without purchasing): the second
    // must replace the first, leaving exactly one snackbar visible.
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    await tester.tap(find.text('trigger'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(SnackBar), findsOneWidget);
    expect(find.text(l10n.subscriptionViewPlansAndPackages), findsOneWidget);
  });
}
