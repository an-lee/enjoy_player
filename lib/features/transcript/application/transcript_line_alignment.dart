/// Aligns primary transcript cues with a secondary track for bilingual UI.
library;

import 'package:enjoy_player/data/subtitle/subtitle_markup_parser.dart';
import 'package:enjoy_player/data/subtitle/transcript_line.dart';
import 'package:enjoy_player/features/player/application/echo_mode_provider.dart';

/// Fast matcher for [transcriptMatchSecondary] when many primaries are resolved
/// against the same [secondary] list (e.g. virtualized transcript rows).
///
/// [secondary] is copied and sorted by [TranscriptLine.startSeconds] once.
class TranscriptSecondaryMatcher {
  factory TranscriptSecondaryMatcher.from(List<TranscriptLine> secondary) {
    if (secondary.isEmpty) {
      return TranscriptSecondaryMatcher._(const []);
    }
    final copy = List<TranscriptLine>.from(secondary)
      ..sort((a, b) => a.startSeconds.compareTo(b.startSeconds));
    return TranscriptSecondaryMatcher._(copy);
  }
  TranscriptSecondaryMatcher._(this._sec);

  /// Sorted by [TranscriptLine.startSeconds] ascending.
  final List<TranscriptLine> _sec;

  /// Last secondary cue with [TranscriptLine.startSeconds] strictly less than [pEnd].
  TranscriptLine? _lastWithStartBefore(double pEnd) {
    if (_sec.isEmpty) return null;
    var lo = 0;
    var hi = _sec.length - 1;
    var ans = -1;
    while (lo <= hi) {
      final mid = (lo + hi) ~/ 2;
      if (_sec[mid].startSeconds < pEnd) {
        ans = mid;
        lo = mid + 1;
      } else {
        hi = mid - 1;
      }
    }
    return ans < 0 ? null : _sec[ans];
  }

  /// Same semantics as [transcriptMatchSecondary] for a single primary line.
  TranscriptLine? match(TranscriptLine primary) {
    if (_sec.isEmpty) return null;
    final pStart = primary.startSeconds;
    final pEnd = primary.endSeconds;

    for (final s in _sec) {
      if (s.startSeconds >= pEnd) break;
      final mid = s.startSeconds + (s.endSeconds - s.startSeconds) / 2;
      if (mid >= pStart && mid < pEnd) return s;
    }

    return _lastWithStartBefore(pEnd);
  }
}

/// Secondary line whose midpoint falls within [primary]'s range, else nearest.
TranscriptLine? transcriptMatchSecondary(
  TranscriptLine primary,
  List<TranscriptLine> secondary, {
  TranscriptSecondaryMatcher? matcher,
}) {
  final m = matcher ?? TranscriptSecondaryMatcher.from(secondary);
  return m.match(primary);
}

String echoReferencePlainText(List<TranscriptLine> lines, EchoState echo) {
  if (!echo.active) return '';
  final start = echo.startLineIndex;
  final end = echo.endLineIndex;
  if (start < 0 || end < 0 || start > end) return '';
  final parts = <String>[];
  for (var i = start; i <= end && i < lines.length; i++) {
    final plain = lines[i].text.replaceAll(tagStripRegExp, '').trim();
    if (plain.isNotEmpty) parts.add(plain);
  }
  return parts.join(' ');
}
