import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';

import 'package:enjoy_player/core/routing/not_found_screen.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

GoRouter _router() {
  return GoRouter(
    initialLocation: '/missing',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, __) => const Scaffold(body: Text('home')),
      ),
    ],
    errorBuilder: (context, state) => NotFoundScreen(uri: state.uri),
  );
}

Widget _harness() {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return MaterialApp.router(
    theme: ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      extensions: [EnjoyThemeTokens.build(scheme)],
    ),
    locale: const Locale('en', 'US'),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: _router(),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('renders the not-found copy and the back-home button', (
    tester,
  ) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();

    expect(find.byIcon(Icons.explore_off_rounded), findsOneWidget);
    expect(find.text('Page not found'), findsOneWidget);
    // The subtitle references the unknown uri verbatim.
    expect(find.textContaining('/missing'), findsOneWidget);
    expect(find.text('Back to home'), findsOneWidget);
  });

  testWidgets('tapping the back-home button routes to "/"', (tester) async {
    await tester.pumpWidget(_harness());
    await tester.pumpAndSettle();
    expect(find.text('Page not found'), findsOneWidget);

    await tester.tap(find.text('Back to home'));
    await tester.pumpAndSettle();

    expect(find.text('home'), findsOneWidget);
    expect(find.text('Page not found'), findsNothing);
  });
}
