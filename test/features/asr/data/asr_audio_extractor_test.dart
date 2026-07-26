import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:enjoy_player/features/asr/data/asr_audio_extractor.dart';
import 'package:enjoy_player/features/asr/domain/asr_audio_extraction_failure.dart';

void main() {
  group('AsrAudioExtractor — audio path', () {
    test('audio-only: reads source bytes directly', () async {
      final tmp = Directory.systemTemp.createTempSync('asr_test_audio_');
      final file = File('${tmp.path}/sample.wav')..writeAsBytesSync([1, 2, 3]);
      addTearDown(() => tmp.delete(recursive: true));

      final bytes = await const AsrAudioExtractor().extractAudio(
        mediaSourceUri: file.path,
        kind: MediaKind.audio,
      );

      expect(bytes, equals(Uint8List.fromList([1, 2, 3])));
    });

    test('audio: oversized file → fileTooLarge', () async {
      final tmp = Directory.systemTemp.createTempSync('asr_test_big_');
      // 4 KB file, but cap at 1 KB.
      final file = File('${tmp.path}/big.wav')
        ..writeAsBytesSync(List.filled(4096, 0));
      addTearDown(() => tmp.delete(recursive: true));

      expect(
        () => const AsrAudioExtractor().extractAudio(
          mediaSourceUri: file.path,
          kind: MediaKind.audio,
          maxBytes: 1024,
        ),
        throwsA(
          isA<AsrAudioExtractionException>().having(
            (e) => e.reason,
            'reason',
            AsrAudioExtractionFailureReason.fileTooLarge,
          ),
        ),
      );
    });

    test('audio: missing file → unsupportedSource', () async {
      expect(
        () => const AsrAudioExtractor().extractAudio(
          mediaSourceUri: '/definitely/does/not/exist.mp3',
          kind: MediaKind.audio,
        ),
        throwsA(
          isA<AsrAudioExtractionException>().having(
            (e) => e.reason,
            'reason',
            AsrAudioExtractionFailureReason.unsupportedSource,
          ),
        ),
      );
    });

    test('audio: whitespace URI → unsupportedSource', () async {
      expect(
        () => const AsrAudioExtractor().extractAudio(
          mediaSourceUri: '   ',
          kind: MediaKind.audio,
        ),
        throwsA(
          isA<AsrAudioExtractionException>().having(
            (e) => e.reason,
            'reason',
            AsrAudioExtractionFailureReason.unsupportedSource,
          ),
        ),
      );
    });

    test('audio: large but within maxBytes reads the full file', () async {
      final tmp = Directory.systemTemp.createTempSync('asr_test_fit_');
      final bytes = List<int>.filled(2048, 7);
      final file = File('${tmp.path}/fit.wav')..writeAsBytesSync(bytes);
      addTearDown(() => tmp.delete(recursive: true));

      final out = await const AsrAudioExtractor().extractAudio(
        mediaSourceUri: file.path,
        kind: MediaKind.audio,
        maxBytes: 4096,
      );
      expect(out, equals(Uint8List.fromList(bytes)));
    });
  });

  group('AsrAudioExtractor — video path failure modes', () {
    test('missing file → unsupportedSource', () async {
      expect(
        () => const AsrAudioExtractor().extractAudio(
          mediaSourceUri: '/definitely/does/not/exist.mp4',
          kind: MediaKind.video,
        ),
        throwsA(
          isA<AsrAudioExtractionException>().having(
            (e) => e.reason,
            'reason',
            AsrAudioExtractionFailureReason.unsupportedSource,
          ),
        ),
      );
    });

    test('empty URI → unsupportedSource', () async {
      expect(
        () => const AsrAudioExtractor().extractAudio(
          mediaSourceUri: '',
          kind: MediaKind.video,
        ),
        throwsA(
          isA<AsrAudioExtractionException>().having(
            (e) => e.reason,
            'reason',
            AsrAudioExtractionFailureReason.unsupportedSource,
          ),
        ),
      );
    });

    test('oversized video file → fileTooLarge', () async {
      final tmp = Directory.systemTemp.createTempSync('asr_test_video_big_');
      // 4 KB file, but cap at 1 KB.
      final file = File('${tmp.path}/big.mp4')
        ..writeAsBytesSync(List.filled(4096, 0));
      addTearDown(() => tmp.delete(recursive: true));

      expect(
        () => const AsrAudioExtractor().extractAudio(
          mediaSourceUri: file.path,
          kind: MediaKind.video,
          maxBytes: 1024,
        ),
        throwsA(
          isA<AsrAudioExtractionException>().having(
            (e) => e.reason,
            'reason',
            AsrAudioExtractionFailureReason.fileTooLarge,
          ),
        ),
      );
    });
  });
}
