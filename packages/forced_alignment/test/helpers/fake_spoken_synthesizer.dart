import 'dart:math' as math;
import 'dart:typed_data';

import 'package:forced_alignment/forced_alignment.dart';

/// Test double: speech-like tone bursts + IPA phones (not letter-split).
///
/// Duration is chosen by the double, not the source clip.
final class FakeSpokenSynthesizer implements SpokenReferenceSynthesizer {
  const FakeSpokenSynthesizer({this.durationSeconds = 2.0});

  final double durationSeconds;

  static const _ipa = <String, List<String>>{
    'hello': ['h', 'ə', 'l', 'oʊ'],
    'world': ['w', 'ɜː', 'l', 'd'],
    'the': ['ð', 'ə'],
    'a': ['ə'],
  };

  @override
  ReferenceAudio synthesize({required String text, required String language}) {
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
      final key = tokens[w].toLowerCase();
      final labels = _ipa[key] ?? ['ə'];
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

/// Unavailable spoken voice for fail-closed harnesses.
final class UnavailableSpokenSynthesizer implements SpokenReferenceSynthesizer {
  const UnavailableSpokenSynthesizer();

  @override
  ReferenceAudio synthesize({required String text, required String language}) {
    throw const SpokenReferenceException(
      message: 'spoken reference disabled by test harness',
    );
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
