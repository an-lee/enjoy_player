import 'dart:io';

import 'package:enjoy_player/core/utils/local_thumbnail.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('localThumbnailFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('local_thumbnail_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('returns null when path is null', () {
      expect(localThumbnailFile(null), isNull);
    });

    test('returns null when path is empty', () {
      expect(localThumbnailFile(''), isNull);
    });

    test('returns null when file does not exist', () {
      final missing = '${tempDir.path}/missing.png';
      expect(localThumbnailFile(missing), isNull);
    });

    test('returns File when file exists', () {
      final file = File('${tempDir.path}/thumb.png');
      file.writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
      final result = localThumbnailFile(file.path);
      expect(result, isNotNull);
      expect(result!.path, file.path);
    });

    test(
      'returns null for whitespace-only path because no such file exists',
      () {
        // Whitespace is not an empty string for `String.isEmpty`, so it falls
        // through to the `File.existsSync` check, which returns null.
        expect(localThumbnailFile('   '), isNull);
      },
    );
  });

  group('resolveLocalThumbnailFile', () {
    late Directory tempDir;

    setUp(() {
      tempDir = Directory.systemTemp.createTempSync('local_thumbnail_test_');
    });

    tearDown(() {
      if (tempDir.existsSync()) {
        tempDir.deleteSync(recursive: true);
      }
    });

    test('agrees with the sync helper', () async {
      final file = File('${tempDir.path}/thumb.png');
      file.writeAsBytesSync(<int>[0x89, 0x50, 0x4E, 0x47]);
      final resolved = await resolveLocalThumbnailFile(file.path);
      expect(resolved!.path, localThumbnailFile(file.path)!.path);
    });

    test('returns null for null, empty and missing paths', () async {
      expect(await resolveLocalThumbnailFile(null), isNull);
      expect(await resolveLocalThumbnailFile(''), isNull);
      expect(
        await resolveLocalThumbnailFile('${tempDir.path}/missing.png'),
        isNull,
      );
    });
  });

  group('thumbnailCacheWidthFor', () {
    test('is twice the rendered slot width', () {
      expect(thumbnailCacheWidthFor(480), 960);
    });

    test('clamps to a sane upper bound and never returns 0', () {
      expect(thumbnailCacheWidthFor(5000), lessThanOrEqualTo(2048));
      expect(thumbnailCacheWidthFor(0), 1);
      expect(thumbnailCacheWidthFor(-40), 1);
      expect(thumbnailCacheWidthFor(double.nan), 1);
    });
  });
}
