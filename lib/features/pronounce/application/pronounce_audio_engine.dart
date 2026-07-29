/// Thin playback engine for pronounce URLs (testable; not media_kit).
library;

import 'dart:async';

import 'package:audioplayers/audioplayers.dart';

abstract interface class PronounceAudioEngine {
  Future<void> playUrl(String url);
  Future<void> stop();
  Stream<void> get onComplete;
  Future<void> dispose();
}

final class AudioplayersPronounceEngine implements PronounceAudioEngine {
  AudioplayersPronounceEngine({AudioPlayer? player})
    : _player = player ?? AudioPlayer();

  final AudioPlayer _player;
  final _complete = StreamController<void>.broadcast();
  StreamSubscription<void>? _sub;
  bool _wired = false;

  void _ensureWired() {
    if (_wired) return;
    _wired = true;
    _sub = _player.onPlayerComplete.listen((_) {
      if (!_complete.isClosed) _complete.add(null);
    });
  }

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> playUrl(String url) async {
    _ensureWired();
    await _player.stop();
    await _player.play(UrlSource(url));
  }

  @override
  Future<void> stop() => _player.stop();

  @override
  Future<void> dispose() async {
    await _sub?.cancel();
    _sub = null;
    await _player.dispose();
    await _complete.close();
  }
}

/// In-memory fake for unit tests.
final class FakePronounceAudioEngine implements PronounceAudioEngine {
  final _complete = StreamController<void>.broadcast();
  final List<String> playedUrls = <String>[];
  int stopCount = 0;
  bool disposed = false;

  @override
  Stream<void> get onComplete => _complete.stream;

  @override
  Future<void> playUrl(String url) async {
    playedUrls.add(url);
  }

  @override
  Future<void> stop() async {
    stopCount++;
  }

  void emitComplete() {
    if (!_complete.isClosed) _complete.add(null);
  }

  @override
  Future<void> dispose() async {
    disposed = true;
    await _complete.close();
  }
}
