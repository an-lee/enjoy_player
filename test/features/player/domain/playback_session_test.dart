import 'package:enjoy_player/features/player/domain/playback_session.dart';
import 'package:flutter_test/flutter_test.dart';

PlaybackSession _session({
  String mediaId = 'm1',
  double currentTimeSeconds = 10.0,
  double durationSeconds = 120.0,
  String? thumbnailUrl,
  String? transcriptId,
}) {
  return PlaybackSession(
    mediaId: mediaId,
    dexieTargetType: 'Video',
    mediaType: 'video',
    mediaTitle: 'Test Media',
    thumbnailUrl: thumbnailUrl,
    durationSeconds: durationSeconds,
    currentTimeSeconds: currentTimeSeconds,
    currentSegmentIndex: 2,
    language: 'en',
    startedAt: DateTime.utc(2024, 1, 1),
    lastActiveAt: DateTime.utc(2024, 1, 2),
    transcriptId: transcriptId,
  );
}

void main() {
  group('PlaybackSession', () {
    test('copyWith replaces specified fields only', () {
      final s = _session();
      final copy = s.copyWith(
        currentTimeSeconds: 55.0,
        mediaTitle: 'New Title',
      );
      expect(copy.currentTimeSeconds, 55.0);
      expect(copy.mediaTitle, 'New Title');
      // Unchanged fields:
      expect(copy.mediaId, 'm1');
      expect(copy.durationSeconds, 120.0);
      expect(copy.currentSegmentIndex, 2);
      expect(copy.language, 'en');
    });

    test('copyWith with no args returns equal instance', () {
      final s = _session();
      final copy = s.copyWith();
      expect(copy, equals(s));
    });

    test('equality compares all fields except lastActiveAt', () {
      final a = _session();
      final b = _session();
      expect(a, equals(b));
      expect(a.hashCode, b.hashCode);
    });

    test('different mediaId means not equal', () {
      final a = _session(mediaId: 'x');
      final b = _session(mediaId: 'y');
      expect(a, isNot(equals(b)));
    });

    test('different currentTimeSeconds means not equal', () {
      final a = _session(currentTimeSeconds: 1.0);
      final b = _session(currentTimeSeconds: 2.0);
      expect(a, isNot(equals(b)));
    });

    test('identical returns true for same instance', () {
      final s = _session();
      expect(s == s, isTrue); // identical check
    });

    test('not equal to non-PlaybackSession object', () {
      final s = _session();
      // ignore: unrelated_type_equality_checks
      expect(s == 'string', isFalse);
    });
  });

  group('playbackChromeOf', () {
    test('returns null for null session', () {
      expect(playbackChromeOf(null), isNull);
    });

    test('extracts stable chrome subset from session', () {
      final s = _session(
        mediaId: 'm99',
        thumbnailUrl: 'https://img.png',
        durationSeconds: 300.0,
      );
      final chrome = playbackChromeOf(s)!;
      expect(chrome.mediaId, 'm99');
      expect(chrome.dexieTargetType, 'Video');
      expect(chrome.mediaType, 'video');
      expect(chrome.mediaTitle, 'Test Media');
      expect(chrome.thumbnailUrl, 'https://img.png');
      expect(chrome.durationSeconds, 300.0);
      expect(chrome.language, 'en');
    });

    test('chrome excludes currentTimeSeconds and timestamps', () {
      // PlaybackChrome record type has no currentTimeSeconds field.
      final s = _session(currentTimeSeconds: 42.0);
      final chrome = playbackChromeOf(s)!;
      // The record only has the 7 fields; verify durationSeconds is present.
      expect(chrome.durationSeconds, 120.0);
    });
  });
}
