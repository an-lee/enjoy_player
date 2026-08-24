import 'dart:io';

import 'package:drift/native.dart';
import 'package:enjoy_player/app.dart';
import 'package:enjoy_player/core/application/app_preferences_provider.dart';
import 'package:enjoy_player/core/theme/enjoy_tokens.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/discover/application/discover_providers.dart';
import 'package:enjoy_player/features/discover/domain/discover_channel.dart';
import 'package:enjoy_player/features/library/application/library_media_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/sync/application/sync_providers.dart';
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

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

class _StaticPrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async => AppPreferencesState.initial;
}

class _LightPrefsCtrl extends AppPreferencesCtrl {
  @override
  Future<AppPreferencesState> build() async =>
      AppPreferencesState.initial.copyWith(themeMode: ThemeMode.light);
}

class _NoopUpdateCtrl extends UpdateCtrl {
  @override
  UpdateCheckResult? build() => null;

  @override
  Future<void> bootstrap() async {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('EnjoyApp smoke test boots signed-out home shell', (
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

    final root = Directory.systemTemp.createTempSync('enjoy_widget_smoke');
    PathProviderPlatform.instance = TestPathProvider(root.path);

    final db = AppDatabase(executor: NativeDatabase.memory());
    final fakeEngine = FakePlayerEngine();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceGlobalAppDatabaseProvider.overrideWithValue(db),
          appDatabaseProvider.overrideWithValue(db),
          authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_StaticPrefsCtrl.new),
          updateCtrlProvider.overrideWith(_NoopUpdateCtrl.new),
          playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
          syncEnqueueProvider.overrideWithValue((_, _, _) async {}),
          libraryHomeRecentsProvider.overrideWith(
            (ref) => Stream<List<Media>>.value(const []),
          ),
          discoverSubscriptionsProvider.overrideWith(
            (ref) => Stream<List<DiscoverChannel>>.value(const []),
          ),
        ],
        child: const EnjoyApp(themeBuilder: _testTheme),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(EnjoyApp), findsOneWidget);
    expect(find.byType(MaterialApp), findsOneWidget);
    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.system,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await fakeEngine.dispose();
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  testWidgets('EnjoyApp MaterialApp.themeMode follows prefs', (tester) async {
    FlutterSecureStorage.setMockInitialValues({});
    PackageInfo.setMockInitialValues(
      appName: 'Enjoy Player',
      packageName: 'com.enjoy.player.test',
      version: '0.3.1',
      buildNumber: '2',
      buildSignature: 'test',
    );

    final root = Directory.systemTemp.createTempSync('enjoy_widget_theme_mode');
    PathProviderPlatform.instance = TestPathProvider(root.path);

    final db = AppDatabase(executor: NativeDatabase.memory());
    final fakeEngine = FakePlayerEngine();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          deviceGlobalAppDatabaseProvider.overrideWithValue(db),
          appDatabaseProvider.overrideWithValue(db),
          authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
          appPreferencesCtrlProvider.overrideWith(_LightPrefsCtrl.new),
          updateCtrlProvider.overrideWith(_NoopUpdateCtrl.new),
          playerEngineTestDoubleProvider.overrideWithValue(fakeEngine),
          syncEnqueueProvider.overrideWithValue((_, _, _) async {}),
          libraryHomeRecentsProvider.overrideWith(
            (ref) => Stream<List<Media>>.value(const []),
          ),
          discoverSubscriptionsProvider.overrideWith(
            (ref) => Stream<List<DiscoverChannel>>.value(const []),
          ),
        ],
        child: const EnjoyApp(themeBuilder: _testTheme),
      ),
    );

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      tester.widget<MaterialApp>(find.byType(MaterialApp)).themeMode,
      ThemeMode.light,
    );

    await tester.pumpWidget(const SizedBox.shrink());
    await tester.pump();
    await fakeEngine.dispose();
    await db.close();
    if (root.existsSync()) root.deleteSync(recursive: true);
  });
}
