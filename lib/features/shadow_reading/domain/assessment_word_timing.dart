/// Pure timing helpers for assessment karaoke + word clips.
///
/// Azure Speech stores [AzureWordAssessment.offset] / [duration] as
/// 100-nanosecond ticks (not milliseconds).
library;

import 'package:azure_speech/azure_speech.dart';

/// Converts Azure 100-nanosecond ticks to whole milliseconds.
int azureTicksToMs(int ticks) {
  if (ticks <= 0) return 0;
  return (ticks / 10000).round();
}

/// Whether [word] has a usable take interval for clip playback / karaoke.
///
/// Omissions and zero-duration words are not clip-eligible.
bool isWordClipUsable(AzureWordAssessment word) {
  if (word.duration <= 0) return false;
  final err = word.pronunciationAssessment.errorType;
  if (err == 'Omission') return false;
  return true;
}

/// Index of the timed word whose interval contains [positionMs], or null.
///
/// Skips words that are not [isWordClipUsable]. When [positionMs] falls in a
/// gap between usable words, returns null (no invented current word).
int? activeWordIndex(List<AzureWordAssessment> words, int positionMs) {
  if (positionMs < 0 || words.isEmpty) return null;
  for (var i = 0; i < words.length; i++) {
    final w = words[i];
    if (!isWordClipUsable(w)) continue;
    final start = azureTicksToMs(w.offset);
    final end = start + azureTicksToMs(w.duration);
    if (positionMs >= start && positionMs < end) {
      return i;
    }
  }
  return null;
}

/// Start/end [Duration] for a word clip, or null when unusable.
({Duration start, Duration end})? wordClipBounds(AzureWordAssessment word) {
  if (!isWordClipUsable(word)) return null;
  final startMs = azureTicksToMs(word.offset);
  final endMs = startMs + azureTicksToMs(word.duration);
  if (endMs <= startMs) return null;
  return (
    start: Duration(milliseconds: startMs),
    end: Duration(milliseconds: endMs),
  );
}
