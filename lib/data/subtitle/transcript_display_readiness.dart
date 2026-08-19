/// Pure karaoke / IPA / enrich gating from nested cues + extractability.
library;

import 'package:enjoy_player/data/subtitle/current_transcript_word.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/data/subtitle/transcript_word_ipa.dart';

/// Derived display capability for the current primary transcript.
class TranscriptDisplayReadiness {
  const TranscriptDisplayReadiness({
    required this.hasNestedWords,
    required this.hasTimedWords,
    required this.hasPhones,
    required this.canTrustWordTimes,
    required this.karaokeSwitchEnabled,
    required this.ipaSwitchEnabled,
    required this.showEnrich,
  });

  final bool hasNestedWords;
  final bool hasTimedWords;
  final bool hasPhones;
  final bool canTrustWordTimes;
  final bool karaokeSwitchEnabled;
  final bool ipaSwitchEnabled;
  final bool showEnrich;

  static const empty = TranscriptDisplayReadiness(
    hasNestedWords: false,
    hasTimedWords: false,
    hasPhones: false,
    canTrustWordTimes: false,
    karaokeSwitchEnabled: false,
    ipaSwitchEnabled: false,
    showEnrich: false,
  );
}

/// Computes gating flags. [lines] is the current **primary** track.
///
/// When [lines] is empty, [showEnrich] is false (empty-state import/ASR
/// handles that surface).
///
/// Owned / extractable media ([canTrustWordTimes]) still offers enrich when
/// nested words exist but karaoke or IPA cannot light up yet (untimed words
/// or missing phones). YouTube hides the tile once any nested words exist.
TranscriptDisplayReadiness transcriptDisplayReadiness({
  required List<TranscriptLine> lines,
  required bool canTrustWordTimes,
  bool trustResolved = true,
}) {
  if (lines.isEmpty) {
    return TranscriptDisplayReadiness(
      hasNestedWords: false,
      hasTimedWords: false,
      hasPhones: false,
      canTrustWordTimes: canTrustWordTimes,
      karaokeSwitchEnabled: false,
      ipaSwitchEnabled: false,
      showEnrich: false,
    );
  }

  var hasNestedWords = false;
  var hasTimedWords = false;
  var hasPhones = false;
  for (final line in lines) {
    final words = line.timeline;
    if (words == null || words.isEmpty) continue;
    hasNestedWords = true;
    if (words.any((w) => wordIpaSpelling(w) != null)) hasPhones = true;
    for (var i = 0; i < words.length; i++) {
      if (wordMediaWindowMs(line, i) != null) {
        hasTimedWords = true;
        break;
      }
    }
  }

  final enrichmentComplete = canTrustWordTimes
      ? hasTimedWords && hasPhones
      : hasNestedWords;

  return TranscriptDisplayReadiness(
    hasNestedWords: hasNestedWords,
    hasTimedWords: hasTimedWords,
    hasPhones: hasPhones,
    canTrustWordTimes: canTrustWordTimes,
    karaokeSwitchEnabled: hasTimedWords && canTrustWordTimes && trustResolved,
    ipaSwitchEnabled: hasPhones,
    showEnrich: !enrichmentComplete,
  );
}
