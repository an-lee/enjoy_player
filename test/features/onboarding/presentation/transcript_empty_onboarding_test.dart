import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_keys.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_target.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_empty_state.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _wrap(Widget child) {
  return ProviderScope(
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
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

  testWidgets('YouTube empty state shows Fetch transcript CTA', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    var fetchCalls = 0;

    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          onFetchYoutube: () async {
            fetchCalls++;
          },
          showImportButton: false,
          showFetchYoutubeButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.transcriptEmptyFetchYoutube), findsOneWidget);
    expect(find.text(l10n.transcriptEmptyAddSubtitle), findsNothing);
    expect(find.textContaining('Cloud captions'), findsOneWidget);

    await tester.tap(find.text(l10n.transcriptEmptyFetchYoutube));
    await tester.pumpAndSettle();
    expect(fetchCalls, 1);
  });

  testWidgets('YouTube Fetch CTA is wrapped for empty-transcript tip', (
    tester,
  ) async {
    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          onFetchYoutube: () async {},
          showImportButton: false,
          showFetchYoutubeButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(OnboardingTarget), findsOneWidget);
    expect(
      _hasShowcaseFor(OnboardingTipId.playerEmptyTranscriptYoutube),
      isTrue,
    );
  });

  testWidgets('local empty state spotlights Extract when extract is shown', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          onExtract: () async {},
          showImportButton: true,
          showExtractButton: true,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.transcriptEmptyExtract), findsOneWidget);
    expect(_hasShowcaseFor(OnboardingTipId.playerEmptyTranscriptLocal), isTrue);
    expect(
      _hasShowcaseFor(OnboardingTipId.playerEmptyTranscriptYoutube),
      isFalse,
    );
  });

  testWidgets('local empty state spotlights Add subtitle when Extract hidden', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(
      _wrap(
        TranscriptEmptyState(
          onImport: () async {},
          showImportButton: true,
          showExtractButton: false,
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.transcriptEmptyAddSubtitle), findsOneWidget);
    expect(_hasShowcaseFor(OnboardingTipId.playerEmptyTranscriptLocal), isTrue);
  });
}

bool _hasShowcaseFor(OnboardingTipId tip) {
  final key = OnboardingKeys.keyFor(tip);
  return ShowcaseView.get().isTargetRendered(key);
}
