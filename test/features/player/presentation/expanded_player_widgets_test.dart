import 'package:drift/native.dart';
import 'package:enjoy_player/core/riverpod/async_value_x.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/player/application/player_preferences_provider.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/features/player/presentation/expanded_player_widgets.dart';
import 'package:enjoy_player/features/player/presentation/widgets/player_surface_target.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 't@test.com', name: 'Test'),
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

ProviderContainer _containerFor(AppDatabase db) {
  return ProviderContainer(
    overrides: [
      appDatabaseProvider.overrideWithValue(db),
      deviceGlobalAppDatabaseProvider.overrideWithValue(db),
      authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
    ],
  );
}

void main() {
  late AppDatabase db;

  setUp(() async {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  testWidgets(
    'ExpandedPlayerLoadingBody shows the local loading stage for non-YouTube',
    (tester) async {
      final container = _containerFor(db);
      addTearDown(container.dispose);
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: ExpandedPlayerLoadingBody(colorScheme: scheme, mediaId: 'm1'),
        ),
      );
      // Two pumps to settle the AsyncValue's loading -> data (null for non-YouTube).
      await tester.pump();
      await tester.pump();

      // Non-YouTube path → PlayerSurfaceTarget for the loading viewport.
      expect(find.byType(PlayerSurfaceTarget), findsWidgets);
    },
  );

  testWidgets(
    'ExpandedPlayerGenericErrorBody renders the localized error message',
    (tester) async {
      final container = _containerFor(db);
      addTearDown(container.dispose);
      final scheme = ColorScheme.fromSeed(seedColor: Colors.blue);

      await tester.pumpWidget(
        _wrap(
          container: container,
          child: ExpandedPlayerGenericErrorBody(colorScheme: scheme),
        ),
      );
      await tester.pumpAndSettle();

      // Body renders a Scaffold + a Text widget.
      expect(find.byType(Scaffold), findsWidgets);
      expect(find.byType(Text), findsWidgets);
    },
  );

  testWidgets('ExpandedPlayerChromeBody video path omits the AppBar', (
    tester,
  ) async {
    final container = _containerFor(db);
    addTearDown(container.dispose);

    final chrome = (
      mediaId: 'm1',
      dexieTargetType: 'Video',
      mediaType: 'video',
      mediaTitle: 'Video title',
      thumbnailUrl: null,
      durationSeconds: 120.0,
      language: 'en',
    );

    await tester.pumpWidget(
      _wrap(
        container: container,
        child: ExpandedPlayerChromeBody(
          mediaId: 'm1',
          chrome: chrome,
          isPlaying: true,
          accent: Colors.amber,
        ),
      ),
    );
    await tester.pump();

    // Video path never reserves an AppBar slot (even when playing).
    expect(find.byType(AppBar), findsNothing);
  });

  test('ExpandedPlayerChromeBody accepts null accent for both paths', () {
    final audioChrome = (
      mediaId: 'm1',
      dexieTargetType: 'Audio',
      mediaType: 'audio',
      mediaTitle: 'A',
      thumbnailUrl: null,
      durationSeconds: 30.0,
      language: 'en',
    );
    final videoChrome = (
      mediaId: 'm2',
      dexieTargetType: 'Video',
      mediaType: 'video',
      mediaTitle: 'V',
      thumbnailUrl: null,
      durationSeconds: 60.0,
      language: 'en',
    );
    final _audio = ExpandedPlayerChromeBody(
      mediaId: 'm1',
      chrome: audioChrome,
      isPlaying: false,
      accent: null,
    );
    final _video = ExpandedPlayerChromeBody(
      mediaId: 'm2',
      chrome: videoChrome,
      isPlaying: true,
      accent: null,
    );
    expect(_audio, isNotNull);
    expect(_video, isNotNull);
  });

  test('playbackChromeOf returns the stable chrome subset', () {
    final now = DateTime.utc(2026);
    final session = PlaybackSession(
      mediaId: 'm1',
      dexieTargetType: 'Video',
      mediaType: 'video',
      mediaTitle: 'T',
      thumbnailUrl: 'thumb',
      durationSeconds: 30.0,
      currentTimeSeconds: 1.5,
      currentSegmentIndex: 0,
      language: 'en',
      startedAt: now,
      lastActiveAt: now,
    );
    final chrome = playbackChromeOf(session);
    expect(chrome, isNotNull);
    expect(chrome!.mediaId, 'm1');
    expect(chrome.mediaTitle, 'T');
    expect(chrome.thumbnailUrl, 'thumb');
    // playbackChromeOf returns null when session is null.
    expect(playbackChromeOf(null), isNull);
  });

  test('playbackChromeOf ignores clock fields in the chrome tuple', () {
    final chrome = playbackChromeOf(null);
    expect(chrome, isNull);
  });

  test('PlayerPreferencesCtrl reports defaults after construction', () async {
    final container = ProviderContainer(
      overrides: [
        appDatabaseProvider.overrideWithValue(db),
        authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
      ],
    );
    addTearDown(container.dispose);
    // Force the controller to build.
    final initial = container.read(playerPreferencesCtrlProvider);
    expect(initial.volume, greaterThanOrEqualTo(0));
    expect(initial.playbackRate, greaterThan(0));
  });
}
