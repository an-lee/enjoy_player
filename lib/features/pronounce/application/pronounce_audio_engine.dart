/// Thin playback engine for pronounce URLs (testable; not media_kit).
library;

import 'dart:async';
import 'dart:io' show Platform;
import 'dart:typed_data';

import 'package:audioplayers/audioplayers.dart';
import 'package:http/http.dart' as http;

import 'package:enjoy_player/core/logging/log.dart';

abstract interface class PronounceAudioEngine {
  Future<void> playUrl(String url);
  Future<void> stop();
  Stream<void> get onComplete;
  Future<void> dispose();
}

typedef PronounceHttpGet = Future<http.Response> Function(Uri url);

final class AudioplayersPronounceEngine implements PronounceAudioEngine {
  AudioplayersPronounceEngine({AudioPlayer? player, PronounceHttpGet? httpGet})
    : _player = player ?? AudioPlayer(),
      _httpGet = httpGet ?? _defaultHttpGet;

  static final _log = logNamed('Pronounce');

  final AudioPlayer _player;
  final PronounceHttpGet _httpGet;
  final _complete = StreamController<void>.broadcast();
  StreamSubscription<void>? _sub;
  bool _wired = false;

  static Future<http.Response> _defaultHttpGet(Uri url) async {
    final client = http.Client();
    try {
      return await client.get(url);
    } finally {
      client.close();
    }
  }

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
    // Windows Media Foundation `CreateObjectFromURL` often returns
    // ACCESS_DENIED (0x80070005) for remote HTTPS URLs. Craft already plays
    // TTS via [BytesSource]; use the same path on Windows, and fall back
    // elsewhere when streaming fails (see specs/031-word-pronounce/research R3).
    if (Platform.isWindows) {
      await _playFromBytes(url);
      return;
    }
    try {
      await _player.play(UrlSource(url));
    } on Object catch (e, st) {
      _log.info('UrlSource failed; falling back to BytesSource', e, st);
      await _playFromBytes(url);
    }
  }

  Future<void> _playFromBytes(String url) async {
    final response = await _httpGet(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw StateError(
        'Pronounce audio download failed: HTTP ${response.statusCode}',
      );
    }
    final bytes = Uint8List.fromList(response.bodyBytes);
    if (bytes.isEmpty) {
      throw StateError('Pronounce audio download returned empty body');
    }
    await _player.play(BytesSource(bytes));
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
