import 'package:drift/native.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_controller.dart';
import 'package:enjoy_player/features/onboarding/application/onboarding_progress_provider.dart';
import 'package:enjoy_player/features/onboarding/domain/onboarding_tip_id.dart';
import 'package:enjoy_player/features/onboarding/domain/tip_progress.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
        appDatabaseProvider.overrideWithValue(db),
      ],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  test('empty-transcript progress is independent per mediaId', () async {
    final progress = container.read(onboardingProgressProvider.notifier);
    await container.read(onboardingProgressProvider.future);

    await progress.markEmptyTranscript('media-a', TipStatus.skipped);
    await progress.markEmptyTranscript('media-b', TipStatus.completed);

    expect(
      await progress.statusOfEmptyTranscript('media-a'),
      TipStatus.skipped,
    );
    expect(
      await progress.statusOfEmptyTranscript('media-b'),
      TipStatus.completed,
    );
    expect(
      await progress.statusOfEmptyTranscript('media-c'),
      TipStatus.pending,
    );
  });

  test(
    'onTranscriptAvailable auto-completes empty tip for that media only',
    () async {
      final progress = container.read(onboardingProgressProvider.notifier);
      await container.read(onboardingProgressProvider.future);
      await progress.markEmptyTranscript('other', TipStatus.skipped);

      await container
          .read(onboardingControllerProvider.notifier)
          .onTranscriptAvailable('target');

      expect(
        await progress.statusOfEmptyTranscript('target'),
        TipStatus.completed,
      );
      expect(
        await progress.statusOfEmptyTranscript('other'),
        TipStatus.skipped,
      );
    },
  );

  test('resetAll clears global and per-media empty-transcript keys', () async {
    final progress = container.read(onboardingProgressProvider.notifier);
    await container.read(onboardingProgressProvider.future);

    await progress.markEmptyTranscript('m1', TipStatus.completed);
    await progress.markGlobal(OnboardingTipId.homeImport, TipStatus.completed);

    await progress.resetAll();

    final snap = container.read(onboardingProgressProvider).requireValue;
    expect(snap.global, isEmpty);
    expect(await progress.statusOfEmptyTranscript('m1'), TipStatus.pending);
  });
}
