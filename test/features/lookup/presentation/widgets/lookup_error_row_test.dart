import 'package:enjoy_player/core/errors/app_failure.dart';
import 'package:enjoy_player/core/presentation/loading_icon.dart';
import 'package:enjoy_player/features/lookup/presentation/widgets/lookup_error_row.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: const [
      AppLocalizations.delegate,
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

Future<void> _pump(WidgetTester tester, Widget child) async {
  await tester.pumpWidget(_wrap(child));
  await tester.pump();
}

void main() {
  test('lookupErrorUserMessage maps AuthFailure to sign-in message', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      lookupErrorUserMessage(const AuthFailure('ignored'), l10n),
      l10n.lookupCloudRequiresSignIn,
    );
  });

  test('lookupErrorUserMessage prefers AppFailure.message', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(
      lookupErrorUserMessage(const NetworkFailure('net down'), l10n),
      'net down',
    );
  });

  test(
    'lookupErrorUserMessage falls back to error.toString() for unknown types',
    () async {
      final l10n = await AppLocalizations.delegate.load(const Locale('en'));
      expect(lookupErrorUserMessage('plain string', l10n), 'plain string');
      expect(lookupErrorUserMessage(42, l10n), '42');
    },
  );

  testWidgets('renders message and a Retry button', (tester) async {
    await _pump(
      tester,
      LookupErrorRow(message: 'Dictionary provider offline', onRetry: () {}),
    );

    expect(find.text('Dictionary provider offline'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);
    expect(find.byIcon(Icons.error_outline_rounded), findsOneWidget);
    expect(find.byType(FilledButton), findsOneWidget);
    // Not busy -> spinner should be absent, refresh icon shown
    expect(find.byType(LoadingIcon), findsNothing);
    expect(find.byIcon(Icons.refresh_rounded), findsOneWidget);
  });

  testWidgets('tapping Retry invokes onRetry exactly once', (tester) async {
    var taps = 0;
    await _pump(tester, LookupErrorRow(message: 'boom', onRetry: () => taps++));

    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(taps, 1);
  });

  testWidgets('tapping Retry disables button while isRetrying is true', (
    tester,
  ) async {
    var taps = 0;
    await _pump(
      tester,
      LookupErrorRow(message: 'boom', onRetry: () => taps++, isRetrying: true),
    );

    final button = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(button.onPressed, isNull);
    expect(find.byType(LoadingIcon), findsOneWidget);
    await tester.tap(find.byType(FilledButton), warnIfMissed: false);
    await tester.pump();
    expect(taps, 0);
  });

  testWidgets('didUpdateWidget resets _tapLatched when isRetrying flips back', (
    tester,
  ) async {
    var taps = 0;
    Widget build({required bool isRetrying}) {
      return LookupErrorRow(
        message: 'boom',
        onRetry: () => taps++,
        isRetrying: isRetrying,
      );
    }

    await tester.pumpWidget(_wrap(build(isRetrying: false)));
    await tester.pump();
    await tester.tap(find.text('Retry'));
    await tester.pump();
    // Latched: button disabled while we never toggle isRetrying=true
    final latchedButton = tester.widget<FilledButton>(
      find.byType(FilledButton),
    );
    expect(latchedButton.onPressed, isNull);
    expect(
      find.byType(LoadingIcon),
      findsOneWidget,
      reason: '_tapLatched keeps the row busy after a tap',
    );

    // Parent flips isRetrying=true -> didUpdateWidget clears _tapLatched
    await tester.pumpWidget(_wrap(build(isRetrying: true)));
    await tester.pump();
    expect(find.byType(LoadingIcon), findsOneWidget);

    // Now flip isRetrying=false (post retry completion) -> latch still cleared.
    await tester.pumpWidget(_wrap(build(isRetrying: false)));
    await tester.pump();
    final afterButton = tester.widget<FilledButton>(find.byType(FilledButton));
    expect(afterButton.onPressed, isNotNull);
    expect(find.byType(LoadingIcon), findsNothing);

    // Tapping again should fire onRetry again.
    await tester.tap(find.text('Retry'));
    await tester.pump();
    expect(taps, 2);
  });
}
