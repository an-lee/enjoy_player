/// Dedicated [media_kit.Player] for shadow-reading take previews (ADR-0003 scope).
///
/// Separate from [PlayerController]'s engine so lesson playback is not replaced.
///
/// [stop] clears the loaded file path; [play] / [playOrPauseTake] / [playClip]
/// set it after a successful [open].
library;

import 'dart:async';
import 'dart:io';

import 'package:media_kit/media_kit.dart' as mk;

import 'package:enjoy_player/core/logging/log.dart';

final _log = logNamed('recordingPreview');

/// Arms a one-shot listener that invokes [onEnd] when [position] reaches [end].
///
/// Used by [RecordingPreviewPlayer.playClip]; exposed for unit tests without
/// constructing a native media_kit player.
StreamSubscription<Duration> armClipEndWatcher({
  required Stream<Duration> position,
  required Duration end,
  required void Function() onEnd,
}) {
  var done = false;
  late final StreamSubscription<Duration> sub;
  sub = position.listen((pos) {
    if (done) return;
    if (pos >= end) {
      done = true;
      onEnd();
    }
  });
  return sub;
}

/// Take-preview API used by shadow-reading UI (ADR-0003 second player).
///
/// Production impl: [RecordingPreviewPlayer]. Tests may stub this without
/// constructing a native media_kit [Player].
abstract class RecordingPreviewPlayback {
  String? get loadedPath;
  Stream<Duration> get position;
  Stream<Duration> get duration;
  Stream<bool> get playing;

  Future<void> play(String path);
  Future<void> seek(Duration position);
  Future<void> playClip(String path, Duration start, Duration end);
  Future<void> playOrPauseTake(String path);
  Future<void> stop();
  Future<void> dispose();
}

/// Wraps a single `media_kit` player for local WAV (or other) preview files.
class RecordingPreviewPlayer implements RecordingPreviewPlayback {
  RecordingPreviewPlayer() : _player = mk.Player();

  final mk.Player _player;
  bool _disposed = false;

  /// Absolute path of the file last opened for preview, or null after [stop].
  String? _loadedPath;

  StreamSubscription<Duration>? _clipEndSub;
  int _clipGeneration = 0;

  /// Absolute path of the media currently loaded, if any.
  @override
  String? get loadedPath => _loadedPath;

  @override
  Stream<Duration> get position => _player.stream.position;

  @override
  Stream<Duration> get duration => _player.stream.duration;

  @override
  Stream<bool> get playing => _player.stream.playing;

  /// Plays [path] from disk from the start; stops any current preview first.
  @override
  Future<void> play(String path) async {
    if (_disposed) {
      throw StateError('RecordingPreviewPlayer disposed');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Recording file missing: $path');
    }
    final abs = file.absolute.path;
    final uri = Uri.file(abs).toString();
    try {
      await stop();
      await _player.open(mk.Media(uri));
      await _player.play();
      _loadedPath = abs;
    } catch (e, st) {
      _log.warning('preview playback failed', e, st);
      rethrow;
    }
  }

  /// Seeks within the currently loaded media.
  @override
  Future<void> seek(Duration position) async {
    if (_disposed) {
      throw StateError('RecordingPreviewPlayer disposed');
    }
    await _player.seek(position);
  }

  /// Plays [path] from [start] until [end], then [stop]s.
  ///
  /// Uses media_kit [Media.start]/[Media.end] — seeking right after [open]
  /// is often ignored and would play from 0 until [end].
  @override
  Future<void> playClip(String path, Duration start, Duration end) async {
    if (_disposed) {
      throw StateError('RecordingPreviewPlayer disposed');
    }
    if (end <= start) {
      throw ArgumentError.value(end, 'end', 'must be greater than start');
    }
    final file = File(path);
    if (!await file.exists()) {
      throw StateError('Recording file missing: $path');
    }
    final abs = file.absolute.path;
    final uri = Uri.file(abs).toString();
    final gen = ++_clipGeneration;
    try {
      await _cancelClipWatcher();
      await _player.stop();
      _loadedPath = null;
      // Prefer Media start/end over post-open seek (seek-before-ready is a no-op).
      await _player.open(mk.Media(uri, start: start, end: end));
      _loadedPath = abs;
      await _player.play();
      // Safety net if the backend ignores Media.end on some platforms.
      _clipEndSub = armClipEndWatcher(
        position: _player.stream.position,
        end: end,
        onEnd: () {
          if (gen != _clipGeneration || _disposed) return;
          unawaited(stop());
        },
      );
    } catch (e, st) {
      _log.warning('preview clip playback failed', e, st);
      rethrow;
    }
  }

  /// If [path] is already loaded, toggles play/pause; otherwise opens and plays it.
  @override
  Future<void> playOrPauseTake(String path) async {
    if (_disposed) {
      throw StateError('RecordingPreviewPlayer disposed');
    }
    final abs = File(path).absolute.path;
    if (_loadedPath != null && _loadedPath == abs) {
      await _cancelClipWatcher();
      await _player.playOrPause();
      return;
    }
    await play(path);
  }

  @override
  Future<void> stop() async {
    if (_disposed) return;
    _clipGeneration++;
    await _cancelClipWatcher();
    await _player.stop();
    _loadedPath = null;
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _clipGeneration++;
    await _cancelClipWatcher();
    _loadedPath = null;
    await _player.dispose();
  }

  Future<void> _cancelClipWatcher() async {
    await _clipEndSub?.cancel();
    _clipEndSub = null;
  }
}
