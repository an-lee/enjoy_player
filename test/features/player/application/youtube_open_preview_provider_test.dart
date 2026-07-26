import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/player/application/youtube_open_preview_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('youtubeOpenPreviewProvider', () {
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

    Future<void> seedVideo({
      required String id,
      required String vid,
      String provider = 'youtube',
      String? thumbnailUrl,
      String? mediaUrl,
    }) async {
      await db.videoDao.insertRow(
        VideoRow(
          id: id,
          vid: vid,
          provider: provider,
          title: 'Title $id',
          thumbnailUrl: thumbnailUrl,
          mediaUrl: mediaUrl,
          durationSeconds: 120,
          language: 'en',
          createdAt: DateTime(2026, 1, 1),
          updatedAt: DateTime(2026, 1, 1),
        ),
      );
    }

    test('returns null when row does not exist', () async {
      final result = await container.read(
        youtubeOpenPreviewProvider('missing').future,
      );
      expect(result, isNull);
    });

    test('returns null for non-YouTube providers', () async {
      await seedVideo(id: 'a1', vid: 'vid_a1', provider: 'user');
      final result = await container.read(
        youtubeOpenPreviewProvider('a1').future,
      );
      expect(result, isNull);
    });

    test('returns null for mixed-case provider that is not YouTube', () async {
      await seedVideo(id: 'b1', vid: 'vid_b1', provider: 'Bilibili');
      final result = await container.read(
        youtubeOpenPreviewProvider('b1').future,
      );
      expect(result, isNull);
    });

    test(
      'uses bare YouTube vid when it parses as a valid 11-char id',
      () async {
        // Rick Astley's id — exactly 11 chars, parses as bare id.
        await seedVideo(id: 'v1', vid: 'dQw4w9WgXcQ');
        final result = await container.read(
          youtubeOpenPreviewProvider('v1').future,
        );
        expect(result, isNotNull);
        expect(result!.videoId, 'dQw4w9WgXcQ');
        expect(
          result.thumbnailUrl,
          'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        );
      },
    );

    test(
      'falls through to thumbnail URL when vid is not a valid YouTube id',
      () async {
        await seedVideo(
          id: 'v2',
          vid: 'unused',
          thumbnailUrl: 'https://i.ytimg.com/vi/dQw4w9WgXcQ/default.jpg',
        );
        final result = await container.read(
          youtubeOpenPreviewProvider('v2').future,
        );
        expect(result!.videoId, 'unused');
        // The CDN URL supplies the real video id, so the maxres URL matches that.
        expect(
          result.thumbnailUrl,
          'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        );
      },
    );

    test(
      'falls through to mediaUrl youtu.be when vid+thumb are unusable',
      () async {
        await seedVideo(
          id: 'v3',
          vid: 'unused',
          mediaUrl: 'https://youtu.be/dQw4w9WgXcQ',
        );
        final result = await container.read(
          youtubeOpenPreviewProvider('v3').future,
        );
        expect(result!.videoId, 'unused');
        expect(
          result.thumbnailUrl,
          'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
        );
      },
    );

    test(
      'returns null thumbnailUrl when nothing parses as a YouTube id',
      () async {
        await seedVideo(
          id: 'v4',
          vid: 'unused',
          mediaUrl: 'https://example.com/asset',
        );
        final result = await container.read(
          youtubeOpenPreviewProvider('v4').future,
        );
        expect(result!.videoId, 'unused');
        expect(result.thumbnailUrl, isNull);
      },
    );

    test('accepts "YouTube" provider (case-insensitive)', () async {
      await seedVideo(id: 'v5', vid: 'dQw4w9WgXcQ', provider: 'YouTube');
      final result = await container.read(
        youtubeOpenPreviewProvider('v5').future,
      );
      expect(result, isNotNull);
      expect(
        result!.thumbnailUrl,
        'https://i.ytimg.com/vi/dQw4w9WgXcQ/maxresdefault.jpg',
      );
    });

    test(
      'different mediaIds resolve independently (autoDispose family)',
      () async {
        await seedVideo(id: 'v6', vid: 'dQw4w9WgXcQ');
        await seedVideo(id: 'v7', vid: 'oHg5SJYRHA0');
        final a = await container.read(youtubeOpenPreviewProvider('v6').future);
        final b = await container.read(youtubeOpenPreviewProvider('v7').future);
        expect(a!.videoId, 'dQw4w9WgXcQ');
        expect(b!.videoId, 'oHg5SJYRHA0');
        expect(a.thumbnailUrl, isNot(b.thumbnailUrl));
      },
    );
  });
}
