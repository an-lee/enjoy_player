import 'package:drift/native.dart';
import 'package:enjoy_player/data/api/api_client.dart';
import 'package:enjoy_player/data/api/services/audio_api.dart';
import 'package:enjoy_player/data/api/services/video_api.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/auth/presentation/widgets/auth_required_callout.dart';
import 'package:enjoy_player/features/cloud/application/cloud_add_to_library.dart';
import 'package:enjoy_player/features/cloud/application/cloud_providers.dart';
import 'package:enjoy_player/features/cloud/data/cloud_index_repository.dart';
import 'package:enjoy_player/features/cloud/domain/remote_library_item.dart';
import 'package:enjoy_player/features/cloud/presentation/cloud_library_body.dart';
import 'package:enjoy_player/features/player/application/player_controller.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'test-user', email: 't@example.com', name: 'Test'),
  );
}

class _SignedOutAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedOut();
}

class _NullPlayerController extends PlayerController {
  @override
  PlaybackSession? build() => null;
}

/// A fake [CloudIndexRepository] that returns canned items.
class _FakeCloudIndexRepository extends CloudIndexRepository {
  _FakeCloudIndexRepository({
    this.fakeAudios = const [],
    this.fakeVideos = const [],
  }) : super(
         audioApi: AudioApi(_dummyClient()),
         videoApi: VideoApi(_dummyClient()),
       );

  final List<RemoteLibraryItem> fakeAudios;
  final List<RemoteLibraryItem> fakeVideos;

  @override
  Future<List<RemoteLibraryItem>> fetchAudios({String? updatedAfter}) async =>
      fakeAudios;

  @override
  Future<List<RemoteLibraryItem>> fetchVideos({String? updatedAfter}) async =>
      fakeVideos;
}

ApiClient _dummyClient() {
  return ApiClient(
    httpClient: MockClient((_) async => http.Response('', 404)),
    getBaseUrl: () async => 'http://localhost',
    getAccessToken: () async => null,
  );
}

RemoteLibraryItem _audioItem({
  String id = 'audio-1',
  String title = 'Podcast Episode 1',
}) {
  return RemoteLibraryItem(
    id: id,
    isVideo: false,
    title: title,
    durationSeconds: 300,
    language: 'en',
    provider: 'user',
    rawJson: {'id': id, 'updatedAt': '2024-01-01T00:00:00Z'},
  );
}

RemoteLibraryItem _videoItem({
  String id = 'video-1',
  String title = 'Lecture 1',
}) {
  return RemoteLibraryItem(
    id: id,
    isVideo: true,
    title: title,
    durationSeconds: 600,
    language: 'en',
    provider: 'user',
    rawJson: {'id': id, 'updatedAt': '2024-01-01T00:00:00Z'},
  );
}

// ---------------------------------------------------------------------------
// Harness
// ---------------------------------------------------------------------------

Widget _wrap({required Widget child, required List<Override> overrides}) {
  return ProviderScope(
    overrides: overrides,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

/// Builds a [CloudLibraryBody] inside a [DefaultTabController] harness.
Widget _harness({
  required List<Override> overrides,
  int initialTabIndex = 0,
  GlobalKey<CloudLibraryBodyState>? stateKey,
}) {
  return _wrap(
    overrides: overrides,
    child: DefaultTabController(
      length: 2,
      initialIndex: initialTabIndex,
      child: Builder(
        builder: (context) {
          final tabController = DefaultTabController.of(context);
          return CloudLibraryBody(key: stateKey, tabController: tabController);
        },
      ),
    ),
  );
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  List<Override> signedInOverrides({
    List<RemoteLibraryItem> audios = const [],
    List<RemoteLibraryItem> videos = const [],
  }) {
    return [
      appDatabaseProvider.overrideWithValue(db),
      authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
      playerControllerProvider.overrideWith(_NullPlayerController.new),
      cloudIndexRepositoryProvider.overrideWithValue(
        _FakeCloudIndexRepository(fakeAudios: audios, fakeVideos: videos),
      ),
      cloudAddToLibraryProvider.overrideWithValue(CloudAddToLibrary(db)),
    ];
  }

  group('CloudLibraryBody', () {
    testWidgets('shows auth required callout when signed out', (tester) async {
      await tester.pumpWidget(
        _harness(
          overrides: [
            authCtrlProvider.overrideWith(_SignedOutAuthCtrl.new),
            playerControllerProvider.overrideWith(_NullPlayerController.new),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // AuthRequiredCallout should be visible.
      expect(find.byType(AuthRequiredCallout), findsOneWidget);
    });

    testWidgets('shows video grid with items when signed in', (tester) async {
      final stateKey = GlobalKey<CloudLibraryBodyState>();
      await tester.pumpWidget(
        _harness(
          stateKey: stateKey,
          overrides: signedInOverrides(
            videos: [
              _videoItem(id: 'v1', title: 'Lecture 1'),
              _videoItem(id: 'v2', title: 'Lecture 2'),
            ],
          ),
        ),
      );
      // Let auth resolve and widget rebuild.
      await tester.pumpAndSettle();

      // Trigger a refresh now that auth is resolved.
      stateKey.currentState!.refreshActiveTab();
      await tester.pumpAndSettle();

      // Video items should be rendered.
      expect(find.text('Lecture 1'), findsOneWidget);
      expect(find.text('Lecture 2'), findsOneWidget);
    });

    testWidgets('shows audio list on second tab', (tester) async {
      final stateKey = GlobalKey<CloudLibraryBodyState>();
      await tester.pumpWidget(
        _harness(
          stateKey: stateKey,
          initialTabIndex: 1,
          overrides: signedInOverrides(
            audios: [
              _audioItem(id: 'a1', title: 'Podcast Episode 1'),
              _audioItem(id: 'a2', title: 'Podcast Episode 2'),
            ],
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger a refresh now that auth is resolved.
      stateKey.currentState!.refreshActiveTab();
      await tester.pumpAndSettle();

      // Audio items should be rendered on the audio tab.
      expect(find.text('Podcast Episode 1'), findsOneWidget);
      expect(find.text('Podcast Episode 2'), findsOneWidget);
    });

    testWidgets('shows empty state for videos when no items', (tester) async {
      final stateKey = GlobalKey<CloudLibraryBodyState>();
      await tester.pumpWidget(
        _harness(
          stateKey: stateKey,
          overrides: signedInOverrides(videos: []),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger a refresh so the empty batch marks the list as done.
      stateKey.currentState!.refreshActiveTab();
      await tester.pumpAndSettle();

      // Empty state should show the video empty title.
      expect(find.text('No cloud video yet'), findsOneWidget);
    });

    testWidgets('shows empty state for audios when no items', (tester) async {
      final stateKey = GlobalKey<CloudLibraryBodyState>();
      await tester.pumpWidget(
        _harness(
          stateKey: stateKey,
          initialTabIndex: 1,
          overrides: signedInOverrides(audios: []),
        ),
      );
      await tester.pumpAndSettle();

      // Trigger a refresh so the empty batch marks the list as done.
      stateKey.currentState!.refreshActiveTab();
      await tester.pumpAndSettle();

      // Empty state should show the audio empty title.
      expect(find.text('No cloud audio yet'), findsOneWidget);
    });
  });
}
