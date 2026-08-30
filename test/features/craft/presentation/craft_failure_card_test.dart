import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/features/craft/domain/craft_failure.dart';
import 'package:enjoy_player/features/craft/presentation/widgets/craft_failure_card.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:enjoy_player/l10n/app_localizations_en.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget wrap(Widget child, {GoRouter? router}) {
    if (router == null) {
      return MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Scaffold(body: child),
      );
    }
    return MaterialApp.router(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      routerConfig: router,
    );
  }

  testWidgets('CraftFailureCard renders the failure message and error icon', (
    tester,
  ) async {
    await tester.pumpWidget(
      wrap(
        CraftFailureCard(
          failure: const CraftTranslateFailure(),
          l10n: AppLocalizationsEn(),
          onRetry: () {},
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
  });

  testWidgets('CraftFailureCard invokes onRetry when action is retry', (
    tester,
  ) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        CraftFailureCard(
          failure: const CraftTranslateFailure(),
          l10n: AppLocalizationsEn(),
          onRetry: () => retried++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();

    expect(retried, 1);
  });

  testWidgets(
    'CraftFailureCard routes to /settings/ai-providers for openAiSettings',
    (tester) async {
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Scaffold(
              body: CraftFailureCard(
                failure: const CraftTtsFailure(
                  action: CraftFailureAction.openAiSettings,
                ),
                l10n: AppLocalizationsEn(),
                onRetry: () {},
              ),
            ),
          ),
          GoRoute(
            path: '/settings/ai-providers',
            builder: (_, _) =>
                const Scaffold(body: Text('ai-providers destination')),
          ),
        ],
      );

      await tester.pumpWidget(wrap(const SizedBox.shrink(), router: router));
      await tester.pumpAndSettle();

      expect(find.text('Open AI settings'), findsOneWidget);

      await tester.tap(find.widgetWithText(FilledButton, 'Open AI settings'));
      await tester.pumpAndSettle();

      expect(find.text('ai-providers destination'), findsOneWidget);
    },
  );

  testWidgets('CraftFailureCard routes to /sign-in for signIn failure', (
    tester,
  ) async {
    final router = GoRouter(
      initialLocation: '/',
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => Scaffold(
            body: CraftFailureCard(
              failure: const CraftSignInRequiredFailure(),
              l10n: AppLocalizationsEn(),
              onRetry: () {},
            ),
          ),
        ),
        GoRoute(
          path: '/sign-in',
          builder: (_, _) => const Scaffold(body: Text('sign-in destination')),
        ),
      ],
    );

    await tester.pumpWidget(wrap(const SizedBox.shrink(), router: router));
    await tester.pumpAndSettle();

    // The action label also doubles as the failure message; tap the button.
    await tester.tap(find.widgetWithText(FilledButton, 'Sign in to use Craft'));
    await tester.pumpAndSettle();

    expect(find.text('sign-in destination'), findsOneWidget);
  });

  testWidgets('CraftFailureCard shows Retry label and calls onRetry for '
      'switchToSpeakDirectly (inherited fallback behavior)', (tester) async {
    var retried = 0;
    await tester.pumpWidget(
      wrap(
        CraftFailureCard(
          failure: const CraftSameLanguageFailure(),
          l10n: AppLocalizationsEn(),
          onRetry: () => retried++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Retry'), findsOneWidget);
    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    expect(retried, 1);
  });

  testWidgets('CraftFailureCard shows the credits CTA alongside Retry for '
      'CraftCreditsFailure', (tester) async {
    var retried = 0;
    final l10n = AppLocalizationsEn();
    await tester.pumpWidget(
      wrap(
        CraftFailureCard(
          failure: const CraftCreditsFailure(
            CreditsFailure(
              'HTTP 402',
              requiredCredits: 1500,
              usedCredits: 0,
              limitCredits: 1000,
            ),
          ),
          l10n: l10n,
          onRetry: () => retried++,
        ),
      ),
    );
    await tester.pumpAndSettle();

    // Numbered message, no raw status.
    expect(find.textContaining('1500'), findsOneWidget);
    expect(find.text('HTTP 402'), findsNothing);
    // Retry still present, plus the unified recovery CTA.
    expect(find.text('Retry'), findsOneWidget);
    expect(find.text(l10n.subscriptionViewPlansAndPackages), findsOneWidget);

    await tester.tap(find.widgetWithText(FilledButton, 'Retry'));
    await tester.pump();
    expect(retried, 1);
  });
}
