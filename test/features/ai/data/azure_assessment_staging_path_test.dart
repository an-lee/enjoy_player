import 'dart:io';

import 'package:enjoy_player/features/ai/data/azure_assessment_staging_path.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;

String _join(String root, String sub1, String sub2) {
  return p.join(root, sub1, sub2);
}

void main() {
  group('pathContainsNonAscii', () {
    test('returns false for pure ASCII paths', () {
      expect(pathContainsNonAscii(r'C:\Windows\Temp\audio.wav'), isFalse);
      expect(pathContainsNonAscii('/tmp/audio.wav'), isFalse);
      expect(pathContainsNonAscii(''), isFalse);
    });

    test('returns true when any code unit is outside 7-bit ASCII', () {
      expect(
        pathContainsNonAscii(r'C:\Users\中文\AppData\Local\Temp\a.wav'),
        isTrue,
      );
      expect(pathContainsNonAscii('café.wav'), isTrue);
      expect(pathContainsNonAscii('naïve'), isTrue);
    });
  });

  group('preferAsciiTempRoot', () {
    test('returns systemTemp unchanged on non-Windows platforms', () {
      final out = preferAsciiTempRoot(
        isWindows: false,
        systemTemp: r'C:\Users\中文\AppData\Local\Temp',
        systemRoot: r'C:\Windows',
        windir: r'C:\Windows',
      );
      expect(out, r'C:\Users\中文\AppData\Local\Temp');
    });

    test('returns systemTemp unchanged when it is already ASCII', () {
      final out = preferAsciiTempRoot(
        isWindows: true,
        systemTemp: r'C:\Users\Alice\AppData\Local\Temp',
      );
      expect(out, r'C:\Users\Alice\AppData\Local\Temp');
    });

    test('prefers systemRoot when present and ASCII', () {
      final out = preferAsciiTempRoot(
        isWindows: true,
        systemTemp: r'C:\Users\中文\AppData\Local\Temp',
        systemRoot: r'C:\Windows',
        windir: r'C:\WINDIR',
      );
      expect(out, _join(r'C:\Windows', 'Temp', 'EnjoyPlayer'));
    });

    test('falls back to windir when systemRoot is missing', () {
      final out = preferAsciiTempRoot(
        isWindows: true,
        systemTemp: r'C:\Users\中文\AppData\Local\Temp',
        windir: r'C:\Windows',
      );
      expect(out, _join(r'C:\Windows', 'Temp', 'EnjoyPlayer'));
    });

    test('skips empty systemRoot and windir candidates', () {
      final out = preferAsciiTempRoot(
        isWindows: true,
        systemTemp: r'C:\Users\中文\AppData\Local\Temp',
        systemRoot: '   ',
        windir: '',
      );
      expect(out, _join(r'C:\Windows', 'Temp', 'EnjoyPlayer'));
    });

    test('returns preferred ASCII path when candidates include ASCII', () {
      // systemRoot is ASCII so it should win.
      final out = preferAsciiTempRoot(
        isWindows: true,
        systemTemp: r'中文\Temp',
        systemRoot: r'C:\Windows',
        windir: r'中文\Win',
      );
      expect(out, _join(r'C:\Windows', 'Temp', 'EnjoyPlayer'));
    });
  });

  group('resolveAzureAssessmentStagingDir', () {
    test('returns systemTemp when it is already ASCII', () async {
      final dir = await resolveAzureAssessmentStagingDir(
        systemTempOverride: Directory.systemTemp.path,
      );
      expect(dir.path, Directory.systemTemp.path);
    });

    test('returns a directory when systemTemp is non-ASCII', () async {
      final dir = await resolveAzureAssessmentStagingDir(
        systemTempOverride: r'中文\Temp',
      );
      expect(dir.path, isNotEmpty);
    });
  });

  group('stageWavForAzureAssessment', () {
    test('returns the original path on non-Windows', () async {
      // On Windows, a leading-/ path is resolved against the current drive
      // root by File.absolute — this case only asserts the POSIX short-circuit.
      if (Platform.isWindows) return;
      final result = await stageWavForAzureAssessment('/tmp/audio.wav');
      expect(result.$1, '/tmp/audio.wav');
      expect(result.$2, isFalse);
    });

    test('returns the original path when it is ASCII', () async {
      final asciiPath = Platform.isWindows
          ? r'C:\Users\Alice\AppData\Local\Temp\ascii_path.wav'
          : '/var/tmp/ascii_path.wav';
      final result = await stageWavForAzureAssessment(asciiPath);
      expect(result.$1, File(asciiPath).absolute.path);
      expect(result.$2, isFalse);
    });
  });
}
