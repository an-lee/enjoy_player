import 'package:drift/drift.dart' show Variable;
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('migration 16 — hot-read-path indexes', () {
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

    test('all covering indexes exist after fresh create', () async {
      final indexes = await db
          .customSelect(
            "SELECT name FROM sqlite_master WHERE type = 'index' "
            "AND name LIKE 'idx_%' ORDER BY name",
          )
          .get();
      final names = indexes.map((r) => r.read<String>('name')).toSet();

      // Migration 16 indexes (issue #467) — declared as @TableIndex on the
      // table classes so createAll() creates them on fresh databases, and
      // also in migration step 16 for upgrades.
      expect(
        names,
        containsAll([
          'idx_transcripts_target',
          'idx_recordings_target',
          'idx_echo_sessions_target_active',
          'idx_videos_provider_vid',
          'idx_videos_local_uri',
          'idx_audios_local_uri',
          'idx_audios_md5',
          'idx_dictations_target',
          'idx_youtube_feed_entries_channel_published',
          'idx_youtube_feed_entries_published',
          'idx_sync_queue_retry_created',
        ]),
      );
    });

    test('transcripts index is usable by EXPLAIN QUERY PLAN', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN '
            'SELECT 1 FROM transcripts WHERE target_type = ? AND target_id = ? '
            'LIMIT 1',
            variables: [
              Variable.withString('Video'),
              Variable.withString('v-1'),
            ],
          )
          .get();
      final planText = plan.map((r) => r.read<String>('detail')).join('\n');
      expect(planText, contains('idx_transcripts_target'));
    });

    test('videos local_uri index is usable by EXISTS query', () async {
      final plan = await db
          .customSelect(
            'EXPLAIN QUERY PLAN '
            'SELECT 1 FROM videos WHERE local_uri = ? LIMIT 1',
            variables: [Variable.withString('/tmp/test.mp4')],
          )
          .get();
      final planText = plan.map((r) => r.read<String>('detail')).join('\n');
      expect(planText, contains('idx_videos_local_uri'));
    });
  });
}
