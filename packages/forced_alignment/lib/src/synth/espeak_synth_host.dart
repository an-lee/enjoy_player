import 'dart:async';
import 'dart:isolate';

import 'package:logging/logging.dart';

import '../failures.dart';
import '../request.dart';
import 'espeak_ng_synthesizer.dart';
import 'native_paths.dart';
import 'spoken_reference.dart';

final _log = Logger('forced_alignment');

final class _EspeakJob {
  const _EspeakJob({
    required this.id,
    required this.reply,
    required this.text,
    required this.language,
    this.libraryPath,
    this.dataPath,
  });

  final int id;
  final SendPort reply;
  final String text;
  final String language;
  final String? libraryPath;
  final String? dataPath;
}

final class _EspeakCancel {
  const _EspeakCancel(this.id);

  final int id;
}

/// One long-lived isolate owns every eSpeak-NG call.
///
/// eSpeak-NG process-global APIs are not safe across overlapping
/// `Isolate.spawn` workers. All production synth goes through this host;
/// DTW isolates receive a finished [ReferenceAudio] only.
void _espeakSynthIsolateMain(SendPort ready) {
  final inbox = ReceivePort();
  var cancelled = false;
  int? currentId;
  inbox.listen((message) {
    if (message is _EspeakCancel) {
      if (currentId == message.id) cancelled = true;
      return;
    }
    if (message is! _EspeakJob) return;
    currentId = message.id;
    cancelled = false;
    setEspeakNativePathOverrides(
      libraryPath: message.libraryPath,
      dataPath: message.dataPath,
    );
    try {
      final audio = EspeakNgSynthesizer(
        isCancelled: () => cancelled,
      ).synthesize(text: message.text, language: message.language);
      message.reply.send(audio);
    } on SpokenReferenceException catch (e) {
      message.reply.send(e);
    } catch (e, st) {
      _log.warning('eSpeak synth isolate failed', e, st);
      message.reply.send(SpokenReferenceException(message: e.toString()));
    } finally {
      currentId = null;
      cancelled = false;
    }
  });
  ready.send(inbox.sendPort);
}

/// Serial production synthesizer. Safe to call from many `align` jobs.
final class EspeakSynthHost {
  static SendPort? _commands;
  static Future<void>? _starting;
  static Future<void> _queue = Future<void>.value();
  static int _nextId = 1;

  static Future<void> _ensureStarted() async {
    if (_commands != null) return;
    _starting ??= () async {
      final ready = ReceivePort();
      try {
        await Isolate.spawn(
          _espeakSynthIsolateMain,
          ready.sendPort,
          debugName: 'espeak_synth',
        );
        _commands = await ready.first as SendPort;
      } finally {
        ready.close();
      }
    }();
    try {
      await _starting;
    } catch (_) {
      _starting = null;
      rethrow;
    }
  }

  /// Speak [text] on the dedicated eSpeak isolate (one job at a time).
  static Future<ReferenceAudio> synthesize({
    required String text,
    required String language,
    AlignmentCancelToken? cancel,
  }) {
    final previous = _queue;
    final released = Completer<void>();
    _queue = released.future;
    return () async {
      await previous;
      try {
        return await _synthesizeUnlocked(
          text: text,
          language: language,
          cancel: cancel,
        );
      } finally {
        released.complete();
      }
    }();
  }

  static Future<ReferenceAudio> _synthesizeUnlocked({
    required String text,
    required String language,
    AlignmentCancelToken? cancel,
  }) async {
    await _ensureStarted();
    if (cancel?.isCancelled ?? false) {
      throw const SpokenReferenceException(
        reason: AlignmentFailureReason.cancelled,
        message: 'spoken reference cancelled',
      );
    }
    final id = _nextId++;
    final reply = ReceivePort();
    _commands!.send(
      _EspeakJob(
        id: id,
        reply: reply.sendPort,
        text: text,
        language: language,
        libraryPath: resolveEspeakLibraryPath(),
        dataPath: resolveEspeakDataPath(),
      ),
    );
    cancel?.onCancel(() {
      _commands?.send(_EspeakCancel(id));
    });
    try {
      final raw = await reply.first;
      if (raw is SpokenReferenceException) throw raw;
      if (raw is ReferenceAudio) return raw;
      throw SpokenReferenceException(
        message: 'unexpected synth payload ${raw.runtimeType}',
      );
    } finally {
      reply.close();
    }
  }
}
