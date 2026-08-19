/// Regression coverage for [_EnjoyAppState.didChangeAppLifecycleState] — the
/// macOS shutdown hook that drains Drift "DartWorker" background isolates
/// before the engine tears down.
///
/// Without this hook, `ref.onDispose` on the keep-alive DB providers never
/// fires during a normal app quit (Riverpod only disposes when its
/// [ProviderContainer] is torn down — tests and hot restart, not normal quit),
/// so the two Drift worker isolates (`enjoy_player.sqlite` +
/// `enjoy_player_<userId>.sqlite`) were killed mid-shutdown and raced
/// `sqlite3_finalize` on stale prepared-statement handles. The macOS crash
/// signature was
///   `EXC_BAD_ACCESS (SIGSEGV) — sqlite3_finalize + 36 — DartWorker`,
/// i.e. pointer-authentication failure in `sqlite3_finalize` triggered by the
/// Dart VM tearing down isolates that were still mid-close.
library;

import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/app.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/update/application/update_controller.dart';
import 'package:enjoy_player/features/update/domain/update_types.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';

import 'support/fake_player_engine.dart';
import 'support/test_path_provider.dart';

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

class _NoopUpdateCtrl extends UpdateCtrl {
  @override
  UpdateCheckResult? build() => null;

  @override
  Future<void> bootstrap() async {}
}

/// Builds successfully but never resolves — pins the app on its loading
/// branch for the whole test (see `app_loading_branch_test.dart`). Keeps the
/// widget tree compact so we exercise only the lifecycle observer wiring,
/// not the full router.
class _NeverCompletingPrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async {
    return Completer<AppPreferencesState>().future;
  }
}

ThemeData _testTheme() {
  final scheme = ColorScheme.fromSeed(
    seedColor: const Color(0xFF7B61FF),
    brightness: Brightness.dark,
  );
  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    brightness: Brightness.dark,
    extensions: [EnjoyThemeTokens.build(scheme)],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('AppLifecycleState.detached drains every open AppDatabase via '
      'closeAndClearAllAppDatabases before the engine tears down', (
    tester,
  ) async {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Enjoy Player',
      packageName: 'com.enjoy.player.test',
      version: '0.3.1',
      buildNumber: '2',
      buildSignature: 'test',
    );

    final root = Directory.systemTemp.createTempSync('enjoy_app_shutdown_hook');
    addTearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });
    PathProviderPlatform.instance = TestPathProvider(root.path);

    // The lifecycle hook calls [closeAndClearAllAppDatabases]; pin its
    // invocation via the test-only debug hook so we don't need to plumb
    // the private singleton maps through a public API. The observable
    // side effect of the hook IS this call.
    var shutdownCalls = 0;
    debugOnShutdownDatabaseClose = () => shutdownCalls++;
    addTearDown(() => debugOnShutdownDatabaseClose = null);

    final deviceGlobal = AppDatabase(executor: NativeDatabase.memory());
    final perUser = AppDatabase(executor: NativeDatabase.memory());
    addTearDown(deviceGlobal.close);
    addTearDown(perUser.close);

    final fakeEngine = FakePlayerEngine();
    addTearDown(fakeEngine.dispose);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceGlobalAppDatabaseProvider.overrideWithValue(deviceGlobal),
          appDatabaseProvider.overrideWithValue(perUser),
          authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(
            _NeverCompletingPrefsCtrl.new,
          ),
          updateCtrlProvider.overrideWith(_NoopUpdateCtrl.new),
          playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
        ],
        child: const EnjoyApp(themeBuilder: _testTheme),
      ),
    );
    for (var i = 0; i < 4; i++) {
      await tester.pump();
    }

    // Sanity: the widget is mounted, the lifecycle observer is registered,
    // and no premature close has been triggered.
    expect(find.byType(EnjoyApp), findsOneWidget);
    expect(shutdownCalls, 0);

    // Dispatch the macOS-quit lifecycle event the same way Flutter's
    // macOS embedder does after `-[NSApplication terminate:]`.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.detached);

    // closeAndClearAllAppDatabases is fire-and-forget (`unawaited` in the
    // lifecycle hook), so pump the event loop until the close future
    // resolves and the debug hook has fired.
    for (var i = 0; i < 20 && shutdownCalls == 0; i++) {
      await tester.pump(const Duration(milliseconds: 10));
    }

    expect(
      shutdownCalls,
      1,
      reason: 'detached lifecycle must trigger closeAndClearAllAppDatabases',
    );

    // Cleanup — pumpWidget(SizedBox) so the observer is removed before the
    // tearDown's explicit close() runs, matching production semantics.
    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
  });

  testWidgets(
    'lifecycle states other than detached do not trigger shutdown drain',
    (tester) async {
      FlutterSecureStorage.setMockInitialValues({});
      PackageInfo.setMockInitialValues(
        appName: 'Enjoy Player',
        packageName: 'com.enjoy.player.test',
        version: '0.3.1',
        buildNumber: '2',
        buildSignature: 'test',
      );

      final root = Directory.systemTemp.createTempSync(
        'enjoy_app_shutdown_hook_negative',
      );
      addTearDown(() {
        if (root.existsSync()) root.deleteSync(recursive: true);
      });
      PathProviderPlatform.instance = TestPathProvider(root.path);

      var shutdownCalls = 0;
      debugOnShutdownDatabaseClose = () => shutdownCalls++;
      addTearDown(() => debugOnShutdownDatabaseClose = null);

      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);

      final fakeEngine = FakePlayerEngine();
      addTearDown(fakeEngine.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            deviceGlobalAppDatabaseProvider.overrideWithValue(db),
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
            appPreferencesCtrlProvider.overrideWith(
              _NeverCompletingPrefsCtrl.new,
            ),
            updateCtrlProvider.overrideWith(_NoopUpdateCtrl.new),
            playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
          ],
          child: const EnjoyApp(themeBuilder: _testTheme),
        ),
      );
      for (var i = 0; i < 4; i++) {
        await tester.pump();
      }

      // Cycle through every other lifecycle state to guard against a future
      // change accidentally widening the hook to fire on paused/inactive.
      for (final state in AppLifecycleState.values) {
        if (state == AppLifecycleState.detached) continue;
        tester.binding.handleAppLifecycleStateChanged(state);
        await tester.pump();
      }

      expect(shutdownCalls, 0, reason: 'only detached should drain databases');

      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump();
    },
  );
}
