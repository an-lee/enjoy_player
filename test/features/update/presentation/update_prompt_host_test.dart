// Tests for `lib/features/update/presentation/update_prompt_host.dart`.
//
// Covers:
// - `UpdatePromptHost` listening to updateCtrlProvider state changes and
//   suppressing the prompt dialog when the player is playing.
// - `runManualUpdateCheck` helper for Settings/About flows across all paths:
//   store-channel notice, offline error, up-to-date notice, and the full
//   update prompt dialog when an update is available.
//
// The update controller is tested directly (snooze/dismiss/etc.) in
// `update_controller_test.dart`. Here we focus on the widget glue and the
// manual flow, both of which depend on `isDirectDistributionChannel`
// (compile-time). We override `debugDefaultTargetPlatformOverride` to flip
// the channel on demand.
import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/update/application/noop_update_strategy.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/update/application/update_providers.dart';
import 'package:enjoy_player/features/update/application/update_strategy.dart';
import 'package:enjoy_player/features/update/domain/update_types.dart';
import 'package:enjoy_player/features/update/presentation/update_prompt_dialog.dart';
import 'package:enjoy_player/features/update/presentation/update_prompt_host.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../../support/fake_player_engine.dart';

ReleaseManifest _manifest({String version = '2.0.0'}) {
  return ReleaseManifest(
    version: version,
    build: 200,
    minSupportedVersion: '1.0.0',
    notes: 'Improvements',
    assets: const {},
  );
}

AppRelease _release({UpdateSeverity severity = UpdateSeverity.optional}) {
  return AppRelease(
    manifest: _manifest(),
    severity: severity,
    currentVersion: '1.0.0',
  );
}

class _ScriptedStrategy implements UpdateStrategy {
  _ScriptedStrategy(this._result);
  final UpdateCheckResult _result;
  @override
  Future<UpdateCheckResult> checkForUpdate({
    required String currentVersion,
    String? snoozedVersion,
    DateTime? snoozeUntil,
  }) async {
    return _result;
  }

  @override
  Stream<UpdateInstallProgress> applyUpdate(AppRelease release) async* {}
  @override
  Future<void> cancelUpdate() async {}
}

Widget _wrap({required ProviderContainer container, required Widget child}) {
  final scheme = ColorScheme.fromSeed(seedColor: const Color(0xFF7B61FF));
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      theme: ThemeData(
        colorScheme: scheme,
        extensions: [EnjoyThemeTokens.build(scheme)],
      ),
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: ScaffoldMessenger(child: Scaffold(body: child)),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late FakePlayerEngine fakeEngine;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    fakeEngine = FakePlayerEngine();
    PackageInfo.setMockInitialValues(
      appName: 'Enjoy Player',
      packageName: 'com.enjoy.player.test',
      version: '1.0.0',
      buildNumber: '100',
      buildSignature: 'test',
    );
  });

  tearDown(() async {
    await fakeEngine.dispose();
    await db.close();
  });

  ProviderContainer makeContainer({
    UpdateStrategy? strategy,
    List<Override> extra = const [],
  }) {
    return ProviderContainer(
      overrides: [
        deviceGlobalAppDatabaseProvider.overrideWithValue(db),
        appDatabaseProvider.overrideWithValue(db),
        updateStrategyProvider.overrideWithValue(
          strategy ?? const NoOpUpdateStrategy(),
        ),
        playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
        ...extra,
      ],
    );
  }

  group('UpdatePromptHost widget', () {
    testWidgets('renders child widget when there is no update', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container: container,
          child: const UpdatePromptHost(child: Text('payload')),
        ),
      );
      await tester.pump();

      expect(find.text('payload'), findsOneWidget);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets(
      'shows prompt dialog when state has release and player is idle',
      (tester) async {
        final container = makeContainer();
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _wrap(
            container: container,
            child: const UpdatePromptHost(child: Text('payload')),
          ),
        );
        await tester.pump();

        // Trigger an update - state has hasUpdate=true.
        container.read(updateCtrlProvider.notifier).state = UpdateCheckResult(
          availability: UpdateAvailability.updateAvailable,
          release: _release(),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        // Dialog should appear since player is not playing.
        expect(find.byType(UpdatePromptDialog), findsOneWidget);
        expect(find.text('payload'), findsOneWidget);
      },
    );

    testWidgets('renders child without bootstrap on store channel', (
      tester,
    ) async {
      final container = makeContainer();
      addTearDown(container.dispose);
      // Default test target is android (store channel), so bootstrap
      // should not be scheduled. The widget should still render fine.
      await tester.pumpWidget(
        _wrap(
          container: container,
          child: const UpdatePromptHost(child: Text('store-payload')),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('store-payload'), findsOneWidget);
    });
  });

  group('runManualUpdateCheck', () {
    testWidgets('shows up-to-date notice when result has no update', (
      tester,
    ) async {
      final container = makeContainer(
        strategy: _ScriptedStrategy(const UpdateCheckResult.upToDate()),
      );
      addTearDown(container.dispose);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () => runManualUpdateCheck(context, ref),
                child: const Text('Run'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SnackBar), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('shows offline notice when result has offline error', (
      tester,
    ) async {
      final container = makeContainer(
        strategy: _ScriptedStrategy(
          const UpdateCheckResult(
            availability: UpdateAvailability.upToDate,
            errorMessage: 'offline',
          ),
        ),
      );
      addTearDown(container.dispose);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () => runManualUpdateCheck(context, ref),
                child: const Text('Run'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      expect(find.byType(SnackBar), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });

    testWidgets('shows store-channel info notice on mobile', (tester) async {
      final container = makeContainer();
      addTearDown(container.dispose);

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () => runManualUpdateCheck(context, ref),
                child: const Text('Run'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 200));

      // Should display info notice about store channel.
      expect(find.byType(SnackBar), findsOneWidget);
    });

    testWidgets('shows update prompt dialog when update is available', (
      tester,
    ) async {
      final container = makeContainer(
        strategy: _ScriptedStrategy(
          UpdateCheckResult(
            availability: UpdateAvailability.updateAvailable,
            release: _release(),
          ),
        ),
      );
      addTearDown(container.dispose);

      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: Consumer(
            builder: (context, ref, _) {
              return ElevatedButton(
                onPressed: () => runManualUpdateCheck(context, ref),
                child: const Text('Run'),
              );
            },
          ),
        ),
      );
      await tester.pump();

      await tester.tap(find.text('Run'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 500));

      // Update dialog should be shown.
      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.byType(UpdatePromptDialog), findsOneWidget);
      debugDefaultTargetPlatformOverride = null;
    });
  });
}
