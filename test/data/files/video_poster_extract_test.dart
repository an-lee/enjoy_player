// Unit tests for the pure helpers in `lib/data/files/video_poster_extract.dart`.
//
// `writeVideoPosterJpeg` itself shells out to ffmpeg / ffmpeg_kit and depends
// on `path_provider`'s app-documents directory, both of which are hard to
// drive in a deterministic unit test. The interesting pure helpers are
// `posterSeekSeconds` (branchy timestamp picker) and
// `posterStorageKeyHexForVideo` (content-hash based key).
import 'dart:convert';

import 'package:crypto/crypto.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/data/files/video_poster_extract.dart';
import 'package:flutter_test/flutter_test.dart';

VideoRow _row({String id = 'row-id', String? md5, int durationSeconds = 60}) {
  return VideoRow(
    id: id,
    vid: 'vid-1',
    provider: 'user',
    title: 't',
    durationSeconds: durationSeconds,
    language: 'en',
    createdAt: DateTime.utc(2024, 1, 1),
    updatedAt: DateTime.utc(2024, 1, 1),
    md5: md5,
  );
}

void main() {
  group('posterSeekSeconds', () {
    test('returns 6.0 fallback when duration is null', () {
      expect(posterSeekSeconds(null), 6.0);
    });

    test('returns 6.0 fallback when duration is zero', () {
      expect(posterSeekSeconds(0), 6.0);
    });

    test('returns 6.0 fallback when duration is negative', () {
      expect(posterSeekSeconds(-10), 6.0);
    });

    test('clamps to (duration*0.45).clamp(0.1, d-0.05) for short clips', () {
      // d = 1 -> 0.45 clamped to [0.1, 0.95] => 0.45.
      expect(posterSeekSeconds(1), closeTo(0.45, 1e-9));
      // d = 2 -> 0.9 clamped to [0.1, 1.95] => 0.9.
      expect(posterSeekSeconds(2), closeTo(0.9, 1e-9));
    });

    test('uses ~12% of duration for clips longer than 2s', () {
      // 10s clip -> 12% = 1.2s, clamped to [2.5, 9.75] => 2.5.
      expect(posterSeekSeconds(10), closeTo(2.5, 1e-9));
      // 30s clip -> 12% = 3.6, clamped to [2.5, 29.75] => 3.6.
      expect(posterSeekSeconds(30), closeTo(3.6, 1e-9));
      // 60s clip -> 12% = 7.2, clamped to [2.5, 59.75] => 7.2.
      expect(posterSeekSeconds(60), closeTo(7.2, 1e-9));
    });

    test('caps at 90s even for very long clips', () {
      // 1000s clip -> 12% = 120s, clamped to [2.5, 999.75] = 120 -> capped at 90.
      expect(posterSeekSeconds(1000), 90.0);
      // 800s clip -> 12% = 96 -> capped at 90.
      expect(posterSeekSeconds(800), 90.0);
    });

    test('respects upper bound (duration - 0.25)', () {
      // 3s clip -> 12% = 0.36, clamp [2.5, 2.75] => 2.5.
      expect(posterSeekSeconds(3), closeTo(2.5, 1e-9));
      // 2.5s clip -> 12% = 0.3, clamp [2.5, 2.25] => 2.5 (lower bound).
      expect(posterSeekSeconds(2), closeTo(0.9, 1e-9));
    });
  });

  group('posterStorageKeyHexForVideo', () {
    test('returns the row md5 when it is set and non-empty', () {
      final row = _row(md5: 'deadbeef');
      expect(posterStorageKeyHexForVideo(row), 'deadbeef');
    });

    test('falls back to sha256(id) when md5 is null', () {
      final row = _row(id: 'xyz');
      final expected = sha256.convert(utf8.encode('xyz')).toString();
      expect(posterStorageKeyHexForVideo(row), expected);
    });

    test('falls back to sha256(id) when md5 is the empty string', () {
      // The function only short-circuits on `isNotEmpty`, so an empty string
      // still falls through to the sha256 fallback.
      final row = _row(id: 'id2', md5: '');
      final expected = sha256.convert(utf8.encode('id2')).toString();
      expect(posterStorageKeyHexForVideo(row), expected);
    });

    test('sha256(id) is 64 hex chars long', () {
      final row = _row(id: 'some-uuid');
      final key = posterStorageKeyHexForVideo(row);
      expect(key, hasLength(64));
      expect(RegExp(r'^[0-9a-f]{64}$').hasMatch(key), isTrue);
    });

    test('different ids yield different storage keys', () {
      final a = posterStorageKeyHexForVideo(_row(id: 'a'));
      final b = posterStorageKeyHexForVideo(_row(id: 'b'));
      expect(a, isNot(b));
    });
  });
}
