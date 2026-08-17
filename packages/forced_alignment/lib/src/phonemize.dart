/// Text-only IPA labels from eSpeak (no source-audio alignment).
library;

import 'package:flutter/foundation.dart';

import 'failures.dart';
import 'language_map.dart';
import 'request.dart';
import 'synth/espeak_synth_host.dart';
import 'synth/spoken_reference.dart';

/// One token with IPA labels and no media-timeline clocks.
final class PhonemeWord {
  const PhonemeWord({required this.text, required this.phones});

  final String text;
  final List<String> phones;
}

/// Phonemize result for one caption line.
final class PhonemizeLineResult {
  const PhonemizeLineResult({required this.words});

  final List<PhonemeWord> words;
}

sealed class PhonemizeOutcome {
  const PhonemizeOutcome();
}

final class PhonemizeSuccess extends PhonemizeOutcome {
  const PhonemizeSuccess(this.lines);

  final List<PhonemizeLineResult> lines;
}

final class PhonemizeFailed extends PhonemizeOutcome {
  const PhonemizeFailed(this.failure);

  final AlignmentFailure failure;
}

/// Pronounces [texts] line-by-line via the spoken-reference synthesizer.
///
/// Discards reference PCM. Does not call [align] / [alignSegments].
Future<PhonemizeOutcome> phonemizeLines({
  required List<String> texts,
  required String language,
  AlignmentCancelToken? cancel,
  @visibleForTesting
  Future<ReferenceAudio> Function({
    required String text,
    required String language,
    AlignmentCancelToken? cancel,
  })?
  synthesize,
}) async {
  if (!isSupportedAlignmentLanguage(language)) {
    return const PhonemizeFailed(
      AlignmentFailure(reason: AlignmentFailureReason.unsupportedLanguage),
    );
  }
  if (texts.every((t) => tokenizeWords(t).isEmpty)) {
    return PhonemizeSuccess([
      for (final _ in texts) const PhonemizeLineResult(words: []),
    ]);
  }

  final out = <PhonemizeLineResult>[];
  for (final text in texts) {
    if (cancel?.isCancelled ?? false) {
      return const PhonemizeFailed(
        AlignmentFailure(reason: AlignmentFailureReason.cancelled),
      );
    }
    final tokens = tokenizeWords(text);
    if (tokens.isEmpty) {
      out.add(const PhonemizeLineResult(words: []));
      continue;
    }
    try {
      final audio = synthesize != null
          ? await synthesize(text: text, language: language, cancel: cancel)
          : await EspeakSynthHost.synthesize(
              text: text,
              language: language,
              cancel: cancel,
            );
      out.add(
        PhonemizeLineResult(
          words: [
            for (final word in audio.words)
              if (word.text.trim().isNotEmpty)
                PhonemeWord(
                  text: word.text.trim(),
                  phones: [
                    for (final phone in word.phones)
                      if (phone.phone.trim().isNotEmpty) phone.phone.trim(),
                  ],
                ),
          ],
        ),
      );
    } on SpokenReferenceException catch (e) {
      if (e.reason == AlignmentFailureReason.cancelled) {
        return PhonemizeFailed(e.toFailure());
      }
      // Leave this cue line-only; other lines may still phonemize.
      out.add(const PhonemizeLineResult(words: []));
    }
  }
  return PhonemizeSuccess(out);
}
