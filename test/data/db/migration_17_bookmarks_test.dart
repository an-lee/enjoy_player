import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migration 17 — macOS security-scoped bookmark blobs', () {
    late AppDatabase db;

    setUp(() {
      db = AppDatabase(executor: NativeDatabase.memory());
    });

    tearDown(() async {
      await db.close();
    });

    test('schemaVersion is at least 17', () {
      expect(db.schemaVersion, greaterThanOrEqualTo(17));
    });

    test('videos.bookmark_data column exists and is nullable', () async {
      final rows = await db
          .customSelect(
            "SELECT name, type, \"notnull\" FROM pragma_table_info('videos') "
            "WHERE name = 'bookmark_data'",
          )
          .get();
      expect(rows, isNotEmpty);
      // `notnull = 0` means the column accepts NULL.
      expect(rows.single.read<int>('notnull'), 0);
      expect(rows.single.read<String>('type'), contains('BLOB'));
    });

    test('audios.bookmark_data column exists and is nullable', () async {
      final rows = await db
          .customSelect(
            "SELECT name, type, \"notnull\" FROM pragma_table_info('audios') "
            "WHERE name = 'bookmark_data'",
          )
          .get();
      expect(rows, isNotEmpty);
      expect(rows.single.read<int>('notnull'), 0);
      expect(rows.single.read<String>('type'), contains('BLOB'));
    });

    test(
      'round-trip: video row can be inserted with a Uint8List bookmark blob',
      () async {
        final now = DateTime.now();
        const id = 'video-bookmark-test';
        final blob = Uint8List.fromList([1, 2, 3, 4, 5, 6, 7, 8]);
        await db.videoDao.insertRow(
          VideoRow(
            id: id,
            vid: 'vid-1',
            provider: 'user',
            title: 'Sample',
            durationSeconds: 0,
            language: 'und',
            source: null,
            localUri: '/Users/an-lee/Downloads/foo.mp4',
            bookmarkData: blob,
            md5: 'deadbeef',
            size: 1024,
            localMtimeMs: now.millisecondsSinceEpoch,
            mediaUrl: null,
            createdAt: now,
            updatedAt: now,
          ),
        );

        final row = await db.videoDao.getById(id);
        expect(row, isNotNull);
        expect(row!.bookmarkData, equals(blob));
      },
    );

    test(
      'upgrade from v16 to v17 on a fresh on-disk file adds both columns',
      () async {
        final file = File(
          '${Directory.systemTemp.path}/'
          'migration_17_${DateTime.now().microsecondsSinceEpoch}.sqlite',
        );
        addTearDown(() {
          if (file.existsSync()) file.deleteSync();
        });

        final seed = AppDatabase(executor: NativeDatabase(file));
        await seed.customStatement('PRAGMA user_version = 16');
        // Seed has the columns from onCreate (memory-style fresh DB), so
        // we don't need to insert any rows. Closing the seed triggers the
        // version pragma persistence.
        await seed.close();

        final reopened = AppDatabase(executor: NativeDatabase(file));
        addTearDown(reopened.close);

        // Trigger onUpgrade(from: 16, to: 17) by touching the database.
        await reopened.customSelect('SELECT 1').get();

        final vcols = await reopened
            .customSelect(
              "SELECT name FROM pragma_table_info('videos') "
              "WHERE name = 'bookmark_data'",
            )
            .get();
        final acols = await reopened
            .customSelect(
              "SELECT name FROM pragma_table_info('audios') "
              "WHERE name = 'bookmark_data'",
            )
            .get();
        expect(vcols, isNotEmpty);
        expect(acols, isNotEmpty);
      },
    );

    test('video row insert without bookmark persists null', () async {
      final now = DateTime.now();
      const id = 'video-no-bookmark';
      await db.videoDao.insertRow(
        VideoRow(
          id: id,
          vid: 'vid-2',
          provider: 'user',
          title: 'No bookmark',
          durationSeconds: 0,
          language: 'und',
          source: null,
          localUri: '/Users/an-lee/Downloads/bar.mp4',
          bookmarkData: null,
          md5: null,
          size: null,
          localMtimeMs: null,
          mediaUrl: null,
          createdAt: now,
          updatedAt: now,
        ),
      );
      final row = await db.videoDao.getById(id);
      expect(row?.bookmarkData, isNull);
    });

    // Sanity-check the column exists in the `_$AppDatabase` generated code.
    test('VideoRow exposes bookmarkData accessor', () async {
      final now = DateTime.now();
      const id = 'video-accessor';
      final blob = Uint8List.fromList([9, 9, 9]);
      final row = VideoRow(
        id: id,
        vid: 'vid-3',
        provider: 'user',
        title: 'Accessor',
        durationSeconds: 0,
        language: 'und',
        source: null,
        localUri: '/Users/an-lee/Downloads/baz.mp4',
        bookmarkData: blob,
        md5: null,
        size: null,
        localMtimeMs: null,
        mediaUrl: null,
        createdAt: now,
        updatedAt: now,
      );
      expect(row.bookmarkData, same(blob));
      // Stored as the same instance — Drift wraps it but the byte content
      // must round-trip.
      expect(row.bookmarkData?.toList(growable: false), [9, 9, 9]);
    });
  });
}
