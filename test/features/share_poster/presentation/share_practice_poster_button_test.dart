import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/db/dexie_target_type_provider.dart';
import 'package:enjoy_player/features/share_poster/presentation/share_practice_poster_button.dart';
import 'package:enjoy_player/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<Widget> _wrap({
  required ProviderContainer container,
  required Widget child,
}) async {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      localizationsDelegates: const [
        AppLocalizations.delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: AppLocalizations.supportedLocales,
      locale: const Locale('en'),
      home: Scaffold(body: child),
    ),
  );
}

Future<void> seedVideo(AppDatabase db, String id) async {
  final now = DateTime.now();
  await db.videoDao.insertRow(
    VideoRow(
      id: id,
      vid: 'vid_$id',
      provider: 'youtube',
      title: 'T $id',
      description: null,
      thumbnailUrl: null,
      durationSeconds: 60,
      language: 'en',
      source: null,
      localUri: null,
      md5: null,
      size: null,
      mediaUrl: 'https://example.com/${id}_video.mp4',
      createdAt: now,
      updatedAt: now,
    ),
  );
}

Future<void> seedRecording(
  AppDatabase db,
  String id,
  String targetType,
  String targetId,
) async {
  await db.recordingDao.insertRow(
    RecordingRow(
      id: id,
      targetType: targetType,
      targetId: targetId,
      referenceStart: 0,
      referenceDuration: 5000,
      referenceText: 'ref',
      language: 'en',
      duration: 4000,
      md5: null,
      audioUrl: null,
      pronunciationScore: null,
      assessmentJson: null,
      localPath: null,
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late ProviderContainer container;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
    container = ProviderContainer(
      overrides: [appDatabaseProvider.overrideWithValue(db)],
    );
  });

  tearDown(() async {
    container.dispose();
    await db.close();
  });

  testWidgets('renders SizedBox when mediaId has no Dexie target', (
    tester,
  ) async {
    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(mediaId: 'unknown-id'),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byType(SharePracticePosterButton), findsOneWidget);
    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('renders nothing when target type known but no recordings', (
    tester,
  ) async {
    await seedVideo(db, 'video-1');
    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(mediaId: 'video-1'),
      ),
    );
    // Allow the FutureProvider to settle.
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(IconButton), findsNothing);
  });

  testWidgets('renders IconButton when recordings exist', (tester) async {
    await seedVideo(db, 'video-2');
    await seedRecording(db, 'rec-1', 'Video', 'video-2');

    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(mediaId: 'video-2'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets('renders IconButton with custom iconColor override', (
    tester,
  ) async {
    await seedVideo(db, 'video-3');
    await seedRecording(db, 'rec-2', 'Video', 'video-3');

    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(
          mediaId: 'video-3',
          iconColor: Colors.red,
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(of: find.byType(IconButton), matching: find.byType(Icon)),
    );
    expect(icon.color, Colors.red);
    expect(icon.size, 20);
    expect(icon.icon, equals(Icons.ios_share_rounded));
  });

  testWidgets('default iconColor is white when none is provided', (
    tester,
  ) async {
    await seedVideo(db, 'video-4');
    await seedRecording(db, 'rec-3', 'Video', 'video-4');

    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(mediaId: 'video-4'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final icon = tester.widget<Icon>(
      find.descendant(of: find.byType(IconButton), matching: find.byType(Icon)),
    );
    expect(icon.color, Colors.white);
  });

  testWidgets('iconButton has a non-empty tooltip', (tester) async {
    await seedVideo(db, 'video-5');
    await seedRecording(db, 'rec-4', 'Video', 'video-5');

    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(mediaId: 'video-5'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final iconButton = tester.widget<IconButton>(find.byType(IconButton));
    expect(iconButton.onPressed, isNotNull);
    expect(iconButton.tooltip, isA<String>());
    expect(iconButton.tooltip!.isNotEmpty, isTrue);
  });

  testWidgets('wrapped in Material with translucent black color', (
    tester,
  ) async {
    await seedVideo(db, 'video-6');
    await seedRecording(db, 'rec-5', 'Video', 'video-6');

    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(mediaId: 'video-6'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();

    final material = tester.widget<Material>(
      find
          .ancestor(
            of: find.byType(IconButton),
            matching: find.byType(Material),
          )
          .first,
    );
    expect(material.color, isNotNull);
    expect(material.borderRadius, isNotNull);
    expect(material.clipBehavior, Clip.antiAlias);
  });

  testWidgets('rebuilds with new mediaId after recordings added later', (
    tester,
  ) async {
    await seedVideo(db, 'video-7');
    // No recordings yet.
    await tester.pumpWidget(
      await _wrap(
        container: container,
        child: const SharePracticePosterButton(mediaId: 'video-7'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsNothing);

    // Add recordings after first render.
    await seedRecording(db, 'rec-6', 'Video', 'video-7');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 50));
    await tester.pumpAndSettle();
    expect(find.byType(IconButton), findsOneWidget);
  });

  testWidgets(
    'different mediaIds resolve independently (per-family StreamProvider)',
    (tester) async {
      await seedVideo(db, 'video-8');
      await seedVideo(db, 'video-9');
      await seedRecording(db, 'rec-7', 'Video', 'video-8');

      await tester.pumpWidget(
        await _wrap(
          container: container,
          child: Column(
            children: const [
              SharePracticePosterButton(mediaId: 'video-8'),
              SharePracticePosterButton(mediaId: 'video-9'),
            ],
          ),
        ),
      );
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      await tester.pumpAndSettle();

      expect(find.byType(IconButton), findsOneWidget);
    },
  );

  test(
    'dexieTargetTypeForMediaProvider resolves missing ids to null',
    () async {
      final result = await container.read(
        dexieTargetTypeForMediaProvider('absent').future,
      );
      expect(result, isNull);
    },
  );
}
