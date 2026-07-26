import 'package:enjoy_player/features/craft/domain/craft_solid_transcript_hint_gate.dart';
import 'package:enjoy_player/features/craft/presentation/craft_solid_transcript_stt_hint.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    CraftSolidTranscriptHintGate.resetForTests();
  });

  Widget wrap(Widget child) {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: Center(child: child)),
    );
  }

  testWidgets('does nothing when savedSolidTimeline is false', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    maybeShowCraftSolidTranscriptSttHint(
      tester.element(find.byType(Scaffold)),
      savedSolidTimeline: false,
    );
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });

  testWidgets('shows snackbar first time gate consumes', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    final ctx = tester.element(find.byType(Scaffold));
    maybeShowCraftSolidTranscriptSttHint(ctx, savedSolidTimeline: true);
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);
    expect(CraftSolidTranscriptHintGate.shownThisSession, isTrue);
  });

  testWidgets('skips snackbar on second call within session', (tester) async {
    await tester.pumpWidget(wrap(const SizedBox.shrink()));
    final ctx = tester.element(find.byType(Scaffold));
    maybeShowCraftSolidTranscriptSttHint(ctx, savedSolidTimeline: true);
    await tester.pump();
    expect(find.byType(SnackBar), findsOneWidget);

    // Clear current snackbar and call again with a fresh BuildContext.
    ScaffoldMessenger.of(ctx).hideCurrentSnackBar();
    await tester.pumpAndSettle();

    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        locale: const Locale('en'),
        home: Builder(
          builder: (innerCtx) {
            maybeShowCraftSolidTranscriptSttHint(
              innerCtx,
              savedSolidTimeline: true,
            );
            return const Scaffold(body: SizedBox.shrink());
          },
        ),
      ),
    );
    await tester.pump();
    expect(find.byType(SnackBar), findsNothing);
  });

  test('resetForTests clears the gate state', () {
    CraftSolidTranscriptHintGate.consume();
    expect(CraftSolidTranscriptHintGate.shownThisSession, isTrue);
    CraftSolidTranscriptHintGate.resetForTests();
    expect(CraftSolidTranscriptHintGate.shownThisSession, isFalse);
  });

  test('consume returns true once then false', () {
    expect(CraftSolidTranscriptHintGate.consume(), isTrue);
    expect(CraftSolidTranscriptHintGate.consume(), isFalse);
    expect(CraftSolidTranscriptHintGate.consume(), isFalse);
  });
}
