import 'dart:convert';
import 'dart:ffi';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:ffi/ffi.dart';
import 'package:logging/logging.dart';
import 'package:meta/meta.dart';

import '../constants.dart';
import '../failures.dart';
import '../language_map.dart';
import 'espeak_ng_bindings.dart';
import 'native_paths.dart';
import 'resample.dart';
import 'spoken_reference.dart';

final _log = Logger('forced_alignment');

bool? _ffiAvailableOverride;

/// Test harness: force [espeakFfiIsAvailable] without touching native files.
@visibleForTesting
void debugSetEspeakFfiAvailable(bool? value) {
  _ffiAvailableOverride = value;
}

/// Decodes eSpeak `id.string[8]` IPA bytes (UTF-8 with `espeakINITIALIZE_PHONEME_IPA`).
///
/// Must not use [String.fromCharCodes] on the raw bytes — that Latin-1-style
/// decode turns multi-byte IPA (e.g. `ɡ` `C9 A1`) into mojibake (`É¡`).
@visibleForTesting
String decodeEspeakPhonemeIdBytes(List<int> units) {
  if (units.isEmpty) return '';
  return utf8.decode(units, allowMalformed: true);
}

/// True when a vendored eSpeak-NG library and data directory can be opened.
bool espeakFfiIsAvailable() {
  if (_ffiAvailableOverride != null) return _ffiAvailableOverride!;
  try {
    return resolveEspeakLibraryPath() != null &&
        resolveEspeakDataPath() != null;
  } catch (_) {
    return false;
  }
}

final class _WordMark {
  _WordMark({
    required this.textPosition,
    required this.length,
    required this.audioMs,
  });

  final int textPosition;
  final int length;
  final int audioMs;
}

final class _PhoneMark {
  _PhoneMark({
    required this.phone,
    required this.audioMs,
    required this.textPosition,
  });

  final String phone;
  final int audioMs;
  final int textPosition;
}

/// Production spoken reference: eSpeak-NG `espeak_Synth` + WORD/PHONEME events.
final class EspeakNgSynthesizer implements SpokenReferenceSynthesizer {
  EspeakNgSynthesizer({this._isCancelled, this.phonemesOnly = false});

  final bool Function()? _isCancelled;

  /// When true, discard native PCM (YouTube IPA). Still runs `espeak_Synth`
  /// so WORD/PHONEME events arrive; does not copy samples onto the Dart heap.
  final bool phonemesOnly;

  static DynamicLibrary? _lib;
  static EspeakNgBindings? _bindings;
  static bool _initialized = false;
  static int _nativeSampleRate = 22050;
  static NativeCallable<EspeakCallbackNative>? _callable;
  static Int16List _pcm = Int16List(0);
  static int _pcmCount = 0;
  static bool _capturePcm = true;
  static final List<_WordMark> _words = <_WordMark>[];
  static final List<_PhoneMark> _phones = <_PhoneMark>[];
  static bool Function()? _cancelHook;

  static void _appendPcm(Pointer<Int16> wav, int n) {
    if (n <= 0) return;
    if (_pcmCount + n > _pcm.length) {
      final next = Int16List(math.max((_pcm.length * 2), _pcmCount + n));
      if (_pcmCount > 0) {
        next.setRange(0, _pcmCount, _pcm);
      }
      _pcm = next;
    }
    _pcm.setRange(_pcmCount, _pcmCount + n, wav.asTypedList(n));
    _pcmCount += n;
  }

  static int _onSynth(
    Pointer<Int16> wav,
    int numsamples,
    Pointer<EspeakEvent> events,
  ) {
    if (_cancelHook?.call() ?? false) return 1;
    if (_capturePcm && wav != nullptr && numsamples > 0) {
      _appendPcm(wav, numsamples);
    }
    if (events != nullptr) {
      for (var i = 0; i < 64; i++) {
        final event = events[i];
        if (event.type == espeakEventListTerminated) break;
        if (event.type == espeakEventWord) {
          _words.add(
            _WordMark(
              textPosition: event.textPosition,
              length: event.length,
              audioMs: event.audioPosition,
            ),
          );
        } else if (event.type == espeakEventPhoneme) {
          final phone = _readPhoneme(event);
          if (phone.isNotEmpty) {
            _phones.add(
              _PhoneMark(
                phone: phone,
                audioMs: event.audioPosition,
                textPosition: event.textPosition,
              ),
            );
          }
        }
      }
    }
    return 0;
  }

  static String _readPhoneme(EspeakEvent event) {
    final units = <int>[];
    for (var i = 0; i < 8; i++) {
      final b = event.idBytes[i];
      if (b == 0) break;
      units.add(b);
    }
    return decodeEspeakPhonemeIdBytes(units);
  }

  static EspeakNgBindings _open() {
    if (_bindings != null) return _bindings!;
    final path = resolveEspeakLibraryPath();
    final data = resolveEspeakDataPath();
    if (path == null || data == null) {
      throw const SpokenReferenceException(
        message: 'eSpeak-NG library or data directory missing',
      );
    }
    try {
      _lib = _openDynamicLibrary(path);
      _bindings = EspeakNgBindings(_lib!);
    } catch (e, st) {
      _log.warning('failed to open eSpeak-NG', e, st);
      throw SpokenReferenceException(message: 'failed to open $path');
    }
    return _bindings!;
  }

  static DynamicLibrary _openDynamicLibrary(String path) {
    try {
      return DynamicLibrary.open(path);
    } on Object catch (e, st) {
      if (Platform.isAndroid && path != kEspeakAndroidSoname) {
        _log.warning(
          'failed to open eSpeak-NG at $path; retrying Android soname',
          e,
          st,
        );
        return DynamicLibrary.open(kEspeakAndroidSoname);
      }
      rethrow;
    }
  }

  static void _ensureInitialized(EspeakNgBindings bindings) {
    if (_initialized) return;
    final data = resolveEspeakDataPath();
    if (data == null) {
      throw const SpokenReferenceException(message: 'eSpeak-NG data missing');
    }
    // espeak_Initialize path is the directory that *contains* espeak-ng-data.
    final parent = Directory(data).parent.path;
    final dataPtr = parent.toNativeUtf8();
    try {
      final rate = bindings.initialize(
        audioOutputSynchronous,
        0,
        dataPtr,
        espeakInitializePhonemeEvents |
            espeakInitializePhonemeIpa |
            espeakInitializeDontExit,
      );
      if (rate <= 0) {
        throw const SpokenReferenceException(
          message: 'espeak_Initialize failed',
        );
      }
      _nativeSampleRate = rate;
      _callable = NativeCallable<EspeakCallbackNative>.isolateLocal(
        _onSynth,
        exceptionalReturn: 1,
      );
      bindings.setSynthCallback(_callable!.nativeFunction);
      _initialized = true;
    } finally {
      malloc.free(dataPtr);
    }
  }

  @override
  ReferenceAudio synthesize({required String text, required String language}) {
    if (_ffiAvailableOverride == false) {
      throw const SpokenReferenceException(
        message: 'eSpeak-NG forced unavailable',
      );
    }
    final voice = espeakVoiceFor(language);
    if (voice == null) {
      throw const SpokenReferenceException(
        reason: AlignmentFailureReason.unsupportedLanguage,
        message: 'no spoken-reference voice',
      );
    }
    if (!espeakFfiIsAvailable()) {
      throw const SpokenReferenceException(
        message: 'eSpeak-NG library or data unavailable',
      );
    }

    final bindings = _open();
    _ensureInitialized(bindings);
    _cancelHook = _isCancelled;
    _capturePcm = !phonemesOnly;
    _pcmCount = 0;
    _words.clear();
    _phones.clear();

    final voicePtr = voice.toNativeUtf8();
    final textPtr = text.toNativeUtf8();
    try {
      final voiceStatus = bindings.setVoiceByName(voicePtr);
      if (voiceStatus != espeakOk) {
        throw SpokenReferenceException(
          message: 'espeak_SetVoiceByName($voice) failed',
        );
      }
      final status = bindings.synth(
        textPtr,
        textPtr.length + 1,
        0,
        0,
        0,
        espeakCharsUtf8,
        nullptr,
        nullptr,
      );
      if (status != espeakOk) {
        throw const SpokenReferenceException(message: 'espeak_Synth failed');
      }
      bindings.synchronize();
    } finally {
      malloc.free(voicePtr);
      malloc.free(textPtr);
      _cancelHook = null;
    }

    if (_isCancelled?.call() ?? false) {
      throw const SpokenReferenceException(
        reason: AlignmentFailureReason.cancelled,
        message: 'spoken reference cancelled',
      );
    }
    if (!phonemesOnly && _pcmCount <= 0) {
      throw const SpokenReferenceException(
        message: 'eSpeak-NG produced no PCM',
      );
    }

    if (phonemesOnly) {
      final duration = _eventDurationSeconds();
      final words = _buildWords(text, duration, requireWordEvents: false);
      return ReferenceAudio(
        pcm: Float32List(0),
        words: words,
        durationSeconds: duration,
      );
    }

    final floatNative = int16ToFloat32(_pcm.sublist(0, _pcmCount));
    final pcm = resampleToAlignmentRate(floatNative, _nativeSampleRate);
    final duration = pcm.length / kAlignmentSampleRate;
    final words = _buildWords(text, duration);
    return ReferenceAudio(pcm: pcm, words: words, durationSeconds: duration);
  }

  static double _eventDurationSeconds() {
    var maxMs = 0;
    for (final word in _words) {
      if (word.audioMs > maxMs) maxMs = word.audioMs;
    }
    for (final phone in _phones) {
      if (phone.audioMs > maxMs) maxMs = phone.audioMs;
    }
    if (maxMs <= 0) return 0.05;
    return maxMs / 1000.0;
  }

  static List<ReferenceWord> _buildWords(
    String text,
    double duration, {
    bool requireWordEvents = true,
  }) {
    if (_words.isEmpty) {
      final tokens = tokenizeWords(text);
      if (tokens.isEmpty) return const [];
      if (requireWordEvents) {
        throw const SpokenReferenceException(
          message: 'eSpeak-NG produced PCM but no word events',
        );
      }
      return _wordsFromTokenSpans(text, duration);
    }
    final tokens = tokenizeWords(text);
    final built = <ReferenceWord>[];
    for (var i = 0; i < _words.length; i++) {
      final mark = _words[i];
      final start = (mark.audioMs / 1000.0).clamp(0.0, duration);
      final endMs = i + 1 < _words.length
          ? _words[i + 1].audioMs
          : duration * 1000;
      final end = (endMs / 1000.0).clamp(start, duration);
      var label = _sliceText(text, mark.textPosition, mark.length);
      if (label.isEmpty && i < tokens.length) label = tokens[i];
      if (label.isEmpty) continue;
      final phones = <ReferencePhone>[];
      for (final phone in _phones) {
        final t = phone.audioMs / 1000.0;
        final nextStart = i + 1 < _words.length
            ? _words[i + 1].audioMs / 1000.0
            : duration + 1;
        if (t >= start && t < nextStart) {
          final pe = phones.isEmpty ? end : (t + 0.02).clamp(t, end);
          if (phones.isNotEmpty) {
            final prev = phones.removeLast();
            phones.add(
              ReferencePhone(
                phone: prev.phone,
                startTime: prev.startTime,
                endTime: t.clamp(prev.startTime, end),
                wordIndex: i,
              ),
            );
          }
          phones.add(
            ReferencePhone(
              phone: phone.phone,
              startTime: t.clamp(start, end),
              endTime: pe,
              wordIndex: i,
            ),
          );
        }
      }
      built.add(
        ReferenceWord(
          text: label,
          startTime: start,
          endTime: end,
          phones: phones,
        ),
      );
    }
    return built;
  }

  /// IPA-only fallback when eSpeak emitted phones but no WORD events.
  static List<ReferenceWord> _wordsFromTokenSpans(
    String text,
    double duration,
  ) {
    final spans = tokenizeWordSpans(text);
    if (spans.isEmpty) return const [];
    final phonesByWord = List<List<String>>.generate(
      spans.length,
      (_) => <String>[],
    );
    for (final phone in _phones) {
      var pos = phone.textPosition;
      if (pos >= 1) pos -= 1;
      var idx = 0;
      for (var i = 0; i < spans.length; i++) {
        if (pos >= spans[i].start && pos < spans[i].end) {
          idx = i;
          break;
        }
        if (pos >= spans[i].end) idx = i;
      }
      if (phone.phone.isNotEmpty) phonesByWord[idx].add(phone.phone);
    }
    return [
      for (var i = 0; i < spans.length; i++)
        ReferenceWord(
          text: spans[i].text,
          startTime: 0,
          endTime: duration,
          phones: [
            for (var p = 0; p < phonesByWord[i].length; p++)
              ReferencePhone(
                phone: phonesByWord[i][p],
                startTime: 0,
                endTime: duration,
                wordIndex: i,
              ),
          ],
        ),
    ];
  }

  static String _sliceText(String text, int position, int length) {
    if (length <= 0) return '';
    var start = position;
    if (start >= 1) start -= 1;
    start = start.clamp(0, text.length);
    final end = (start + length).clamp(start, text.length);
    if (end <= start) return '';
    return text.substring(start, end).trim();
  }
}

/// Production factory. Never [DurationModelSynthesizer].
SpokenReferenceSynthesizer createProductionSynthesizer({
  bool Function()? isCancelled,
}) {
  return EspeakNgSynthesizer(isCancelled: isCancelled);
}

/// True when [createProductionSynthesizer] is the eSpeak-NG implementation.
bool productionSynthesizerIsEspeakNg() =>
    createProductionSynthesizer() is EspeakNgSynthesizer;
