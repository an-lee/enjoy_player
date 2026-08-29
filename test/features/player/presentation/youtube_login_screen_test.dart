import 'package:enjoy_player/features/player/presentation/youtube_login_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart'
    show debugDefaultTargetPlatformOverride, TargetPlatform;
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets(
    'renders the coming-soon notice on Linux instead of the sign-in WebView',
    (tester) async {
      // try/finally so the override is cleared *before* the testWidgets
      // verification check runs (same pattern as media_card_test).
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      try {
        await tester.pumpWidget(
          const ProviderScope(
            child: MaterialApp(
              localizationsDelegates: [
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: YoutubeLoginScreen(),
            ),
          ),
        );
        await tester.pump();

        expect(
          find.text('YouTube is not yet available on Linux — coming soon.'),
          findsOneWidget,
        );
        // Ungated, the screen constructs InAppWebView, which asserts — no
        // platform backend exists in the test environment (the same failure
        // as production Linux).
        expect(tester.takeException(), isNull);
      } finally {
        debugDefaultTargetPlatformOverride = null;
      }
    },
  );
}
