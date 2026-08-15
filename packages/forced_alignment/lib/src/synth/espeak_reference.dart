import 'dart:math' as math;
import 'dart:typed_data';

import '../constants.dart';

/// True when a native eSpeak-NG library can be loaded.
///
/// pub.dev `espeak` is phonemize-only today; waveform synth FFI lives in this
/// file when a host `libespeak-ng` is present. CI goldens skip otherwise.
bool espeakFfiIsAvailable() {
  try {
    return _tryOpenEspeakNg() != null;
  } catch (_) {
    return false;
  }
}

dynamic _tryOpenEspeakNg() {
  // Waveform `espeak_Synth` is not in pub.dev `espeak` 0.1.x. A future FFI
  // wrap can `DynamicLibrary.open` here without a second path package.
  return null;
}

final _wordPattern = RegExp(r"[\p{L}\p{N}']+", unicode: true);

/// Words in transcript order. Punctuation-only text yields an empty list.
List<String> tokenizeWords(String text) {
  return [
    for (final match in _wordPattern.allMatches(text))
      if (match.group(0)!.isNotEmpty) match.group(0)!,
  ];
}

/// Built-in G2P for fixtures + Latin fallback. eSpeak IPA replaces this when
/// [espeakFfiIsAvailable] and a phonemize wrap is wired.
List<String> phonesForWord(String word, String language) {
  final key = word.toLowerCase().replaceAll(
    RegExp(r'[^\p{L}\p{N}]', unicode: true),
    '',
  );
  if (key.isEmpty) return const [];
  const english = <String, List<String>>{
    'hello': ['h', 'ə', 'l', 'oʊ'],
    'world': ['w', 'ɜː', 'l', 'd'],
    'the': ['ð', 'ə'],
    'a': ['ə'],
  };
  if (language.startsWith('en') && english.containsKey(key)) {
    return english[key]!;
  }
  return [for (final rune in key.runes) String.fromCharCode(rune)];
}

final class ReferencePhone {
  const ReferencePhone({
    required this.phone,
    required this.startTime,
    required this.endTime,
    required this.wordIndex,
  });

  final String phone;
  final double startTime;
  final double endTime;
  final int wordIndex;
}

final class ReferenceWord {
  const ReferenceWord({
    required this.text,
    required this.startTime,
    required this.endTime,
    required this.phones,
  });

  final String text;
  final double startTime;
  final double endTime;
  final List<ReferencePhone> phones;
}

final class ReferenceAudio {
  const ReferenceAudio({
    required this.pcm,
    required this.words,
    required this.durationSeconds,
  });

  final Float32List pcm;
  final List<ReferenceWord> words;
  final double durationSeconds;
}

/// Deterministic reference waveform (tone bursts per phone) stretched to
/// [durationSeconds]. Real eSpeak PCM replaces this when FFI synth lands.
final class DurationModelSynthesizer {
  const DurationModelSynthesizer();

  ReferenceAudio synthesize({
    required String text,
    required String language,
    required double durationSeconds,
  }) {
    final duration = math.max(durationSeconds, kMinAudioSeconds);
    final n = math.max(1, (duration * kAlignmentSampleRate).round());
    final pcm = Float32List(n);
    final tokens = tokenizeWords(text);
    if (tokens.isEmpty) {
      return ReferenceAudio(
        pcm: pcm,
        words: const [],
        durationSeconds: duration,
      );
    }
    final words = <ReferenceWord>[];
    final slot = duration / tokens.length;
    for (var w = 0; w < tokens.length; w++) {
      final start = w * slot;
      final end = (w + 1) * slot;
      final phones = phonesForWord(tokens[w], language);
      final labels = phones.isEmpty ? [tokens[w]] : phones;
      final phoneDur = (end - start) / labels.length;
      final mapped = <ReferencePhone>[];
      for (var p = 0; p < labels.length; p++) {
        final ps = start + p * phoneDur;
        final pe = start + (p + 1) * phoneDur;
        mapped.add(
          ReferencePhone(
            phone: labels[p],
            startTime: ps,
            endTime: pe,
            wordIndex: w,
          ),
        );
        _writeTone(pcm, ps, pe, _freqFor(labels[p]));
      }
      words.add(
        ReferenceWord(
          text: tokens[w],
          startTime: start,
          endTime: end,
          phones: mapped,
        ),
      );
    }
    return ReferenceAudio(pcm: pcm, words: words, durationSeconds: duration);
  }
}

void _writeTone(Float32List pcm, double startSec, double endSec, double hz) {
  final start = (startSec * kAlignmentSampleRate).floor().clamp(0, pcm.length);
  final end = (endSec * kAlignmentSampleRate).ceil().clamp(0, pcm.length);
  for (var i = start; i < end; i++) {
    pcm[i] = 0.18 * math.sin(2 * math.pi * hz * i / kAlignmentSampleRate);
  }
}

double _freqFor(String phone) {
  final h = phone.hashCode.abs();
  return 180.0 + (h % 520);
}
