import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_progress_provider.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/about_section_card.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

Widget _harness({required AppDatabase db}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ProviderScope(
    overrides: [
      deviceGlobalAppDatabaseProvider.overrideWithValue(db),
      appDatabaseProvider.overrideWithValue(db),
      // Avoid update-check side effects while tapping About rows.
      updateAvailableBadgeProvider.overrideWith((ref) => false),
    ],
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en', 'US'),
      home: const Scaffold(
        body: SingleChildScrollView(child: AboutSectionCard()),
      ),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Enjoy Player',
      packageName: 'com.enjoy.player.test',
      version: '0.3.1',
      buildNumber: '2',
      buildSignature: 'test',
    );
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('cancel leaves tip progress intact', (tester) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en', 'US'));
    await tester.pumpWidget(_harness(db: db));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AboutSectionCard)),
    );
    await container.read(onboardingProgressProvider.future);
    await container
        .read(onboardingProgressProvider.notifier)
        .markGlobal(OnboardingTipId.homeCraft, TipStatus.completed);
    await container
        .read(onboardingProgressProvider.notifier)
        .markEmptyTranscript('media-a', TipStatus.skipped);

    await tester.scrollUntilVisible(
      find.text(l10n.settingsResetProductTipsTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.settingsResetProductTipsTitle));
    await tester.pumpAndSettle();

    expect(
      find.text(l10n.settingsResetProductTipsConfirmTitle),
      findsOneWidget,
    );
    await tester.tap(
      find.text(
        MaterialLocalizations.of(
          tester.element(find.byType(AlertDialog)),
        ).cancelButtonLabel,
      ),
    );
    await tester.pumpAndSettle();

    final progress = container.read(onboardingProgressProvider).requireValue;
    expect(
      progress.statusOfGlobal(OnboardingTipId.homeCraft),
      TipStatus.completed,
    );
    expect(
      await container
          .read(onboardingProgressProvider.notifier)
          .statusOfEmptyTranscript('media-a'),
      TipStatus.skipped,
    );
  });

  testWidgets('confirm clears tip progress and shows success notice', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en', 'US'));
    await tester.pumpWidget(_harness(db: db));
    await tester.pumpAndSettle();

    final container = ProviderScope.containerOf(
      tester.element(find.byType(AboutSectionCard)),
    );
    await container.read(onboardingProgressProvider.future);
    await container
        .read(onboardingProgressProvider.notifier)
        .markGlobal(OnboardingTipId.homeImport, TipStatus.completed);
    await container
        .read(onboardingProgressProvider.notifier)
        .markEmptyTranscript('media-a', TipStatus.completed);

    await tester.scrollUntilVisible(
      find.text(l10n.settingsResetProductTipsTitle),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text(l10n.settingsResetProductTipsTitle));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.settingsResetProductTipsConfirmAction));
    await tester.pump(); // dialog pop + reset
    await tester.pump(); // AppNotice post-frame
    await tester.pump();

    final progress = container.read(onboardingProgressProvider).requireValue;
    expect(progress.global, isEmpty);
    expect(
      await container
          .read(onboardingProgressProvider.notifier)
          .statusOfEmptyTranscript('media-a'),
      TipStatus.pending,
    );
    expect(find.text(l10n.settingsResetProductTipsDone), findsOneWidget);
  });
}
