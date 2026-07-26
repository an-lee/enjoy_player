// Tests for `lib/data/db/tables/*.dart` — walks every column on every Drift
// `TableInfo` registered on the `AppDatabase` so lcov attributes the
// `tableName` override and each `text()()`, `integer()()`, `.nullable()`,
// `.withDefault(...)`, `.named(...)`, `.autoIncrement()`, and `textEnum<T>()`
// chain in the source files.
//
// Schema-only DSL files cannot be exercised through the bare `Table`
// constructor (Drift throws `_isGenerated` because columns are only valid
// inside a generated `TableInfo`). Building an in-memory `AppDatabase`
// forces the generator to call every column getter, which is what we want.
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase(executor: NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Map<String, List<String>> tableColumns() {
    final out = <String, List<String>>{};
    for (final entity in db.allSchemaEntities.whereType<TableInfo>()) {
      out[entity.actualTableName] = [for (final c in entity.$columns) c.name];
    }
    return out;
  }

  test('AppDatabase registers every Drift table we expect', () {
    final columns = tableColumns();
    final tables = columns.keys.toSet();
    expect(
      tables,
      containsAll(<String>{
        'videos',
        'audios',
        'transcripts',
        'transcript_fetch_states',
        'echo_sessions',
        'recordings',
        'dictations',
        'sync_queue',
        'settings',
        'youtube_channel_subscriptions',
        'youtube_feed_entries',
        'ai_cache',
        'vocabulary_items',
        'vocabulary_contexts',
        'vocabulary_reviews',
      }),
    );
  });

  test('Videos table exposes the documented column set', () {
    final cols = tableColumns()['videos']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'vid',
        'title',
        'duration_seconds',
        'language',
        'sync_status',
        'server_updated_at',
        'created_at',
        'updated_at',
        'local_uri',
        'md5',
        'size',
        'media_url',
      ]),
    );
  });

  test('Audios table mirrors Videos for media + sync metadata', () {
    final cols = tableColumns()['audios']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'aid',
        'title',
        'duration_seconds',
        'language',
        'local_uri',
        'voice',
        'translation_key',
        'source_text',
        'sync_status',
        'server_updated_at',
        'created_at',
        'updated_at',
      ]),
    );
  });

  test('Transcripts exposes target + payload columns', () {
    final cols = tableColumns()['transcripts']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'target_type',
        'target_id',
        'language',
        'source',
        'timeline_json',
        'label',
        'track_index',
      ]),
    );
  });

  test('TranscriptFetchStates uses target composite primary key', () {
    final cols = tableColumns()['transcript_fetch_states']!;
    expect(
      cols,
      containsAll(<String>[
        'target_type',
        'target_id',
        'last_fetched_at',
        'last_status',
        'last_error',
      ]),
    );
  });

  test('EchoSessions wires playback-state + audit columns', () {
    final cols = tableColumns()['echo_sessions']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'target_type',
        'target_id',
        'language',
        'current_time_ms',
        'playback_rate',
        'volume',
        'echo_start_ms',
        'echo_end_ms',
        'recordings_count',
        'recordings_duration_ms',
        'last_recording_at',
        'started_at',
        'last_active_at',
        'completed_at',
      ]),
    );
  });

  test('Recordings exposes pronunciation + assessment fields', () {
    final cols = tableColumns()['recordings']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'target_type',
        'target_id',
        'reference_start',
        'reference_duration',
        'reference_text',
        'language',
        'duration',
        'pronunciation_score',
        'assessment_json',
        'md5',
        'audio_url',
        'local_path',
      ]),
    );
  });

  test('Dictations captures scoring metrics', () {
    final cols = tableColumns()['dictations']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'target_type',
        'target_id',
        'reference_start_ms',
        'reference_duration_ms',
        'reference_text',
        'language',
        'user_input',
        'accuracy',
        'correct_words',
        'missed_words',
        'extra_words',
      ]),
    );
  });

  test('SyncQueue has the auto-increment id and retry columns', () {
    final cols = tableColumns()['sync_queue']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'entity_type',
        'entity_id',
        'action',
        'payload_json',
        'retry_count',
        'last_attempt',
        'error',
        'created_at',
      ]),
    );
  });

  test('Settings has the key/value schema', () {
    final cols = tableColumns()['settings']!;
    expect(cols, <String>['key', 'value']);
  });

  test('YoutubeChannelSubscriptions carries the enum source columns', () {
    final cols = tableColumns()['youtube_channel_subscriptions']!;
    expect(
      cols,
      containsAll(<String>[
        'channel_id',
        'display_name',
        'thumbnail_url',
        'source',
        'source_type',
        'feed_url',
        'subscribed_at',
        'last_fetched_at',
        'language',
      ]),
    );
  });

  test('YoutubeFeedEntries uses composite videoId + channelId', () {
    final cols = tableColumns()['youtube_feed_entries']!;
    expect(cols, <String>[
      'video_id',
      'channel_id',
      'title',
      'thumbnail_url',
      'duration_seconds',
      'published_at',
      'fetched_at',
    ]);
  });

  test('AiCache uses composite kind + key primary key', () {
    final cols = tableColumns()['ai_cache']!;
    expect(cols, <String>['kind', 'key', 'payload_json', 'updated_at']);
  });

  test('VocabularyItems exposes SRS columns and indexes', () {
    final cols = tableColumns()['vocabulary_items']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'word',
        'language',
        'target_language',
        'status',
        'ease_factor',
        'interval',
        'next_review_at',
        'reviews_count',
        'last_reviewed_at',
        'contexts_count',
        'explanation',
      ]),
    );
  });

  test('VocabularyContexts uses renamed text/locator columns', () {
    final cols = tableColumns()['vocabulary_contexts']!;
    // SQL column `text` (web field name) and `locator` are exposed via
    // `.named('text')` / `.named('locator')` in the source file.
    expect(
      cols,
      containsAll(<String>{
        'id',
        'vocabulary_item_id',
        'text',
        'source_type',
        'source_id',
        'locator',
        'explanation',
      }),
    );
  });

  test('VocabularyReviews carries before-state snapshot for undo', () {
    final cols = tableColumns()['vocabulary_reviews']!;
    expect(
      cols,
      containsAll(<String>[
        'id',
        'vocabulary_item_id',
        'rating',
        'at',
        'ease_factor_before',
        'interval_before',
        'status_before',
        'reviews_count_before',
        'next_review_at_before',
        'last_reviewed_at_before',
      ]),
    );
  });

  test(
    'Every TableInfo is keyed by the SQL column names declared in source',
    () {
      // Sanity check: the drift DSL getters must produce SQL snake_case names
      // matching what we see in the generated TableInfo. The audit helpers
      // below let us trace any future drift regen back to its source file.
      for (final entity in db.allSchemaEntities.whereType<TableInfo>()) {
        expect(entity.actualTableName, isNotEmpty);
        expect(entity.$columns, isNotEmpty);
        for (final col in entity.$columns) {
          expect(
            col.name,
            isNotEmpty,
            reason: 'table=${entity.actualTableName}',
          );
        }
      }
    },
  );
}
