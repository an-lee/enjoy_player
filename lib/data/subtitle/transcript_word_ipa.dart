/// Stored-phone pronunciation helpers (no Flutter, no invented IPA).
library;

import 'package:enjoy_player/data/subtitle/transcript_line.dart';

/// Ordered non-empty [TranscriptPhone.phone] labels for [word].
List<String> wordIpaPieces(TranscriptWord word) {
  final phones = word.phones;
  if (phones == null || phones.isEmpty) return const [];
  return [
    for (final phone in phones)
      if (phone.phone.trim().isNotEmpty) phone.phone.trim(),
  ];
}

/// Concatenated stored pronunciation for overlay, or null when none.
String? wordIpaSpelling(TranscriptWord word) {
  final pieces = wordIpaPieces(word);
  if (pieces.isEmpty) return null;
  return pieces.join();
}
