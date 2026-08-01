import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/layout/enjoy_page_kind.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/core/theme/widgets/enjoy_card.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/application/profile_practice_stats_provider.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/profile_content.dart';
import 'package:enjoy_player/features/library/domain/learning_statistics.dart';
import 'package:enjoy_player/features/settings/presentation/settings_screen.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_section_card.dart';
import 'package:enjoy_player/features/shadow_reading/application/recording_input_device_controller.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
import 'package:enjoy_player/features/sync/data/sync_queue_repository.dart';
import 'package:enjoy_player/features/vocabulary/application/vocabulary_providers.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_stats.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

const _fakeProfile = UserProfile(
  id: 'user-1',
  email: 'reader@example.com',
  name: 'Reader',
  balance: 12.5,
);

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(profile: _fakeProfile);
}

class _StaticPrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => AppPreferencesState.initial;
}

class _FakeRecordingInputDeviceCtrl extends RecordingInputDeviceCtrl {
  @override
  Future<RecordingInputDeviceState> build() async =>
      const RecordingInputDeviceState(
        devices: [],
        selectedId: null,
        persistedId: null,
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

  testWidgets(
    'Settings section cards share the hub gutter with Profile on mobile',
    (tester) async {
      // Compact phone width — hub gutter is pageGutterCompact (16).
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      final scheme = ColorScheme.fromSeed(
        seedColor: const Color(0xFF7B61FF),
        brightness: Brightness.dark,
      );
      final tokens = EnjoyThemeTokens.build(scheme);

      final overrides = [
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
        appDatabaseProvider.overrideWithValue(db),
        authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
        appPreferencesCtrlProvider.overrideWith(_StaticPrefsCtrl.new),
        recordingInputDeviceCtrlProvider.overrideWith(
          _FakeRecordingInputDeviceCtrl.new,
        ),
        syncQueueSnapshotProvider.overrideWith(
          (ref) => Stream.value(
            const SyncQueueSnapshot(
              retryablePending: 0,
              permanentlyFailed: 0,
              detailRows: [],
            ),
          ),
        ),
        syncLastFullSyncAtProvider.overrideWith((ref) async => null),
        profilePracticeStatsProvider.overrideWith(
          (ref) async => LearningStatistics.empty(),
        ),
        vocabularyStatsProvider.overrideWithValue(
          const VocabularyStats(
            total: 0,
            due: 0,
            newCount: 0,
            learningCount: 0,
            reviewingCount: 0,
            masteredCount: 0,
          ),
        ),
      ];

      // Measure Profile card left edge first.
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
              brightness: Brightness.dark,
              extensions: [tokens],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: ProfileContent()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final profileCard = tester.getTopLeft(find.byType(EnjoyCard).first);
      final expectedInset = EnjoyPageMetrics.of(
        tester.element(find.byType(ProfileContent)),
        kind: EnjoyPageKind.hub,
        paneWidth: 390,
      ).horizontalInset;
      expect(profileCard.dx, closeTo(expectedInset, 0.5));

      // Settings should match the same hub inset (no extra card pad).
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides,
          child: MaterialApp(
            theme: ThemeData(
              colorScheme: scheme,
              useMaterial3: true,
              brightness: Brightness.dark,
              extensions: [tokens],
            ),
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: const SettingsScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      final settingsCard = tester.getTopLeft(
        find.byType(SettingsSectionCard).first,
      );
      expect(settingsCard.dx, closeTo(expectedInset, 0.5));
      expect(settingsCard.dx, closeTo(profileCard.dx, 0.5));
    },
  );
}
