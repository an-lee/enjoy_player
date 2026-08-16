import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/sheet_drag_handle.dart';
import 'package:enjoy_player/features/transcript/presentation/word_phone_inspect_sheet.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _app(Widget home) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return MaterialApp(
    theme: ThemeData(
      colorScheme: scheme,
      useMaterial3: true,
      brightness: Brightness.dark,
      extensions: [EnjoyThemeTokens.build(scheme)],
    ),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: home,
  );
}

void main() {
  testWidgets('lists stored phone pieces in order', (tester) async {
    await tester.pumpWidget(
      _app(
        Scaffold(
          body: Builder(
            builder: (context) {
              return TextButton(
                onPressed: () {
                  unawaited(
                    showWordPhoneInspectSheet(
                      context: context,
                      wordText: 'an',
                      pieces: const ['æ', 'n'],
                    ),
                  );
                },
                child: const Text('open'),
              );
            },
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();

    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(find.text(l10n.transcriptWordInspectTitle('an')), findsOneWidget);
    expect(find.text('æ'), findsOneWidget);
    expect(find.text('n'), findsOneWidget);
    expect(find.byType(PaddedSheetDragHandle), findsOneWidget);
    expect(find.textContaining('pronounce'), findsNothing);
    expect(find.textContaining('align'), findsNothing);
  });
}
