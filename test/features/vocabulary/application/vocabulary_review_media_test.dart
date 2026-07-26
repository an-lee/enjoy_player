import 'package:enjoy_player/features/vocabulary/application/vocabulary_review_media.dart';
import 'package:enjoy_player/features/vocabulary/domain/vocabulary_models.dart';
import 'package:flutter_test/flutter_test.dart';

VocabularyContext _context({
  VocabularySourceType sourceType = VocabularySourceType.video,
  String sourceId = 'media-1',
  MediaLocator? locator,
}) {
  return VocabularyContext(
    id: 'ctx-1',
    vocabularyItemId: 'vocab-1',
    text: 'hello',
    sourceType: sourceType,
    sourceId: sourceId,
    locator: locator,
    createdAt: DateTime.utc(2024),
    updatedAt: DateTime.utc(2024),
  );
}

void main() {
  group('mediaLocatorWindow', () {
    test('converts milliseconds to seconds', () {
      final locator = MediaLocator(start: 5000, duration: 3000);
      final window = mediaLocatorWindow(locator);
      expect(window.startSec, closeTo(5.0, 1e-9));
      expect(window.endSec, closeTo(8.0, 1e-9));
    });

    test('handles zero start', () {
      final locator = MediaLocator(start: 0, duration: 1500);
      final window = mediaLocatorWindow(locator);
      expect(window.startSec, 0.0);
      expect(window.endSec, closeTo(1.5, 1e-9));
    });

    test('handles large values', () {
      final locator = MediaLocator(start: 3600000, duration: 60000);
      final window = mediaLocatorWindow(locator);
      expect(window.startSec, closeTo(3600.0, 1e-9));
      expect(window.endSec, closeTo(3660.0, 1e-9));
    });
  });

  group('vocabularyContextSupportsMediaActions', () {
    test('true for video with valid locator and sourceId', () {
      final ctx = _context(
        sourceType: VocabularySourceType.video,
        sourceId: 'vid-1',
        locator: MediaLocator(start: 1000, duration: 2000),
      );
      expect(vocabularyContextSupportsMediaActions(ctx), isTrue);
    });

    test('true for audio with valid locator and sourceId', () {
      final ctx = _context(
        sourceType: VocabularySourceType.audio,
        sourceId: 'aud-1',
        locator: MediaLocator(start: 0, duration: 5000),
      );
      expect(vocabularyContextSupportsMediaActions(ctx), isTrue);
    });

    test('false for ebook source type', () {
      final ctx = _context(
        sourceType: VocabularySourceType.ebook,
        sourceId: 'book-1',
        locator: MediaLocator(start: 0, duration: 1000),
      );
      expect(vocabularyContextSupportsMediaActions(ctx), isFalse);
    });

    test('false when locator is null', () {
      final ctx = _context(
        sourceType: VocabularySourceType.video,
        sourceId: 'vid-1',
        locator: null,
      );
      expect(vocabularyContextSupportsMediaActions(ctx), isFalse);
    });

    test('false when locator duration is zero', () {
      final ctx = _context(
        sourceType: VocabularySourceType.video,
        sourceId: 'vid-1',
        locator: MediaLocator(start: 1000, duration: 0),
      );
      expect(vocabularyContextSupportsMediaActions(ctx), isFalse);
    });

    test('false when locator duration is negative', () {
      final ctx = _context(
        sourceType: VocabularySourceType.video,
        sourceId: 'vid-1',
        locator: MediaLocator(start: 1000, duration: -100),
      );
      expect(vocabularyContextSupportsMediaActions(ctx), isFalse);
    });

    test('false when sourceId is empty', () {
      final ctx = _context(
        sourceType: VocabularySourceType.video,
        sourceId: '',
        locator: MediaLocator(start: 0, duration: 1000),
      );
      expect(vocabularyContextSupportsMediaActions(ctx), isFalse);
    });
  });
}
