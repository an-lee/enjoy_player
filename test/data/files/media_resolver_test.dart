/// Tests for the library-import filename extension classifier.
///
/// The picker extension lists feed `FilePicker.allowedExtensions` and the
/// library import filter, so accidental drift here directly affects which
/// files users can bring into the app.
library;

import 'package:enjoy_player/data/files/media_resolver.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('isVideoFileName', () {
    test('recognizes every supported video extension', () {
      for (final ext in kFilePickerLocalVideoExtensions) {
        expect(isVideoFileName('clip.$ext'), isTrue, reason: ext);
      }
    });

    test('is case-insensitive on the extension', () {
      expect(isVideoFileName('clip.MP4'), isTrue);
      expect(isVideoFileName('clip.Mp4'), isTrue);
      expect(isVideoFileName('clip.mOV'), isTrue);
    });

    test('rejects unsupported video extensions', () {
      expect(isVideoFileName('clip.txt'), isFalse);
      expect(isVideoFileName('clip.mp3'), isFalse);
      expect(isVideoFileName('clip.flac'), isFalse);
    });

    test('rejects files without an extension', () {
      expect(isVideoFileName('clip'), isFalse);
      expect(isVideoFileName(''), isFalse);
      expect(isVideoFileName('.'), isFalse);
    });

    test('rejects dot-prefixed names whose dot is not a separator', () {
      // `.mp4` (just the extension, no basename) must not be classified as
      // video — `path.extension` returns '.mp4' but the basename is empty.
      expect(isVideoFileName('.mp4'), isFalse);
    });
  });

  group('isAudioFileName', () {
    test('recognizes every supported audio extension', () {
      for (final ext in kFilePickerLocalAudioExtensions) {
        expect(isAudioFileName('clip.$ext'), isTrue, reason: ext);
      }
    });

    test('is case-insensitive on the extension', () {
      expect(isAudioFileName('clip.MP3'), isTrue);
      expect(isAudioFileName('clip.Opus'), isTrue);
      expect(isAudioFileName('clip.oGa'), isTrue);
    });

    test('rejects video-only and unsupported extensions', () {
      expect(isAudioFileName('clip.mp4'), isFalse);
      expect(isAudioFileName('clip.mkv'), isFalse);
      expect(isAudioFileName('clip.txt'), isFalse);
    });

    test('rejects files without an extension', () {
      expect(isAudioFileName('clip'), isFalse);
      expect(isAudioFileName(''), isFalse);
    });
  });

  group('isImportableLocalMediaFileName', () {
    test('is the union of video and audio extensions', () {
      expect(
        isImportableLocalMediaFileName('clip.mp4'),
        isVideoFileName('clip.mp4'),
      );
      expect(
        isImportableLocalMediaFileName('clip.mp3'),
        isAudioFileName('clip.mp3'),
      );
    });

    test('rejects non-media extensions', () {
      expect(isImportableLocalMediaFileName('clip.txt'), isFalse);
      expect(isImportableLocalMediaFileName('notes.md'), isFalse);
      expect(isImportableLocalMediaFileName('cover.jpg'), isFalse);
    });

    test('every constant in kFilePickerLocalImportExtensions imports', () {
      for (final ext in kFilePickerLocalImportExtensions) {
        expect(
          isImportableLocalMediaFileName('file.$ext'),
          isTrue,
          reason: ext,
        );
      }
    });

    test('extension lists stay disjoint (no overlap between audio/video)', () {
      // If anyone ever accidentally duplicates an extension across the two
      // lists, the union still classifies it as one or the other — but we
      // want to keep them clean so callers can render the right kind icon.
      final overlap = kFilePickerLocalVideoExtensions
          .toSet()
          .intersection(kFilePickerLocalAudioExtensions.toSet());
      expect(overlap, isEmpty);
    });
  });
}