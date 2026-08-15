import 'dart:convert';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/db/app_database_provider.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/transcript/application/transcript_lines_provider.dart';
import 'package:enjoy_player/features/transcript/data/client_profile.dart';
import 'package:enjoy_player/features/transcript/data/youtube_profiles_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

const _mediaId = 'media-dedupe';
const _activeTranscriptId = 'tr-active';
const _inactiveTranscriptId = 'tr-inactive';

String _timeline(List<TranscriptLine> lines) =>
    jsonEncode(lines.map((e) => e.toJson()).toList());

List<TranscriptLine> _activeLines() => const [
  TranscriptLine(text: 'hello', startMs: 0, durationMs: 500),
  TranscriptLine(text: 'world', startMs: 500, durationMs: 500),
];

EchoSessionRow _echoSession({
  required String transcriptId,
  int recordingsCount = 0,
  DateTime? lastActiveAt,
}) {
  final now = DateTime.utc(2026, 6, 28);
  return EchoSessionRow(
    id: 'echo-1',
    targetType: 'Audio',
    targetId: _mediaId,
    language: 'und',
    currentTimeMs: 0,
    playbackRate: 1,
    volume: 1,
    echoStartMs: null,
    echoEndMs: null,
    transcriptId: transcriptId,
    secondaryTranscriptId: null,
    recordingsCount: recordingsCount,
    recordingsDurationMs: 0,
    lastRecordingAt: null,
    currentSegmentIndex: -1,
    echoActive: false,
    echoStartLine: -1,
    echoEndLine: -1,
    blurActive: false,
    startedAt: now,
    lastActiveAt: lastActiveAt ?? now,
    completedAt: null,
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

TranscriptRow _transcript({
  required String id,
  required List<TranscriptLine> lines,
  DateTime? updatedAt,
}) {
  final now = updatedAt ?? DateTime.utc(2026, 6, 28);
  return TranscriptRow(
    id: id,
    targetType: 'Audio',
    targetId: _mediaId,
    language: 'en',
    source: 'user',
    timelineJson: _timeline(lines),
    referenceId: null,
    label: id,
    trackIndex: null,
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

AudioRow _audio() {
  final now = DateTime.utc(2026, 6, 28);
  return AudioRow(
    id: _mediaId,
    aid: 'f',
    provider: 'user',
    title: 't',
    description: null,
    thumbnailUrl: null,
    durationSeconds: 0,
    language: 'und',
    translationKey: null,
    sourceText: null,
    voice: null,
    source: null,
    localUri: 'file:///a.mp3',
    md5: null,
    size: 1,
    mediaUrl: null,
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('TranscriptLine value equality', () {
    test('two lines with identical fields are ==', () {
      const a = TranscriptLine(text: 'hi', startMs: 0, durationMs: 100);
      const b = TranscriptLine(text: 'hi', startMs: 0, durationMs: 100);
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });

    test('changing any field breaks ==', () {
      const base = TranscriptLine(text: 'hi', startMs: 0, durationMs: 100);
      const txt = TranscriptLine(text: 'bye', startMs: 0, durationMs: 100);
      const start = TranscriptLine(text: 'hi', startMs: 1, durationMs: 100);
      const dur = TranscriptLine(text: 'hi', startMs: 0, durationMs: 101);
      expect(base, isNot(equals(txt)));
      expect(base, isNot(equals(start)));
      expect(base, isNot(equals(dur)));
    });

    test('identical line fields with different timeline words are not ==', () {
      const a = TranscriptLine(
        text: 'hi',
        startMs: 0,
        durationMs: 100,
        timeline: [TranscriptWord(text: 'hi')],
      );
      const b = TranscriptLine(
        text: 'hi',
        startMs: 0,
        durationMs: 100,
        timeline: [TranscriptWord(text: 'HI')],
      );
      expect(a, isNot(equals(b)));
    });
  });

  group('transcriptLinesForMediaProvider dedupe', () {
    late AppDatabase db;
    late ProviderContainer container;
    late ProviderSubscription<AsyncValue<List<TranscriptLine>>> sub;
    final emissions = <List<TranscriptLine>>[];

    Future<void> setupContainer() async {
      container = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          youtubeProfilesProvider.overrideWith(
            (ref) async => kBuiltInClientProfiles,
          ),
        ],
      );
      addTearDown(container.dispose);

      emissions.clear();
      sub = container.listen(transcriptLinesForMediaProvider(_mediaId), (
        _,
        next,
      ) {
        if (next.hasValue) emissions.add(next.requireValue);
      }, fireImmediately: true);
      addTearDown(sub.close);

      // Wait for the initial (post-setup) emission to land.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      // Drain the seeded-state emissions so the post-seed count is 0.
      final initial = emissions.length;
      emissions.clear();
      // Sanity: at least one emission must have happened before draining.
      expect(initial, greaterThanOrEqualTo(1));
    }

    setUp(() async {
      db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await db.audioDao.insertRow(_audio());
      await db.transcriptDao.upsert(
        _transcript(id: _activeTranscriptId, lines: _activeLines()),
      );
      await db.transcriptDao.upsert(
        _transcript(
          id: _inactiveTranscriptId,
          lines: const [
            TranscriptLine(text: 'unused', startMs: 0, durationMs: 1),
          ],
        ),
      );
      await db.echoSessionDao.upsert(
        _echoSession(transcriptId: _activeTranscriptId),
      );
    });

    test(
      'skips identical emissions when echo session bumps only counts',
      () async {
        await setupContainer();
        // Bump recordingsCount — Drift re-emits the echo session row.
        await (db.update(
          db.echoSessions,
        )..where((s) => s.id.equals('echo-1'))).write(
          EchoSessionsCompanion(
            recordingsCount: const Value(7),
            updatedAt: Value(DateTime.utc(2026, 6, 28, 12)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          emissions,
          isEmpty,
          reason:
              'Echo session count bump is a no-op for lines. '
              'Got $emissions',
        );
      },
    );

    test(
      'skips identical emissions when in-active transcript row changes',
      () async {
        await setupContainer();
        // Touch the in-active transcript's updatedAt — Drift re-emits the
        // watchAllForTarget stream.
        await (db.update(
          db.transcripts,
        )..where((t) => t.id.equals(_inactiveTranscriptId))).write(
          TranscriptsCompanion(updatedAt: Value(DateTime.utc(2026, 6, 28, 13))),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(
          emissions,
          isEmpty,
          reason:
              'In-active transcript row change is a no-op for the active '
              'lines. Got $emissions',
        );
      },
    );

    test('re-emits when the active transcript row is replaced', () async {
      await setupContainer();
      // Replace the active transcript's timeline — real change.
      await db.transcriptDao.upsert(
        _transcript(
          id: _activeTranscriptId,
          lines: const [
            TranscriptLine(text: 'goodbye', startMs: 0, durationMs: 500),
          ],
          updatedAt: DateTime.utc(2026, 6, 28, 14),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(emissions, isNotEmpty);
      expect(emissions.last.single.text, 'goodbye');
    });

    test(
      're-emits when the active transcript id changes via echo session',
      () async {
        await setupContainer();
        // Reassign the echo session to point at the in-active transcript id.
        await (db.update(
          db.echoSessions,
        )..where((s) => s.id.equals('echo-1'))).write(
          EchoSessionsCompanion(
            transcriptId: const Value(_inactiveTranscriptId),
            updatedAt: Value(DateTime.utc(2026, 6, 28, 15)),
          ),
        );
        await Future<void>.delayed(const Duration(milliseconds: 50));
        expect(emissions, isNotEmpty);
        expect(emissions.last.single.text, 'unused');
      },
    );
  });

  group('_computeLines uses getById (not listForTarget)', () {
    // Pins the contract: _computeLines must look up the active row by id,
    // not scan the full list and pick the first row by ordering. We seed
    // the in-active transcript with a timestamp LATER than the active
    // one — a listForTarget-with-wrong-pick would surface 'unused'
    // instead of the active lines.
    test('lines come from getById(activeId), not listForTarget()', () async {
      final db = AppDatabase(executor: NativeDatabase.memory());
      addTearDown(db.close);
      await db.audioDao.insertRow(_audio());
      await db.transcriptDao.upsert(
        _transcript(id: _activeTranscriptId, lines: _activeLines()),
      );
      // Insert the in-active row AFTER the active one — if _computeLines
      // scanned with listForTarget and ordered by source/language/createdAt
      // (createdAt ascending puts the in-active row first), picking the
      // first row instead of the active one would surface 'unused'.
      await db.transcriptDao.upsert(
        _transcript(
          id: _inactiveTranscriptId,
          lines: const [
            TranscriptLine(text: 'unused', startMs: 0, durationMs: 1),
          ],
          updatedAt: DateTime.utc(2026, 6, 28, 11),
        ),
      );
      await db.echoSessionDao.upsert(
        _echoSession(transcriptId: _activeTranscriptId),
      );

      final c = ProviderContainer(
        overrides: [
          appDatabaseProvider.overrideWithValue(db),
          youtubeProfilesProvider.overrideWith(
            (ref) async => kBuiltInClientProfiles,
          ),
        ],
      );
      addTearDown(c.dispose);

      final emissions = <List<TranscriptLine>>[];
      final sub = c.listen(transcriptLinesForMediaProvider(_mediaId), (
        _,
        next,
      ) {
        if (next.hasValue) emissions.add(next.requireValue);
      }, fireImmediately: true);
      addTearDown(sub.close);

      // Wait for at least one emission to land.
      final deadline = DateTime.now().add(const Duration(seconds: 2));
      while (emissions.isEmpty && DateTime.now().isBefore(deadline)) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(
        emissions,
        isNotEmpty,
        reason: 'Provider should emit at least once within 2s',
      );
      expect(emissions.last.map((l) => l.text).toList(), ['hello', 'world']);
    });
  });
}
