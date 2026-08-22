/// Shadow-reading take capture + persistence (issue #597).
///
/// A deep module behind a small interface: `start` / `cancel` /
/// `stopAndPersist` / `deleteTake`. It hides microphone permission handling,
/// take-path construction, the "recreate the recorder after every stop"
/// Windows workaround, WAV hashing / duration parsing, the silence heuristic,
/// 18-field [RecordingRow] construction, Drift insert, and sync enqueue.
/// The panel shrinks to view + callbacks; tests exercise the seam directly.
library;

import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:uuid/uuid.dart';

import 'package:enjoy_player/core/audio/wav_duration_ms.dart';
import 'package:enjoy_player/core/audio/wav_signal_peak.dart';
import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/db/app_database.dart';
import 'package:enjoy_player/features/sync/domain/sync_types.dart';

final _log = logNamed('ShadowTakeStore');

/// Minimal seam over `package:record`'s [AudioRecorder] so the store can be
/// tested with a fake (production adapter: [PackageRecordMicRecorder]).
abstract class MicRecorder {
  Future<bool> hasPermission();

  Future<void> start(RecordConfig config, {required String path});

  /// Returns the path of the written WAV, or `null`/empty when nothing was
  /// captured.
  Future<String?> stop();

  Future<void> dispose();
}

/// Production adapter delegating to a real [AudioRecorder].
class PackageRecordMicRecorder implements MicRecorder {
  PackageRecordMicRecorder() : _impl = AudioRecorder();

  final AudioRecorder _impl;

  @override
  Future<bool> hasPermission() => _impl.hasPermission();

  @override
  Future<void> start(RecordConfig config, {required String path}) =>
      _impl.start(config, path: path);

  @override
  Future<String?> stop() => _impl.stop();

  @override
  Future<void> dispose() => _impl.dispose();
}

/// The echo region a take is recorded against — everything the persisted
/// [RecordingRow] needs beyond the WAV itself.
class TakeRegion {
  const TakeRegion({
    required this.targetType,
    required this.targetId,
    required this.language,
    required this.referenceText,
    required this.startSec,
    required this.endSec,
  });

  final String targetType;
  final String targetId;
  final String language;
  final String referenceText;
  final double startSec;
  final double endSec;
}

/// Outcome of a successful [ShadowTakeStore.stopAndPersist].
class TakePersistResult {
  const TakePersistResult({required this.row, required this.looksSilent});

  final RecordingRow row;

  /// True when the captured WAV looks silent (low RMS / non-zero ratio). The
  /// caller surfaces a warning; the row is persisted regardless.
  final bool looksSilent;
}

/// Microphone permission was denied by the OS.
final class MicPermissionDeniedException implements Exception {
  const MicPermissionDeniedException();

  @override
  String toString() => 'microphone permission denied';
}

/// The captured WAV is missing or unreadable at persist time.
final class TakeFileMissingException implements Exception {
  const TakeFileMissingException(this.path);

  final String path;

  @override
  String toString() => 'recording wav missing at path: $path';
}

/// Capture config aligned with the web client and Azure Speech expectations.
///
/// 16 kHz mono PCM16 WAV avoids stereo downmix loss (one mic channel + one
/// silent / out-of-phase channel cancelling each other to zero) and matches
/// what the Azure Speech SDK accepts directly without downstream re-encoding.
///
/// `device` is the user's chosen (or auto-picked, non-virtual) microphone —
/// this is what stops Windows from silently picking GlideX / VoiceMeeter /
/// Stereo-Mix loopback devices.
RecordConfig buildShadowRecordConfig(InputDevice? device) => RecordConfig(
  encoder: AudioEncoder.wav,
  sampleRate: 16000,
  numChannels: 1,
  device: device,
);

class ShadowTakeStore {
  ShadowTakeStore({
    required AppDatabase db,
    required SyncEnqueueFn enqueueSync,
    MicRecorder Function()? recorderFactory,
    Directory? takeDirectory,
  }) {
    _db = db;
    _enqueueSync = enqueueSync;
    _recorderFactory = recorderFactory ?? PackageRecordMicRecorder.new;
    _takeDirectoryOverride = takeDirectory;
    _recorder = _recorderFactory();
  }

  late final AppDatabase _db;
  late final SyncEnqueueFn _enqueueSync;
  late final MicRecorder Function() _recorderFactory;
  late final Directory? _takeDirectoryOverride;

  late MicRecorder _recorder;
  bool _active = false;

  /// Whether a take capture is currently in flight on the microphone.
  bool get isActive => _active;

  Future<Directory> _takeDirectory() async {
    final override = _takeDirectoryOverride;
    if (override != null) return override;
    final support = await getApplicationSupportDirectory();
    return Directory(p.join(support.path, 'recordings'));
  }

  /// Begins capturing a take. Throws [MicPermissionDeniedException] when the
  /// OS denies the microphone, or propagates recorder errors.
  Future<void> start({required InputDevice? device}) async {
    final dir = await _takeDirectory();
    await dir.create(recursive: true);
    final id = const Uuid().v4();
    final outPath = p.join(dir.path, '$id.wav');

    final granted = await _recorder.hasPermission();
    if (!granted) {
      throw const MicPermissionDeniedException();
    }

    await _recorder.start(buildShadowRecordConfig(device), path: outPath);
    _active = true;
  }

  /// Discards an in-progress take without persisting it.
  Future<void> cancel() async {
    if (!_active) return;
    _active = false;
    String? path;
    try {
      path = await _recorder.stop();
    } catch (e, st) {
      _log.warning('microphone stop (cancel recording) failed', e, st);
    }
    await _resetRecorder();
    await _deleteFileIfExists(path);
  }

  /// Stops the capture and persists it as a [RecordingRow]. Returns the row
  /// plus a silence verdict; throws [TakeFileMissingException] when nothing
  /// was captured, or propagates DB / sync errors for the caller to surface.
  Future<TakePersistResult> stopAndPersist({required TakeRegion region}) async {
    if (!_active) {
      throw const TakeFileMissingException('');
    }
    _active = false;

    final path = await _recorder.stop();
    await _resetRecorder();

    if (path == null || path.isEmpty) {
      _log.warning('recorder.stop returned no path');
      throw const TakeFileMissingException('');
    }
    _log.fine('recorder.stop wrote $path');
    return _persistRecording(path, region);
  }

  /// Removes a persisted take: sync-enqueue delete, file GC, then DAO delete.
  /// Callers stop any preview playback of [row] first (a presentation concern).
  Future<void> deleteTake(RecordingRow row) async {
    await _enqueueSync(SyncEntityType.recording, row.id, SyncAction.delete);
    final lp = row.localPath;
    if (lp != null && lp.isNotEmpty) {
      await _deleteFileIfExists(lp);
    }
    await _db.recordingDao.deleteId(row.id);
  }

  /// Stops any in-flight capture (discarding the WAV) and releases the
  /// recorder. Safe to call from a widget `dispose`.
  Future<void> dispose() async {
    if (_active) {
      _active = false;
      try {
        final path = await _recorder.stop();
        await _deleteFileIfExists(path);
      } catch (e, st) {
        _log.fine('recorder stop on dispose', e, st);
      }
    }
    try {
      await _recorder.dispose();
    } catch (_) {}
  }

  /// Recreated after every `stop()` — `record` on Windows can keep stale
  /// Media Foundation state on the same instance, so a second `start()`
  /// quietly produces a zero-sample WAV ("second take won't record").
  Future<void> _resetRecorder() async {
    final old = _recorder;
    _recorder = _recorderFactory();
    try {
      await old.dispose();
    } catch (e, st) {
      _log.fine('audio recorder dispose after stop failed', e, st);
    }
  }

  Future<void> _deleteFileIfExists(String? path) async {
    if (path == null || path.isEmpty) return;
    try {
      final f = File(path);
      if (await f.exists()) await f.delete();
    } catch (e, st) {
      _log.fine('delete recording wav failed', e, st);
    }
  }

  Future<TakePersistResult> _persistRecording(
    String wavPath,
    TakeRegion region,
  ) async {
    final file = File(wavPath);
    if (!await file.exists()) {
      _log.warning('recording wav missing at path: $wavPath');
      throw TakeFileMissingException(wavPath);
    }
    final bytes = await file.readAsBytes();
    final hash = sha256.convert(bytes).toString();

    final parsedMs = wavDurationMsFromBytes(bytes);
    final durationMs = parsedMs ?? 0;
    if (parsedMs == null && bytes.isNotEmpty) {
      _log.warning(
        'could not parse WAV duration ($wavPath, ${bytes.length} bytes)',
      );
    }

    var looksSilent = false;
    final peak = scanWavDataPeakFromBytes(bytes);
    if (peak != null) {
      _log.fine(
        'recording wav fmt=${peak.fmt.audioFormat} '
        'ch=${peak.fmt.numChannels} ${peak.fmt.sampleRate}Hz '
        '${peak.fmt.bitsPerSample}bit '
        'peak≈${peak.peakNormalized.toStringAsFixed(5)} '
        'rms≈${peak.rmsNormalized.toStringAsFixed(6)} '
        'nonZero=${(peak.nonZeroRatio * 100).toStringAsFixed(2)}% '
        'samples=${peak.totalSamples} '
        'bytes=${bytes.length} durMs=$durationMs',
      );
      // Real speech captured at moderate volume gives RMS in the rough
      // 0.02-0.3 range. RMS below ~0.001 with non-zero ratio under ~1% means
      // the WAV is essentially silent even when peak looks healthy.
      const minRms = 0.001;
      const minNonZeroRatio = 0.01;
      looksSilent =
          peak.rmsNormalized < minRms || peak.nonZeroRatio < minNonZeroRatio;
      if (looksSilent) {
        _log.warning(
          'recording wav appears silent '
          '(peak≈${peak.peakNormalized.toStringAsFixed(6)} '
          'rms≈${peak.rmsNormalized.toStringAsFixed(6)} '
          'nonZero=${(peak.nonZeroRatio * 100).toStringAsFixed(2)}%). '
          'Check Windows microphone privacy / default input device.',
        );
      }
    }

    final id = p.basenameWithoutExtension(wavPath);
    final now = DateTime.now();
    final startMs = (region.startSec * 1000).round();
    final durMs = ((region.endSec - region.startSec) * 1000).round();
    final row = RecordingRow(
      id: id,
      targetType: region.targetType,
      targetId: region.targetId,
      referenceStart: startMs,
      referenceDuration: durMs,
      referenceText: region.referenceText,
      language: region.language,
      duration: durationMs,
      md5: hash,
      audioUrl: null,
      pronunciationScore: null,
      assessmentJson: null,
      localPath: wavPath,
      syncStatus: 'local',
      serverUpdatedAt: null,
      createdAt: now,
      updatedAt: now,
    );
    await _db.recordingDao.insertRow(row);
    await _enqueueSync(SyncEntityType.recording, id, SyncAction.create);
    return TakePersistResult(row: row, looksSilent: looksSilent);
  }
}
