import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/features/shadow_reading/presentation/widgets/shadow_recording_caption.dart';
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

Future<
  ({
    AppLocalizations l10n,
    TextTheme tt,
    ColorScheme scheme,
    EnjoyThemeTokens tok,
  })
>
_build(WidgetTester tester) async {
  final l10n = await AppLocalizations.delegate.load(const Locale('en'));
  late TextTheme tt;
  late ColorScheme scheme;
  late EnjoyThemeTokens tok;
  await tester.pumpWidget(
    MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (context) {
          tt = Theme.of(context).textTheme;
          scheme = Theme.of(context).colorScheme;
          tok = EnjoyThemeTokens.of(context);
          return const SizedBox.shrink();
        },
      ),
    ),
  );
  await tester.pump();
  return (l10n: l10n, tt: tt, scheme: scheme, tok: tok);
}

void main() {
  testWidgets(
    'formats elapsed/target as "x.x s / y.y s" with tabular figures',
    (tester) async {
      final env = await _build(tester);
      await _pump(
        tester,
        ShadowRecordingCaptionRow(
          elapsedSec: 0.5,
          targetSec: 1.2,
          overTarget: false,
          overBySec: 0,
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
        ),
      );

      expect(find.text('0.5 s / 1.2 s'), findsOneWidget);
      // Over-target indicator should be absent.
      expect(find.byIcon(Icons.circle), findsNothing);
    },
  );

  testWidgets('renders "+x.xs over target" pill when overTarget is true', (
    tester,
  ) async {
    final env = await _build(tester);
    await _pump(
      tester,
      ShadowRecordingCaptionRow(
        elapsedSec: 2.3,
        targetSec: 2.0,
        overTarget: true,
        overBySec: 0.3,
        l10n: env.l10n,
        tt: env.tt,
        scheme: env.scheme,
        tok: env.tok,
      ),
    );

    expect(find.text('2.3 s / 2.0 s'), findsOneWidget);
    expect(find.text('+0.3s over target'), findsOneWidget);
    // Red dot icon appears as the over-target indicator.
    expect(find.byIcon(Icons.circle), findsOneWidget);
  });

  testWidgets('falls back to "x.x s" plain text when targetSec is zero', (
    tester,
  ) async {
    final env = await _build(tester);
    await _pump(
      tester,
      ShadowRecordingCaptionRow(
        elapsedSec: 0.7,
        targetSec: 0,
        overTarget: false,
        overBySec: 0,
        l10n: env.l10n,
        tt: env.tt,
        scheme: env.scheme,
        tok: env.tok,
      ),
    );

    expect(find.text('0.7 s'), findsOneWidget);
    expect(find.text('0.7 s / 0.0 s'), findsNothing);
  });

  testWidgets(
    'semantics label announces "x.x seconds elapsed of y.y seconds target"',
    (tester) async {
      final env = await _build(tester);
      await _pump(
        tester,
        ShadowRecordingCaptionRow(
          elapsedSec: 1.0,
          targetSec: 2.5,
          overTarget: false,
          overBySec: 0,
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
        ),
      );

      final semantics = tester.getSemantics(find.text('1.0 s / 2.5 s'));
      expect(
        semantics.label,
        startsWith('1.0 seconds elapsed of 2.5 seconds target'),
      );
    },
  );

  testWidgets(
    'over-target branch exposes a Flexible text so it wraps at narrow width',
    (tester) async {
      final env = await _build(tester);
      await _pump(
        tester,
        ShadowRecordingCaptionRow(
          elapsedSec: 5.0,
          targetSec: 4.0,
          overTarget: true,
          overBySec: 1.0,
          l10n: env.l10n,
          tt: env.tt,
          scheme: env.scheme,
          tok: env.tok,
        ),
      );

      final flexible = tester
          .widgetList<Widget>(find.byType(Flexible))
          .toList();
      expect(flexible, isNotEmpty);
      // Over-target text wraps in a Flexible child.
      expect(
        tester
            .widgetList<Text>(find.byType(Text))
            .any((t) => t.data == '+1.0s over target'),
        isTrue,
      );
    },
  );

  testWidgets('rounds to one decimal place when formatting seconds', (
    tester,
  ) async {
    final env = await _build(tester);
    await _pump(
      tester,
      ShadowRecordingCaptionRow(
        elapsedSec: 1.23456,
        targetSec: 2.98765,
        overTarget: false,
        overBySec: 0,
        l10n: env.l10n,
        tt: env.tt,
        scheme: env.scheme,
        tok: env.tok,
      ),
    );

    expect(find.text('1.2 s / 3.0 s'), findsOneWidget);
  });
}
