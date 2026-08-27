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

/// One eSpeak `espeak_EVENT_WORD` mark.
///
/// [textPosition] is 1-based and [length] counts source characters, but
/// eSpeak does not emit one event per orthographic token: function words can
/// be swallowed (no event), expansions can emit several events with shifted
/// positions (`77` → "seventy seven"), and some events report `length == 0`.
/// Display labels never come from these fields; they only carry timing.
final class EspeakWordEvent {
  const EspeakWordEvent({
    required this.textPosition,
    required this.length,
    required this.audioMs,
  });

  final int textPosition;
  final int length;
  final int audioMs;
}

/// One eSpeak `espeak_EVENT_PHONEME` mark.
final class EspeakPhoneEvent {
  const EspeakPhoneEvent({
    required this.phone,
    required this.audioMs,
    required this.textPosition,
  });

  final String phone;
  final int audioMs;
  final int textPosition;
}

/// Zero-based token index for each eSpeak word event, in event order.
///
/// Events map onto [spans] — the app's tokenizer output, which stays the
/// authoritative orthography. Each event takes the nearest span it has not
/// already passed, so swallowed-word neighbours keep their own events,
/// expansion duplicates (`77` + `7`) collapse onto one token, and stale or
/// zero-length events land on the token they were spoken for.
@visibleForTesting
List<int> mapWordEventsToTokenSpans(List<WordSpan> spans, List<int> positions) {
  if (spans.isEmpty) return const <int>[];
  final owners = List<int>.filled(positions.length, 0);
  var cursor = 0;
  for (var i = 0; i < positions.length; i++) {
    final position = math.max(0, math.min(spans.last.end, positions[i]));
    var best = cursor;
    var bestDistance = _distanceToSpan(spans[best], position);
    for (var t = cursor + 1; t < spans.length; t++) {
      final distance = _distanceToSpan(spans[t], position);
      if (distance < bestDistance) {
        bestDistance = distance;
        best = t;
      }
      if (spans[t].start > position) break;
    }
    owners[i] = best;
    cursor = best;
  }
  return owners;
}

int _distanceToSpan(WordSpan span, int position) {
  if (position >= span.start && position < span.end) return 0;
  if (position < span.start) return span.start - position;
  return position - (span.end - 1);
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
  static final List<EspeakWordEvent> _words = <EspeakWordEvent>[];
  static final List<EspeakPhoneEvent> _phones = <EspeakPhoneEvent>[];
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
            EspeakWordEvent(
              textPosition: event.textPosition,
              length: event.length,
              audioMs: event.audioPosition,
            ),
          );
        } else if (event.type == espeakEventPhoneme) {
          final phone = _readPhoneme(event);
          if (phone.isNotEmpty) {
            _phones.add(
              EspeakPhoneEvent(
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
    return buildWords(
      text: text,
      duration: duration,
      wordEvents: _words,
      phoneEvents: _phones,
      requireWordEvents: requireWordEvents,
    );
  }

  /// Reference words for [text], one per [tokenizeWordSpans] span.
  ///
  /// Spans are the authoritative orthography: eSpeak word events only
  /// contribute timing (mapped back onto spans by [mapWordEventsToTokenSpans]),
  /// so swallowed words, numeral expansions, and hyphenated compounds can
  /// never change the displayed word sequence (issue #621).
  ///
  /// Each token's span tiles the reference audio: a token owning events keeps
  /// the audio up to the next owned event; tokens without an event share the
  /// surrounding region proportionally by length so every source word stays
  /// visible with a usable window. Phones attach by audio time within the
  /// token's span.
  @visibleForTesting
  static List<ReferenceWord> buildWords({
    required String text,
    required double duration,
    required List<EspeakWordEvent> wordEvents,
    required List<EspeakPhoneEvent> phoneEvents,
    bool requireWordEvents = true,
  }) {
    final spans = tokenizeWordSpans(text);
    if (spans.isEmpty) return const [];
    if (wordEvents.isEmpty) {
      if (requireWordEvents) {
        throw const SpokenReferenceException(
          message: 'eSpeak-NG produced PCM but no word events',
        );
      }
      return _wordsFromTokenSpans(text, duration);
    }

    final owners = mapWordEventsToTokenSpans(spans, [
      for (final event in wordEvents)
        math.max(0, math.min(text.length, event.textPosition - 1)),
    ]);

    final firstEvent = List<int?>.filled(spans.length, null);
    for (var k = 0; k < owners.length; k++) {
      firstEvent[owners[k]] ??= k;
    }
    final claimed = <int>[
      for (var t = 0; t < spans.length; t++)
        if (firstEvent[t] != null) t,
    ];
    final eventStartSec = <double>[
      for (final event in wordEvents)
        (event.audioMs / 1000.0).clamp(0.0, duration),
    ];

    final starts = List<double>.filled(spans.length, 0);
    final ends = List<double>.filled(spans.length, 0);
    _distributeRegion(
      spans,
      starts,
      ends,
      0,
      claimed.first,
      0,
      eventStartSec[firstEvent[claimed.first]!],
    );
    for (var g = 0; g < claimed.length; g++) {
      final token = claimed[g];
      final regionEnd = g + 1 < claimed.length
          ? eventStartSec[firstEvent[claimed[g + 1]]!]
          : duration;
      _distributeRegion(
        spans,
        starts,
        ends,
        token,
        g + 1 < claimed.length ? claimed[g + 1] : spans.length,
        eventStartSec[firstEvent[token]!],
        regionEnd,
      );
    }

    final phonesByToken = _phonesByToken(phoneEvents, starts, ends);
    return [
      for (var t = 0; t < spans.length; t++)
        ReferenceWord(
          text: spans[t].text,
          startTime: starts[t],
          endTime: ends[t],
          phones: _phonesForSpan(phonesByToken[t], starts[t], ends[t], t),
        ),
    ];
  }

  /// Assign tokens `[startToken, endToken)` a share of
  /// `[regionStart, regionEnd)`.
  ///
  /// A lone token keeps the whole region (the previous
  /// word-end = next-event-start convention); a run of event-less tokens
  /// shares it proportionally by token length.
  static void _distributeRegion(
    List<WordSpan> spans,
    List<double> starts,
    List<double> ends,
    int startToken,
    int endToken,
    double regionStart,
    double regionEnd,
  ) {
    if (endToken <= startToken) return;
    if (endToken - startToken == 1) {
      starts[startToken] = regionStart;
      ends[startToken] = regionEnd;
      return;
    }
    final totalLength = regionEnd - regionStart;
    final weights = [
      for (var t = startToken; t < endToken; t++) spans[t].text.length,
    ];
    final weightSum = weights.fold<int>(0, (a, b) => a + b);
    var cursor = regionStart;
    for (var t = startToken; t < endToken; t++) {
      final share = weightSum <= 0
          ? totalLength / (endToken - startToken)
          : totalLength * weights[t - startToken] / weightSum;
      starts[t] = cursor;
      cursor += share;
      ends[t] = t + 1 == endToken ? regionEnd : cursor;
    }
  }

  /// Chronological phone marks bucketed by the token whose span contains them.
  static List<List<EspeakPhoneEvent>> _phonesByToken(
    List<EspeakPhoneEvent> phoneEvents,
    List<double> starts,
    List<double> ends,
  ) {
    final buckets = List<List<EspeakPhoneEvent>>.generate(
      starts.length,
      (_) => <EspeakPhoneEvent>[],
    );
    if (buckets.isEmpty) return buckets;
    var cursor = 0;
    for (final event in phoneEvents) {
      final time = event.audioMs / 1000.0;
      while (cursor + 1 < buckets.length && time >= ends[cursor]) {
        cursor++;
      }
      buckets[cursor].add(event);
    }
    return buckets;
  }

  /// Phone spans for one token, preserving the previous shape: the first
  /// phone reaches the token end and each mark closes the previous one.
  static List<ReferencePhone> _phonesForSpan(
    List<EspeakPhoneEvent> events,
    double start,
    double end,
    int wordIndex,
  ) {
    final phones = <ReferencePhone>[];
    for (final event in events) {
      final t = (event.audioMs / 1000.0).clamp(start, end);
      final pe = phones.isEmpty ? end : (t + 0.02).clamp(t, end);
      if (phones.isNotEmpty) {
        final prev = phones.removeLast();
        phones.add(
          ReferencePhone(
            phone: prev.phone,
            startTime: prev.startTime,
            endTime: t.clamp(prev.startTime, end),
            wordIndex: wordIndex,
          ),
        );
      }
      phones.add(
        ReferencePhone(
          phone: event.phone,
          startTime: t,
          endTime: pe,
          wordIndex: wordIndex,
        ),
      );
    }
    return phones;
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
