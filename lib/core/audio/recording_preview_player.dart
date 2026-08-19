/// Dedicated [media_kit.Player] for shadow-reading take previews (ADR-0003 scope).
///
/// Separate from [PlayerController]'s engine so lesson playback is not replaced.
///
/// [stop] clears the loaded file path; [play] / [playOrPauseTake] / [playClip]
/// set it after a successful [open].
library;

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:media_kit/media_kit.dart' as mk;

import 'package:enjoy_player/core/logging/log.dart';
import 'package:enjoy_player/data/files/security_scoped_bookmark.dart';

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

  /// Active macOS security-scoped grant for the currently loaded path, if
  /// any. Released on `stop()`, the next `play*` call, and on `dispose()`.
  /// See ADR-0060.
  int? _scopeToken;

  Future<void> _releaseScope() async {
    final token = _scopeToken;
    if (token == null) return;
    _scopeToken = null;
    await SecurityScopedBookmarkChannel.releaseBookmark(token);
  }

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
    final resolved = await _resolveForPlayback(abs);
    final uri = Uri.file(resolved.path).toString();
    try {
      await stop();
      await _player.open(mk.Media(uri));
      await _player.play();
      _loadedPath = abs;
      _scopeToken = resolved.scopeToken;
    } catch (e, st) {
      final token = resolved.scopeToken;
      if (token != null) {
        await SecurityScopedBookmarkChannel.releaseBookmark(token);
      }
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
    final resolved = await _resolveForPlayback(abs);
    final uri = Uri.file(resolved.path).toString();
    final gen = ++_clipGeneration;
    try {
      await _cancelClipWatcher();
      await _player.stop();
      _loadedPath = null;
      // Prefer Media start/end over post-open seek (seek-before-ready is a no-op).
      await _player.open(mk.Media(uri, start: start, end: end));
      _loadedPath = abs;
      _scopeToken = resolved.scopeToken;
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
      final token = resolved.scopeToken;
      if (token != null) {
        await SecurityScopedBookmarkChannel.releaseBookmark(token);
      }
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
    await _releaseScope();
  }

  @override
  Future<void> dispose() async {
    if (_disposed) return;
    _disposed = true;
    _clipGeneration++;
    await _cancelClipWatcher();
    _loadedPath = null;
    await _releaseScope();
    await _player.dispose();
  }

  Future<void> _cancelClipWatcher() async {
    await _clipEndSub?.cancel();
    _clipEndSub = null;
  }

  /// Resolves [absolutePath] for playback: returns the path itself plus an
  /// optional security-scoped access token (the macOS sandbox grants
  /// disappear between launches; ADR-0060). Returns a token of `null` on
  /// any non-macOS platform or when no native shim is registered.
  Future<_ResolvedPath> _resolveForPlayback(String absolutePath) async {
    final bookmark = await _loadBookmarkFor(absolutePath);
    if (bookmark != null) {
      final resolved = await SecurityScopedBookmarkChannel.resolveBookmark(
        bookmark,
      );
      if (resolved != null) {
        return _ResolvedPath(resolved.path, resolved.token);
      }
      // Bookmark resolution failed (file gone, scope denied) — fall
      // through to the legacy path so the open still has a chance.
    }
    return _ResolvedPath(absolutePath, null);
  }

  Future<Uint8List?> _loadBookmarkFor(String absolutePath) async {
    // Preview recordings are app-managed (Craft from text writes into the
    // app sandbox's `media/` folder) — they never have a bookmark. We keep
    // the hook for future shadow-reading-of-imported-media features that
    // may need to look up a row's bookmark blob.
    return null;
  }
}

class _ResolvedPath {
  const _ResolvedPath(this.path, this.scopeToken);
  final String path;
  final int? scopeToken;
}
