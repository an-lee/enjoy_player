import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/settings/application/settings_selected_section_provider.dart';
import 'package:enjoy_player/features/settings/domain/settings_search_entry.dart';
import 'package:enjoy_player/features/settings/presentation/settings_screen.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_layout_single_column.dart';
import 'package:enjoy_player/features/settings/presentation/widgets/settings_layout_two_pane.dart';
import 'package:enjoy_player/features/shadow_reading/application/recording_input_device_controller.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
import 'package:enjoy_player/features/sync/data/sync_queue_repository.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

class _StaticPrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => AppPreferencesState.initial;
}

/// Avoids real hardware/FFI microphone enumeration during widget tests,
/// which can hang or behave unpredictably outside a full Flutter engine.
class _FakeRecordingInputDeviceCtrl extends RecordingInputDeviceCtrl {
  @override
  Future<RecordingInputDeviceState> build() async =>
      const RecordingInputDeviceState(
        devices: [],
        selectedId: null,
        persistedId: null,
      );
}

/// Common test overrides. Sync providers are pinned to static values
/// (rather than left to hit real drift `.watch()` streams) so widget tests
/// can safely dispose without tripping flutter_test's pending-timer check.
///
/// (Untyped: Riverpod 3.x's `Override` type isn't part of its public API.)
// ignore: strict_top_level_inference
_settingsTestOverrides(AppDatabase db) => [
  deviceGlobalAppDatabaseProvider.overrideWithValue(db),
  appDatabaseProvider.overrideWithValue(db),
  authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
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
];

Widget _harness({required AppDatabase db}) {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ProviderScope(
    overrides: _settingsTestOverrides(db),
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        useMaterial3: true,
        brightness: Brightness.dark,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: const SettingsScreen(),
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

  group('SettingsScreen layout', () {
    testWidgets('renders single-column layout below the rail breakpoint', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(700, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(db: db));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsLayoutSingleColumn), findsOneWidget);
      expect(find.byType(SettingsLayoutTwoPane), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets('renders two-pane layout at/above the rail breakpoint', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(_harness(db: db));
      await tester.pumpAndSettle();

      expect(find.byType(SettingsLayoutTwoPane), findsOneWidget);
      expect(find.byType(SettingsLayoutSingleColumn), findsNothing);
      expect(tester.takeException(), isNull);
    });

    testWidgets(
      'resizing across the breakpoint repeatedly preserves selection and '
      'raises no exceptions',
      (tester) async {
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);
        tester.view.devicePixelRatio = 1.0;

        final container = ProviderContainer(
          overrides: _settingsTestOverrides(db),
        );
        addTearDown(container.dispose);
        container
            .read(settingsSelectedSectionProvider.notifier)
            .select(SettingsSectionIds.recording);

        final scheme = ColorScheme.fromSeed(
          seedColor: const Color(0xFF7B61FF),
          brightness: Brightness.dark,
        );
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              theme: ThemeData(
                colorScheme: scheme,
                extensions: [EnjoyThemeTokens.build(scheme)],
              ),
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: const SettingsScreen(),
            ),
          ),
        );
        await tester.pumpAndSettle();

        for (var i = 0; i < 10; i++) {
          final wide = i.isEven;
          tester.view.physicalSize = wide
              ? const Size(1200, 900)
              : const Size(700, 900);
          await tester.pumpAndSettle();
        }

        expect(tester.takeException(), isNull);
        expect(
          container.read(settingsSelectedSectionProvider),
          SettingsSectionIds.recording,
        );
      },
    );
  });

  group('SettingsScreen sections (single column)', () {
    testWidgets(
      'all sections render content immediately (no collapse headers)',
      (tester) async {
        tester.view.physicalSize = const Size(700, 2400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(_harness(db: db));
        await tester.pumpAndSettle();

        final l10n = await AppLocalizations.delegate.load(const Locale('en'));

        expect(
          find.text(l10n.settingsAppearanceDisplayLanguage),
          findsOneWidget,
        );
        expect(find.text(l10n.settingsAiProvidersTileTitle), findsOneWidget);

        expect(
          find.text(l10n.settingsTranscriptEnrichmentTitle),
          findsOneWidget,
        );
        expect(find.text(l10n.settingsTranscriptKaraokeTitle), findsOneWidget);
        expect(
          find.text(l10n.settingsTranscriptIpaOverlayTitle),
          findsOneWidget,
        );
        expect(
          find.text(l10n.settingsTranscriptWordPracticeTitle),
          findsOneWidget,
        );

        expect(find.text(l10n.settingsApiBaseUrl), findsOneWidget);
        expect(find.text(l10n.appTitle), findsWidgets);
        expect(tester.takeException(), isNull);
      },
    );
  });
}
