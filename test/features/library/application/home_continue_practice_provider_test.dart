import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/library/application/home_continue_practice_provider.dart';
import 'package:enjoy_player/features/library/domain/media.dart';
import 'package:enjoy_player/features/library/domain/practice_resume.dart';
import 'package:flutter_test/flutter_test.dart';

Media _media({
  required String id,
  String title = 'Talk',
  int durationMs = 120000,
  DateTime? updatedAt,
}) {
  final ts = updatedAt ?? DateTime.utc(2026, 1, 1);
  return Media(
    id: id,
    kind: MediaKind.video,
    title: title,
    sourceUri: 'file:///$id',
    durationMs: durationMs,
    language: 'en-US',
    contentHash: id,
    fileSize: 1,
    createdAt: ts,
    updatedAt: ts,
  );
}

EchoSessionRow _session({
  required String id,
  required String targetId,
  int currentTimeMs = 30000,
  bool echoActive = false,
  DateTime? lastActiveAt,
}) {
  final ts = lastActiveAt ?? DateTime.utc(2026, 6, 1);
  return EchoSessionRow(
    id: id,
    targetType: 'Video',
    targetId: targetId,
    language: 'en',
    currentTimeMs: currentTimeMs,
    playbackRate: 1,
    volume: 1,
    echoStartMs: null,
    echoEndMs: null,
    transcriptId: null,
    secondaryTranscriptId: null,
    recordingsCount: 0,
    recordingsDurationMs: 0,
    lastRecordingAt: null,
    currentSegmentIndex: -1,
    echoActive: echoActive,
    echoStartLine: -1,
    echoEndLine: -1,
    blurActive: false,
    startedAt: ts,
    lastActiveAt: ts,
    completedAt: null,
    syncStatus: null,
    serverUpdatedAt: null,
    createdAt: ts,
    updatedAt: ts,
  );
}

void main() {
  group('resolvePracticeResume', () {
    test('returns null when there are no sessions', () {
      expect(
        resolvePracticeResume(
          sessions: const [],
          lookupMedia: (_) => _media(id: 'x'),
        ),
        isNull,
      );
    });

    test('follows last session, not recents updatedAt', () {
      final practiced = _media(id: 'a', updatedAt: DateTime.utc(2020, 1, 1));
      final newerLibrary = _media(id: 'b', updatedAt: DateTime.utc(2026, 1, 1));
      final byId = {'a': practiced, 'b': newerLibrary};
      final resume = resolvePracticeResume(
        sessions: [
          _session(
            id: 's-a',
            targetId: 'a',
            lastActiveAt: DateTime.utc(2026, 8, 1),
          ),
          _session(
            id: 's-b',
            targetId: 'b',
            lastActiveAt: DateTime.utc(2025, 1, 1),
          ),
        ],
        lookupMedia: (id) => byId[id],
      );
      expect(resume?.media.id, 'a');
    });

    test('omits progress when duration is 0', () {
      final resume = resolvePracticeResume(
        sessions: [_session(id: 's', targetId: 'a', currentTimeMs: 5000)],
        lookupMedia: (_) => _media(id: 'a', durationMs: 0),
      );
      expect(resume, isNotNull);
      expect(resume!.progress, isNull);
    });

    test('maps echo_active onto PracticeResume', () {
      final resume = resolvePracticeResume(
        sessions: [_session(id: 's', targetId: 'a', echoActive: true)],
        lookupMedia: (_) => _media(id: 'a'),
      );
      expect(resume?.echoActive, isTrue);
    });

    test('skips missing media and uses the next valid session', () {
      final resume = resolvePracticeResume(
        sessions: [
          _session(id: 'gone', targetId: 'missing'),
          _session(id: 'ok', targetId: 'a'),
        ],
        lookupMedia: (id) => id == 'a' ? _media(id: 'a') : null,
      );
      expect(resume?.sessionId, 'ok');
      expect(resume?.media.id, 'a');
    });

    test('returns null when every session target is missing', () {
      expect(
        resolvePracticeResume(
          sessions: [_session(id: 'gone', targetId: 'missing')],
          lookupMedia: (_) => null,
        ),
        isNull,
      );
    });

    test('recents populated without sessions stays null', () {
      expect(
        resolvePracticeResume(
          sessions: const [],
          lookupMedia: (_) => _media(id: 'recent'),
        ),
        isNull,
      );
    });

    test('bumping another item updatedAt does not steal Continue', () {
      final a = _media(id: 'a', updatedAt: DateTime.utc(2020, 1, 1));
      var b = _media(id: 'b', updatedAt: DateTime.utc(2021, 1, 1));
      final sessions = [
        _session(
          id: 's-a',
          targetId: 'a',
          lastActiveAt: DateTime.utc(2026, 1, 1),
        ),
      ];
      expect(
        resolvePracticeResume(
          sessions: sessions,
          lookupMedia: (id) => id == 'a' ? a : b,
        )?.media.id,
        'a',
      );
      b = _media(id: 'b', updatedAt: DateTime.utc(2026, 8, 1));
      expect(
        resolvePracticeResume(
          sessions: sessions,
          lookupMedia: (id) => id == 'a' ? a : b,
        )?.media.id,
        'a',
      );
    });
  });

  group('PracticeResume equality', () {
    test('ignores Media.updatedAt', () {
      final first = PracticeResume(
        media: _media(id: 'a', updatedAt: DateTime.utc(2020, 1, 1)),
        positionMs: 10,
        echoActive: false,
        lastActiveAt: DateTime.utc(2026, 1, 1),
        sessionId: 's',
      );
      final second = PracticeResume(
        media: _media(id: 'a', updatedAt: DateTime.utc(2026, 8, 1)),
        positionMs: 10,
        echoActive: false,
        lastActiveAt: DateTime.utc(2026, 8, 2),
        sessionId: 's',
      );
      expect(first, equals(second));
    });
  });
}
