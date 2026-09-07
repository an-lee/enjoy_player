/// Strategy interface + dispatcher for subtitle formats.
library;

import 'package:enjoy_player/core/utils/duration_parsing.dart';
import 'package:enjoy_player/data/subtitle/subtitle_markup_parser.dart'
    show tagStripRegExp;
import 'transcript_line.dart';

/// Matches an SRT cue index line (digits only).
final RegExp _kSrtCueIndex = RegExp(r'^\d+$');

/// Matches an SRT timestamp arrow line (HH:MM:SS,mmm --> HH:MM:SS,mmm).
final RegExp _kSrtArrow = RegExp(
  r'(\d{1,2}:\d{2}:\d{2}[,.]\d{3})\s*-->\s*(\d{1,2}:\d{2}:\d{2}[,.]\d{3})',
);

/// Matches a VTT timestamp arrow line (with optional hours, MM:SS.mmm).
final RegExp _kVttArrow = RegExp(
  r'(\d{1,2}:)?(\d{2}):(\d{2})\.(\d{3})\s*-->\s*'
  r'(\d{1,2}:)?(\d{2}):(\d{2})\.(\d{3})',
);

/// Routes by filename extension or content sniffing.
class SubtitleParserFacade {
  const SubtitleParserFacade();

  static const SrtParser srt = SrtParser();
  static const VttParser vtt = VttParser();

  /// Strips ASS/SSA override tags like {\an8}, {\pos(...)}, {\c&H...&}, etc.
  static String stripAssTags(String text) =>
      text.replaceAll(RegExp(r'\{[^}]*\}'), '').trim();

  List<TranscriptLine> parseWithHint(String content, {String? fileName}) {
    final lower = fileName?.toLowerCase() ?? '';
    if (lower.endsWith('.vtt')) return vtt.parse(content);
    if (lower.endsWith('.srt')) return srt.parse(content);
    if (content.trimLeft().startsWith('WEBVTT')) return vtt.parse(content);
    return srt.parse(content);
  }

  List<TranscriptLine> parse(String content) =>
      parseWithHint(content, fileName: null);
}

/// Minimal SRT parser (supports multi-line cues and CRLF).
class SrtParser {
  const SrtParser();

  List<TranscriptLine> parse(String content) {
    final lines = content
        .replaceAll('\r\n', '\n')
        .replaceAll('\r', '\n')
        .split('\n');
    final cues = <TranscriptLine>[];
    var i = 0;
    while (i < lines.length) {
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      if (i >= lines.length) break;

      if (_kSrtCueIndex.hasMatch(lines[i].trim())) {
        i++;
      }
      if (i >= lines.length) break;

      final timeLine = lines[i];
      final arrowMatch = _kSrtArrow.firstMatch(timeLine);
      if (arrowMatch == null) {
        i++;
        continue;
      }
      final start = _parseTs(arrowMatch.group(1)!);
      final end = _parseTs(arrowMatch.group(2)!);
      i++;
      final textBuf = StringBuffer();
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (textBuf.isNotEmpty) textBuf.writeln();
        textBuf.write(lines[i]);
        i++;
      }
      final text = textBuf.toString().trim();
      if (text.isNotEmpty && end > start) {
        cues.add(
          TranscriptLine(text: text, startMs: start, durationMs: end - start),
        );
      }
    }
    cues.sort((a, b) => a.startMs.compareTo(b.startMs));
    return cues;
  }

  static int _parseTs(String raw) =>
      tryParseHmsDuration(raw)?.inMilliseconds ?? 0;
}

/// Minimal WebVTT cue parser (skips headers and NOTE regions).
class VttParser {
  const VttParser();

  List<TranscriptLine> parse(String content) {
    var text = content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
    if (text.startsWith('\uFEFF')) text = text.substring(1);

    final lines = text.split('\n');
    var i = 0;
    if (lines.isNotEmpty && lines[0].startsWith('WEBVTT')) {
      i = 1;
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        i++;
      }
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
    }

    final cues = <TranscriptLine>[];
    while (i < lines.length) {
      while (i < lines.length && lines[i].trim().isEmpty) {
        i++;
      }
      if (i >= lines.length) break;

      var line = lines[i];
      if (line.startsWith('NOTE') ||
          line.startsWith('STYLE') ||
          line.startsWith('REGION')) {
        i++;
        while (i < lines.length && lines[i].trim().isNotEmpty) {
          i++;
        }
        continue;
      }

      if (!line.contains('-->')) {
        i++;
        if (i >= lines.length) break;
        line = lines[i];
      }

      final arrowMatch = _kVttArrow.firstMatch(line);
      if (arrowMatch == null) {
        i++;
        continue;
      }

      final start = _parseVttTs(
        arrowMatch.group(1),
        arrowMatch.group(2)!,
        arrowMatch.group(3)!,
        arrowMatch.group(4)!,
      );
      final end = _parseVttTs(
        arrowMatch.group(5),
        arrowMatch.group(6)!,
        arrowMatch.group(7)!,
        arrowMatch.group(8)!,
      );

      i++;
      final textBuf = StringBuffer();
      while (i < lines.length && lines[i].trim().isNotEmpty) {
        if (textBuf.isNotEmpty) textBuf.writeln();
        textBuf.write(_stripTags(lines[i]));
        i++;
      }
      final cueText = textBuf.toString().trim();
      if (cueText.isNotEmpty && end > start) {
        cues.add(
          TranscriptLine(
            text: cueText,
            startMs: start,
            durationMs: end - start,
          ),
        );
      }
    }
    cues.sort((a, b) => a.startMs.compareTo(b.startMs));
    return cues;
  }

  static String _stripTags(String l) => l.replaceAll(tagStripRegExp, '').trim();

  static int _parseVttTs(String? hOpt, String mm, String ss, String ms) {
    final h = hOpt != null ? int.tryParse(hOpt.replaceAll(':', '')) ?? 0 : 0;
    return tryParseHmsDuration('$h:$mm:$ss.$ms')?.inMilliseconds ?? 0;
  }
}
