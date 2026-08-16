import 'dart:ffi';
import 'dart:io';

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
  _PhoneMark({required this.phone, required this.audioMs});

  final String phone;
  final int audioMs;
}

/// Production spoken reference: eSpeak-NG `espeak_Synth` + WORD/PHONEME events.
final class EspeakNgSynthesizer implements SpokenReferenceSynthesizer {
  EspeakNgSynthesizer({this._isCancelled});

  final bool Function()? _isCancelled;

  static DynamicLibrary? _lib;
  static EspeakNgBindings? _bindings;
  static bool _initialized = false;
  static int _nativeSampleRate = 22050;
  static NativeCallable<EspeakCallbackNative>? _callable;
  static final List<int> _pcm = <int>[];
  static final List<_WordMark> _words = <_WordMark>[];
  static final List<_PhoneMark> _phones = <_PhoneMark>[];
  static bool Function()? _cancelHook;

  static int _onSynth(
    Pointer<Int16> wav,
    int numsamples,
    Pointer<EspeakEvent> events,
  ) {
    if (_cancelHook?.call() ?? false) return 1;
    if (wav != nullptr && numsamples > 0) {
      _pcm.addAll(wav.asTypedList(numsamples));
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
            _phones.add(_PhoneMark(phone: phone, audioMs: event.audioPosition));
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
    if (units.isEmpty) return '';
    return String.fromCharCodes(units);
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
      _lib = DynamicLibrary.open(path);
      _bindings = EspeakNgBindings(_lib!);
    } catch (e, st) {
      _log.warning('failed to open eSpeak-NG', e, st);
      throw SpokenReferenceException(message: 'failed to open $path');
    }
    return _bindings!;
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
    _pcm.clear();
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
    if (_pcm.isEmpty) {
      throw const SpokenReferenceException(
        message: 'eSpeak-NG produced no PCM',
      );
    }

    final floatNative = int16ToFloat32(_pcm);
    final pcm = resampleToAlignmentRate(floatNative, _nativeSampleRate);
    final duration = pcm.length / kAlignmentSampleRate;
    final words = _buildWords(text, duration);
    return ReferenceAudio(pcm: pcm, words: words, durationSeconds: duration);
  }

  static List<ReferenceWord> _buildWords(String text, double duration) {
    if (_words.isEmpty) {
      final tokens = tokenizeWords(text);
      if (tokens.isEmpty) return const [];
      throw const SpokenReferenceException(
        message: 'eSpeak-NG produced PCM but no word events',
      );
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
