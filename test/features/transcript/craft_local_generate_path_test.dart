import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:enjoy_player/features/transcript/presentation/transcript_empty_state.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Craft library items are local `Audio` rows (`provider == 'craft'`), never
/// YouTube. [TranscriptPanel] gates Generate with `showLocalActions = !isYoutube`,
/// so Craft blank/solid media share the same `launchAsrGeneration` path as
/// other local audio — no Craft-specific exclusion.
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

  testWidgets(
    'Craft-like local empty state exposes AI transcript generate CTA',
    (tester) async {
      // Mirrors TranscriptPanel for non-YouTube media (including Craft).
      const showLocalActions = true;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: TranscriptEmptyState(
              onImport: () async {},
              onGenerate: () async {},
              showImportButton: showLocalActions,
              showGenerateButton: showLocalActions,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('AI transcript'), findsOneWidget);
    },
  );
}
