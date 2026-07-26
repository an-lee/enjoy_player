import 'dart:async';

import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/player/application/open_media_provider.dart';
import 'package:enjoy_player/features/player/application/player_engine_test_double_provider.dart';
import 'package:enjoy_player/features/player/domain/player_launch_request.dart';
import 'package:enjoy_player/features/player/presentation/expanded_player_screen.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../../support/fake_player_engine.dart';

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 't@example.com', name: 'Test'),
  );
}

Widget _wrap({required ProviderContainer container, required Widget child}) {
  return UncontrolledProviderScope(
    container: container,
    child: MediaQuery(
      // Suppress skeleton AnimationController.repeat() so the test framework
      // does not consider a timer pending after disposal.
      data: const MediaQueryData(disableAnimations: true, size: Size(800, 600)),
      child: MaterialApp(
        localizationsDelegates: const [
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: child,
      ),
    ),
  );
}

void main() {
  late AppDatabase db;
  late FakePlayerEngine fake;

  setUpAll(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    fake = FakePlayerEngine();
  });

  tearDownAll(() async {
    await db.close();
    await fake.dispose();
  });

  group('ExpandedPlayerScreen', () {
    testWidgets(
      'renders the loading body when the launch future is still pending',
      (tester) async {
        // The widget reads `openMediaLaunchProvider` and renders the loading
        // body (SkeletonAppBootstrap inside _LocalLoadingVideoStage) before
        // the future resolves. We override the provider body to never
        // resolve so the loading state stays visible.
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            playerEngineTestDoubleProvider.overrideWithValue(fake),
            openMediaLaunchProvider.overrideWith((ref, request) async {
              await Completer<void>().future;
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _wrap(
            container: container,
            child: const ExpandedPlayerScreen(
              launch: PlayerLaunchRequest(mediaId: 'm1'),
            ),
          ),
        );
        await tester.pump();

        expect(find.byType(SkeletonAppBootstrap), findsOneWidget);
      },
    );

    testWidgets(
      'passes the launch request mediaId through to the loading body',
      (tester) async {
        // Verifies the ProviderContainer override is keyed by the same
        // PlayerLaunchRequest shape used by the widget, so the pending
        // future is observed.
        const customLaunch = PlayerLaunchRequest(
          mediaId: 'custom-media-id',
          autoplay: true,
        );

        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            playerEngineTestDoubleProvider.overrideWithValue(fake),
            openMediaLaunchProvider.overrideWith((ref, request) async {
              expect(request.mediaId, 'custom-media-id');
              await Completer<void>().future;
            }),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          _wrap(
            container: container,
            child: const ExpandedPlayerScreen(launch: customLaunch),
          ),
        );
        await tester.pump();
        await tester.pump();

        expect(find.byType(SkeletonAppBootstrap), findsOneWidget);
      },
    );
  });
}
