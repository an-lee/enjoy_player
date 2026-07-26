import 'package:drift/native.dart';
import 'package:enjoy_player/core/theme/widgets/skeleton.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/auth/application/auth_controller.dart';
import 'package:enjoy_player/features/auth/domain/auth_state.dart';
import 'package:enjoy_player/features/auth/domain/user_profile.dart';
import 'package:enjoy_player/features/transcript/application/transcript_fetch_controller.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/application/video_row_for_media_provider.dart';
import 'package:enjoy_player/features/transcript/domain/transcript_fetch_status.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_empty_state.dart';
import 'package:enjoy_player/features/transcript/presentation/transcript_panel.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Sentinel value for [VideoRow.createdAt]/[updatedAt] (UTC midnight 2024-01-01).
final DateTime _epoch = DateTime.utc(2024);

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
      home: Scaffold(body: child),
    ),
  );
}

class _SignedInAuthCtrl extends AuthCtrl {
  @override
  Future<AuthState> build() async => const AuthSignedIn(
    profile: UserProfile(id: 'u1', email: 't@example.com', name: 'Test'),
  );
}

void main() {
  late AppDatabase db;

  setUpAll(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDownAll(() async {
    await db.close();
  });

  group('TranscriptPanel', () {
    testWidgets(
      'renders the SkeletonTranscript placeholder while lines are loading',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            transcriptLinesForMediaProvider(
              'm1',
            ).overrideWith((ref) => const Stream<List<TranscriptLine>>.empty()),
            videoRowForMediaProvider('m1').overrideWith(
              (ref) async => VideoRow(
                createdAt: _epoch,
                updatedAt: _epoch,
                id: 'm1',
                vid: 'v1',
                provider: 'youtube',
                title: 'T',
                durationSeconds: 60,
                language: 'en',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _wrap(
            container: container,
            child: const TranscriptPanel(mediaId: 'm1'),
          ),
        );
        // We are still in loading state — render the skeleton.
        expect(find.byType(SkeletonTranscript), findsOneWidget);
      },
    );

    testWidgets('renders an inline error UI when lines stream errors out', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          transcriptLinesForMediaProvider(
            'm1',
          ).overrideWith((ref) => Stream.error(Exception('boom'))),
          transcriptFetchStatusProvider('m1').overrideWith(
            (ref) => const TranscriptFetchUiState(
              status: TranscriptFetchStatus.idle,
            ),
          ),
          videoRowForMediaProvider('m1').overrideWith(
            (ref) async => VideoRow(
              createdAt: _epoch,
              updatedAt: _epoch,
              id: 'm1',
              vid: 'v1',
              provider: 'local',
              title: 'T',
              durationSeconds: 60,
              language: 'en',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container: container,
          child: const TranscriptPanel(mediaId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Transcript unavailable'), findsOneWidget);
    });

    testWidgets(
      'renders the inline error UI when fetch state reports error and lines empty',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            transcriptLinesForMediaProvider(
              'm1',
            ).overrideWith((ref) => Stream.value(<TranscriptLine>[])),
            transcriptFetchStatusProvider('m1').overrideWith(
              (ref) => const TranscriptFetchUiState(
                status: TranscriptFetchStatus.error,
                errorMessage: 'failed',
              ),
            ),
            videoRowForMediaProvider('m1').overrideWith(
              (ref) async => VideoRow(
                createdAt: _epoch,
                updatedAt: _epoch,
                id: 'm1',
                vid: 'v1',
                provider: 'local',
                title: 'T',
                durationSeconds: 60,
                language: 'en',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _wrap(
            container: container,
            child: const TranscriptPanel(mediaId: 'm1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text('Transcript unavailable'), findsOneWidget);
        expect(find.text('Retry'), findsOneWidget);
      },
    );

    testWidgets(
      'renders the loading spinner when fetch state is loading and lines empty',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            transcriptLinesForMediaProvider(
              'm1',
            ).overrideWith((ref) => Stream.value(<TranscriptLine>[])),
            transcriptFetchStatusProvider('m1').overrideWith(
              (ref) => const TranscriptFetchUiState(
                status: TranscriptFetchStatus.loading,
              ),
            ),
            videoRowForMediaProvider('m1').overrideWith(
              (ref) async => VideoRow(
                createdAt: _epoch,
                updatedAt: _epoch,
                id: 'm1',
                vid: 'v1',
                provider: 'local',
                title: 'T',
                durationSeconds: 60,
                language: 'en',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _wrap(
            container: container,
            child: const TranscriptPanel(mediaId: 'm1'),
          ),
        );
        // CircularProgressIndicator has an infinite animation; pumpAndSettle
        // will hang forever. Use a few manual pumps instead.
        for (var i = 0; i < 4; i++) {
          await tester.pump(const Duration(milliseconds: 50));
        }

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text('Fetching subtitles…'), findsOneWidget);
      },
    );

    testWidgets(
      'renders TranscriptEmptyState for local media with empty lines + idle fetch',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            appDatabaseProvider.overrideWithValue(db),
            authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
            transcriptLinesForMediaProvider(
              'm1',
            ).overrideWith((ref) => Stream.value(<TranscriptLine>[])),
            transcriptFetchStatusProvider('m1').overrideWith(
              (ref) => const TranscriptFetchUiState(
                status: TranscriptFetchStatus.idle,
              ),
            ),
            videoRowForMediaProvider('m1').overrideWith(
              (ref) async => VideoRow(
                createdAt: _epoch,
                updatedAt: _epoch,
                id: 'm1',
                vid: 'v1',
                provider: 'local',
                title: 'T',
                durationSeconds: 60,
                language: 'en',
              ),
            ),
          ],
        );
        addTearDown(container.dispose);
        await tester.pumpWidget(
          _wrap(
            container: container,
            child: const TranscriptPanel(mediaId: 'm1'),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(TranscriptEmptyState), findsOneWidget);

        // Local media shows the local-actions hint and not the remote hint.
        expect(
          find.text(
            'Add a subtitle file, extract embedded captions, or create an AI transcript.',
          ),
          findsOneWidget,
        );

        // Add subtitle / AI transcript buttons are visible.
        expect(find.text('Add subtitle'), findsOneWidget);
        expect(find.text('AI transcript'), findsOneWidget);
      },
    );

    testWidgets('hides local actions and uses remote hint for YouTube media', (
      tester,
    ) async {
      final container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          authCtrlProvider.overrideWith(_SignedInAuthCtrl.new),
          transcriptLinesForMediaProvider(
            'm1',
          ).overrideWith((ref) => Stream.value(<TranscriptLine>[])),
          transcriptFetchStatusProvider('m1').overrideWith(
            (ref) => const TranscriptFetchUiState(
              status: TranscriptFetchStatus.idle,
            ),
          ),
          videoRowForMediaProvider('m1').overrideWith(
            (ref) async => VideoRow(
              createdAt: _epoch,
              updatedAt: _epoch,
              id: 'm1',
              vid: 'v1',
              provider: 'youtube',
              title: 'T',
              durationSeconds: 60,
              language: 'en',
            ),
          ),
        ],
      );
      addTearDown(container.dispose);
      await tester.pumpWidget(
        _wrap(
          container: container,
          child: const TranscriptPanel(mediaId: 'm1'),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.byType(TranscriptEmptyState), findsOneWidget);

      // No local buttons for YouTube.
      expect(find.text('Add subtitle'), findsNothing);
      expect(find.text('AI transcript'), findsNothing);

      // Remote hint is visible.
      expect(
        find.text(
          'Cloud captions load automatically when available. Open the CC menu to refresh.',
        ),
        findsOneWidget,
      );
    });
  });
}
