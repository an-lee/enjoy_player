import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:showcaseview/showcaseview.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_controller.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_progress_provider.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_eligibility.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';
import 'package:enjoy_player/features/onboarding/presentation/onboarding_target.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

/// Registers ShowcaseView with animations off so [pumpAndSettle] can finish.
class _TestShowcaseHost extends ConsumerStatefulWidget {
  const _TestShowcaseHost({required this.child});

  final Widget child;

  @override
  ConsumerState<_TestShowcaseHost> createState() => _TestShowcaseHostState();
}

class _TestShowcaseHostState extends ConsumerState<_TestShowcaseHost> {
  @override
  void initState() {
    super.initState();
    ShowcaseView.register(
      enableAutoScroll: false,
      disableMovingAnimation: true,
      disableScaleAnimation: true,
      skipIfTargetNotPresent: false,
      onStart: (_, _) {
        ref.read(onboardingControllerProvider.notifier).onShowcaseStarted();
      },
      onFinish: () {
        ref.read(onboardingControllerProvider.notifier).onShowcaseFinished();
      },
      onDismiss: (key) {
        ref
            .read(onboardingControllerProvider.notifier)
            .onShowcaseDismissed(key);
      },
      globalFloatingActionWidget: (context) {
        final l10n = AppLocalizations.of(context)!;
        return FloatingActionWidget(
          right: 16,
          bottom: 24,
          child: TextButton(
            onPressed: () => ShowcaseView.get().dismiss(),
            child: Text(l10n.onboardingTipSkip),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    try {
      ShowcaseView.get().unregister();
    } on Object {
      // Already unregistered.
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class _HomeTipSurface extends ConsumerStatefulWidget {
  const _HomeTipSurface();

  @override
  ConsumerState<_HomeTipSurface> createState() => _HomeTipSurfaceState();
}

class _HomeTipSurfaceState extends ConsumerState<_HomeTipSurface> {
  var importTaps = 0;
  var craftTaps = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(
        ref
            .read(onboardingControllerProvider.notifier)
            .tryStartHomeEntries(const TriggerContext(routePath: '/')),
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        OnboardingTarget(
          tipId: OnboardingTipId.homeCraft,
          onTargetAction: () => setState(() => craftTaps++),
          child: OutlinedButton(
            onPressed: () {
              unawaited(
                ref
                    .read(onboardingControllerProvider.notifier)
                    .onTargetActed(OnboardingTipId.homeCraft),
              );
              setState(() => craftTaps++);
            },
            child: const Text('Craft action'),
          ),
        ),
        const SizedBox(height: 16),
        OnboardingTarget(
          tipId: OnboardingTipId.homeImport,
          onTargetAction: () => setState(() => importTaps++),
          child: FilledButton(
            onPressed: () {
              unawaited(
                ref
                    .read(onboardingControllerProvider.notifier)
                    .onTargetActed(OnboardingTipId.homeImport),
              );
              setState(() => importTaps++);
            },
            child: const Text('Import action'),
          ),
        ),
      ],
    );
  }
}

Widget _harness({required AppDatabase db}) {
  return ProviderScope(
    overrides: [
      deviceGlobalAppDatabaseProvider.overrideWithValue(db),
      appDatabaseProvider.overrideWithValue(db),
    ],
    child: const MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      locale: Locale('en'),
      home: _TestShowcaseHost(
        child: Scaffold(body: Center(child: _HomeTipSurface())),
      ),
    ),
  );
}

Future<void> _pumpTips(WidgetTester tester) async {
  // Allow post-frame start + showcase target wait frames.
  for (var i = 0; i < 40; i++) {
    await tester.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets('Home tips start with Import then chain to Craft', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_harness(db: db));
    await _pumpTips(tester);

    expect(find.text(l10n.onboardingTipHomeImportTitle), findsOneWidget);
    expect(find.text(l10n.onboardingTipHomeCraftTitle), findsNothing);

    // Learn-by-doing on Import advances to Craft in the same visit.
    await tester.tap(find.text('Import action'));
    await _pumpTips(tester);

    expect(find.text(l10n.onboardingTipHomeCraftTitle), findsOneWidget);
  });

  testWidgets('Skip ends Home sequence and persists so tips do not return', (
    tester,
  ) async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    await tester.pumpWidget(_harness(db: db));
    await _pumpTips(tester);

    expect(find.text(l10n.onboardingTipHomeImportTitle), findsOneWidget);

    await tester.tap(find.text(l10n.onboardingTipSkip));
    await _pumpTips(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.byType(_HomeTipSurface)),
    );
    final progress = container.read(onboardingProgressProvider).requireValue;
    expect(
      progress.statusOfGlobal(OnboardingTipId.homeImport),
      TipStatus.skipped,
    );
    expect(
      progress.statusOfGlobal(OnboardingTipId.homeCraft),
      TipStatus.skipped,
    );

    // Restart attempt must not show overlays again.
    await container
        .read(onboardingControllerProvider.notifier)
        .tryStartHomeEntries(const TriggerContext(routePath: '/'));
    await _pumpTips(tester);

    expect(find.text(l10n.onboardingTipHomeImportTitle), findsNothing);
    expect(find.text(l10n.onboardingTipHomeCraftTitle), findsNothing);
  });
}
