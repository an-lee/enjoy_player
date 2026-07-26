// Simple sanity test for `lib/features/hotkeys/presentation/hotkey_capture_dialog.dart`.
import 'package:enjoy_player/features/hotkeys/presentation/hotkey_capture_dialog.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  Widget build() {
    return MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Builder(
        builder: (ctx) => Scaffold(
          body: Center(
            child: ElevatedButton(
              onPressed: () => showDialog<String?>(
                context: ctx,
                builder: (_) => const HotkeyCaptureDialog(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
  }

  testWidgets('renders title and Cancel button on open', (tester) async {
    await tester.pumpWidget(build());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.byType(HotkeyCaptureDialog), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });

  testWidgets('Cancel button dismisses the dialog', (tester) async {
    await tester.pumpWidget(build());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    expect(find.text('Cancel'), findsOneWidget);
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(find.byType(HotkeyCaptureDialog), findsNothing);
  });

  testWidgets('KeyUp event (not KeyDown) is ignored', (tester) async {
    await tester.pumpWidget(build());
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    // Send only KeyUp — the dialog ignores non-Down events.
    HardwareKeyboard.instance.handleKeyEvent(
      KeyUpEvent(
        physicalKey: const PhysicalKeyboardKey(0),
        logicalKey: LogicalKeyboardKey.keyA,
        timeStamp: Duration.zero,
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SelectableText), findsNothing);
    expect(find.text('Cancel'), findsOneWidget);
    expect(find.byType(HotkeyCaptureDialog), findsOneWidget);
  });
}
