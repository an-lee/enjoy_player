import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/presentation/widgets/transport/transport_volume_button.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../../../support/fake_player_engine.dart';

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 't@test.com', name: 'Test'),
  );
}

ProviderContainer _containerFor(AppDatabase db, FakePlayerEngine fake) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      deviceGlobalAppDatabaseProvider.overrideWithValue(db),
      authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
      playerEngineTestDoubleProvider.overrideWithValue(fake),
    ],
  );
}

Widget _wrap({required ProviderContainer container, required Widget child}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: true),
        child: child ?? const SizedBox.shrink(),
      ),
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  late AppDatabase db;
  late FakePlayerEngine fake;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
    fake = FakePlayerEngine();
  });

  tearDown(() async {
    await db.close();
    await fake.dispose();
  });

  testWidgets('TransportVolumeButton renders a volume icon', (tester) async {
    final container = _containerFor(db, fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _wrap(container: container, child: const TransportVolumeButton()),
    );
    await tester.pump();

    // The button should render an IconButton with a volume-related icon.
    expect(find.byIcon(Icons.volume_up_rounded), findsOneWidget);
  });

  testWidgets('TransportVolumeButton shows muted icon when volume is 0', (
    tester,
  ) async {
    final container = _containerFor(db, fake);
    addTearDown(container.dispose);
    // Force volume to 0.
    await container.read(playerPreferencesCtrlProvider.notifier).setVolume(0);
    await tester.pumpWidget(
      _wrap(container: container, child: const TransportVolumeButton()),
    );
    await tester.pump();

    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });

  testWidgets('TransportVolumeButton toggles mute on tap', (tester) async {
    final container = _containerFor(db, fake);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      _wrap(container: container, child: const TransportVolumeButton()),
    );
    await tester.pump();

    // Tap the icon button.
    await tester.tap(find.byIcon(Icons.volume_up_rounded));
    await tester.pump();

    // After muting, the icon should switch.
    expect(find.byIcon(Icons.volume_off_rounded), findsOneWidget);
  });
}
