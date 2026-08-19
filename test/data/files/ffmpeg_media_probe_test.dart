import 'dart:io';

import 'package:enjoy_player/data/files/ffmpeg_media_probe.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('FfmpegMediaProbe.parseDurationSeconds', () {
    test('parses HH:MM:SS.xx format', () {
      expect(
        FfmpegMediaProbe.parseDurationSeconds(
          '  Duration: 00:01:30.50, start: 0.000000, bitrate: 1024 kb/s',
        ),
        90,
      );
    });

    test('parses hours correctly', () {
      expect(
        FfmpegMediaProbe.parseDurationSeconds(
          'Duration: 01:02:03.45, start: 0.0',
        ),
        3723,
      );
    });

    test('returns null when there is no Duration line', () {
      expect(FfmpegMediaProbe.parseDurationSeconds('something else'), isNull);
    });

    test('returns null when the Duration line is malformed', () {
      expect(
        FfmpegMediaProbe.parseDurationSeconds('Duration: foo, start: 0.0'),
        isNull,
      );
    });

    test('returns null on empty input', () {
      expect(FfmpegMediaProbe.parseDurationSeconds(''), isNull);
    });
  });

  group('FfmpegMediaProbe.countSubtitleStreams', () {
    test('counts each Subtitle stream line', () {
      const stderr = '''
Stream #0:0(und): Video: h264
Stream #0:1(eng): Audio: aac
Stream #0:2(eng): Subtitle: subrip
Stream #0:3(fra): Subtitle: subrip
''';
      expect(FfmpegMediaProbe.countSubtitleStreams(stderr), 2);
    });

    test('handles [0xNNNN] tag between stream id and language', () {
      const stderr = '''
Stream #0:0[0x100](eng): Video: h264
Stream #0:3[0x1200](eng): Subtitle: hdmv_pgs_subtitle
''';
      expect(FfmpegMediaProbe.countSubtitleStreams(stderr), 1);
    });

    test('returns 0 when no subtitle streams exist', () {
      const stderr = '''
Stream #0:0(und): Video: h264
Stream #0:1(eng): Audio: aac
''';
      expect(FfmpegMediaProbe.countSubtitleStreams(stderr), 0);
    });

    test('returns 0 on empty input', () {
      expect(FfmpegMediaProbe.countSubtitleStreams(''), 0);
    });

    test('is case-insensitive on the Subtitle keyword', () {
      const stderr = 'Stream #0:0(eng): SUBTITLE: subrip';
      expect(FfmpegMediaProbe.countSubtitleStreams(stderr), 1);
    });
  });

  group('FfmpegMediaProbe.subtitleLanguageHints', () {
    test('extracts language tags in order', () {
      const stderr = '''
Stream #0:2(eng): Subtitle: subrip
Stream #0:3(fra): Subtitle: subrip
Stream #0:4(spa): Subtitle: subrip
''';
      expect(FfmpegMediaProbe.subtitleLanguageHints(stderr), <String?>[
        'eng',
        'fra',
        'spa',
      ]);
    });

    test('returns null for streams without a language tag', () {
      const stderr = 'Stream #0:2: Subtitle: subrip';
      expect(FfmpegMediaProbe.subtitleLanguageHints(stderr), <String?>[null]);
    });

    test('lowercases the language code', () {
      const stderr = 'Stream #0:2(ENG): Subtitle: subrip';
      expect(FfmpegMediaProbe.subtitleLanguageHints(stderr), ['eng']);
    });

    test('treats "und" / "unknown" / empty as null', () {
      const stderr = '''
Stream #0:2(und): Subtitle: subrip
Stream #0:3(unknown): Subtitle: subrip
Stream #0:4(): Subtitle: subrip
Stream #0:5(en): Subtitle: subrip
''';
      expect(FfmpegMediaProbe.subtitleLanguageHints(stderr), <String?>[
        null,
        null,
        null,
        'en',
      ]);
    });

    test('returns empty list when no subtitle streams', () {
      expect(
        FfmpegMediaProbe.subtitleLanguageHints('Stream #0:0(eng): Video: h264'),
        isEmpty,
      );
    });

    test('trims whitespace around language tag', () {
      const stderr = 'Stream #0:2( eng ): Subtitle: subrip';
      expect(FfmpegMediaProbe.subtitleLanguageHints(stderr), ['eng']);
    });
  });

  group('FfmpegMediaProbe.mediaInputForFfmpeg', () {
    test('returns the file: URI path for file: URIs', () {
      // Uri.toFilePath follows the host platform's path style.
      expect(
        FfmpegMediaProbe.mediaInputForFfmpeg('file:///tmp/movie.mp4'),
        Platform.isWindows ? r'\tmp\movie.mp4' : '/tmp/movie.mp4',
      );
    });

    test('returns the URI unchanged for non-file schemes', () {
      expect(
        FfmpegMediaProbe.mediaInputForFfmpeg('https://example.com/x.mp4'),
        'https://example.com/x.mp4',
      );
    });

    test('returns the URI unchanged for relative paths', () {
      expect(
        FfmpegMediaProbe.mediaInputForFfmpeg('relative/path.mp4'),
        'relative/path.mp4',
      );
    });

    test('returns the URI unchanged for unparseable input', () {
      // An obviously invalid scheme should still be returned as-is because
      // Uri.tryParse fails; we still want determinism.
      expect(FfmpegMediaProbe.mediaInputForFfmpeg('a:b:c'), 'a:b:c');
    });
  });

  group('FfmpegMediaProbe.debugResetFfmpegExecutableCache', () {
    test('exists as a test seam and does not throw', () {
      // No public way to read the cache, but the test seam must be callable
      // (and should be a no-op the first time).
      expect(
        () => FfmpegMediaProbe.debugResetFfmpegExecutableCache(),
        returnsNormally,
      );
    });

    test('resetting twice is safe', () {
      FfmpegMediaProbe.debugResetFfmpegExecutableCache();
      FfmpegMediaProbe.debugResetFfmpegExecutableCache();
      // We don't assert on internal state; just that the seam is callable.
    });
  });

  group('FfmpegMediaProbe.bundledFfmpegCandidatePaths', () {
    test('Windows looks next to the exe', () {
      expect(
        FfmpegMediaProbe.bundledFfmpegCandidatePaths(
          executableDir: r'C:\Program Files\Enjoy',
          isWindows: true,
          isLinux: false,
        ),
        [r'C:\Program Files\Enjoy\ffmpeg.exe'],
      );
    });

    test('Linux looks next to the exe and under lib/', () {
      expect(
        FfmpegMediaProbe.bundledFfmpegCandidatePaths(
          executableDir: '/opt/enjoy/bin',
          isWindows: false,
          isLinux: true,
        ),
        ['/opt/enjoy/bin/ffmpeg', '/opt/enjoy/bin/lib/ffmpeg'],
      );
    });

    test('Apple and Android have no CLI bundle', () {
      expect(
        FfmpegMediaProbe.bundledFfmpegCandidatePaths(
          executableDir: '/Applications/Enjoy.app',
          isWindows: false,
          isLinux: false,
        ),
        isEmpty,
      );
    });
  });
}
