import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/player/application/player_position_tracker.dart';
import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:logging/logging.dart';

import '../../../support/fake_player_engine.dart';

/// Video DAO that always fails to insert — a Drift write blowing up mid-play.
class _ThrowingVideoDao extends VideoDao {
  _ThrowingVideoDao(super.db);

  int insertCalls = 0;

  @override
  Future<void> insertRow(VideoRow row) async {
    insertCalls++;
    throw StateError('disk I/O error');
  }
}

/// Database whose [videoDao] throws, so the tracker hits a real failing write
/// instead of a mock seam.
class _ThrowingVideoDatabase extends AppDatabase {
  _ThrowingVideoDatabase() : super(executor: NativeDatabase.memory());

  late final _ThrowingVideoDao throwingVideoDao = _ThrowingVideoDao(
    this as AppDatabase,
  );

  @override
  VideoDao get videoDao => throwingVideoDao;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('PlayerPositionTracker duration listener', () {
    late _ThrowingVideoDatabase db;
    late FakePlayerEngine fake;
    late ProviderContainer container;
    late PlaybackSession? session;

    setUp(() {
      db = _ThrowingVideoDatabase();
      fake = FakePlayerEngine();
      session = PlaybackSession(
        mediaId: 'v1',
        dexieTargetType: 'Video',
        mediaType: 'video',
        mediaTitle: 't',
        durationSeconds: 0,
        currentTimeSeconds: 0,
        currentSegmentIndex: -1,
        language: 'en',
        startedAt: DateTime.utc(2026, 8, 30),
        lastActiveAt: DateTime.utc(2026, 8, 30),
      );
      container = ProviderContainer(
        overrides: [appDatabaseProvider.overrideWithValue(db)],
      );
      addTearDown(container.dispose);
    });

    Ref refOf() {
      late Ref captured;
      container.read(
        Provider<int>((ref) {
          captured = ref;
          return 0;
        }),
      );
      return captured;
    }

    PlayerPositionTracker tracker() => PlayerPositionTracker(
      ref: refOf(),
      getEngine: () => fake,
      getSession: () => session,
      setSession: (next) => session = next,
      currentOpenGeneration: () => 0,
    );

    VideoRow videoRow() {
      final now = DateTime.utc(2026, 8, 30);
      return VideoRow(
        id: 'v1',
        vid: 'v1',
        provider: 'user',
        title: 't',
        description: null,
        thumbnailUrl: null,
        durationSeconds: 0,
        language: 'en',
        source: null,
        localUri: null,
        md5: null,
        size: null,
        mediaUrl: null,
        createdAt: now,
        updatedAt: now,
      );
    }

    test('a failing duration backfill logs and playback continues', () async {
      final records = <LogRecord>[];
      final sub = Logger('PlayerPositionTracker').onRecord.listen(records.add);
      addTearDown(sub.cancel);

      final t = tracker();
      t.subscribe(
        openGeneration: 0,
        mediaId: 'v1',
        dexieTargetType: 'Video',
        kind: MediaKind.video,
        video: videoRow(),
        audio: null,
      );

      // An escaping Drift throw would surface as an unhandled async exception
      // and fail the test — passing is part of the assertion.
      fake.emitDuration(const Duration(seconds: 91));
      await Future<void>.delayed(Duration.zero);

      expect(db.throwingVideoDao.insertCalls, 1);
      // The session was already updated before the write threw.
      expect(session?.durationSeconds, 91);

      // Later events still flow (and still try the write).
      fake.emitDuration(const Duration(seconds: 92));
      await Future<void>.delayed(Duration.zero);

      expect(db.throwingVideoDao.insertCalls, 2);
      expect(session?.durationSeconds, 92);
      expect(records.where((r) => r.level >= Level.WARNING), isNotEmpty);
    });
  });
}
