import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:enjoy_player/features/transcript/presentation/transcript_empty_state.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );
}

void main() {
  setUp(() {
    ShowcaseView.register(
      enableAutoScroll: false,
      disableMovingAnimation: true,
      disableScaleAnimation: true,
    );
  });

  tearDown(() {
    try {
      ShowcaseView.get().unregister();
    } on Object {
      // Already unregistered.
    }
  });

  testWidgets('shows AI transcript CTA when enabled', (tester) async {
    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          onGenerate: () async {},
          showImportButton: true,
          showGenerateButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI transcript'), findsOneWidget);
    expect(find.text('Add subtitle'), findsOneWidget);
    expect(find.textContaining('Add a subtitle file'), findsOneWidget);
  });

  testWidgets('hides AI transcript CTA when showGenerateButton is false', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          showImportButton: true,
          showGenerateButton: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('AI transcript'), findsNothing);
    expect(find.text('Add subtitle'), findsOneWidget);
  });

  testWidgets('shows remote hint when no local actions are available', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          showImportButton: false,
          showExtractButton: false,
          showGenerateButton: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(
      find.textContaining('Cloud captions load automatically'),
      findsOneWidget,
    );
    expect(find.text('AI transcript'), findsNothing);
    expect(find.text('Add subtitle'), findsNothing);
  });

  testWidgets('AI transcript CTA shows busy spinner while onGenerate runs', (
    tester,
  ) async {
    final completer = Completer<void>();
    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          onGenerate: () => completer.future,
          showImportButton: true,
          showGenerateButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('AI transcript'));
    await tester.pump(); // first rebuild → busy
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete();
    await tester.pumpAndSettle();
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });
}
