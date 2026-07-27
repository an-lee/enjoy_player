/// Drift table: cached RSS feed entries (not library media until imported).
library;

import 'package:drift/drift.dart';

@TableIndex(
  name: 'idx_youtube_feed_entries_channel_published',
  columns: {#channelId, #publishedAt},
)
@TableIndex(name: 'idx_youtube_feed_entries_published', columns: {#publishedAt})
@DataClassName('YoutubeFeedEntryRow')
class YoutubeFeedEntries extends Table {
  @override
  String get tableName => 'youtube_feed_entries';

  TextColumn get videoId => text()();
  TextColumn get channelId => text()();
  TextColumn get title => text()();
  TextColumn get thumbnailUrl => text().nullable()();
  IntColumn get durationSeconds => integer().nullable()();
  DateTimeColumn get publishedAt => dateTime()();
  DateTimeColumn get fetchedAt => dateTime()();

  @override
  Set<Column<Object>> get primaryKey => {videoId, channelId};
}
