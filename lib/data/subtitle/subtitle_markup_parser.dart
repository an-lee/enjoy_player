/// Parses common SSA/ASS/HTML-like subtitle markup into plain segments with style hints.
///
/// Handles `<font color="...">`, `<b>`, `<strong>`, `<i>`, `<em>`, `<u>`, `<br>`, and strips
/// other tags while keeping inner text. No Flutter imports — safe for tests and data layer.
library;

import 'package:enjoy_player/core/utils/text_normalization.dart';

/// One contiguous substring with resolved inline style (stacked tags flattened).
class SubtitleTextSegment {
  const SubtitleTextSegment(
    this.text, {
    this.colorArgb,
    this.bold = false,
    this.italic = false,
    this.underline = false,
  });

  final String text;
  final int? colorArgb;
  final bool bold;
  final bool italic;
  final bool underline;
}

class _StyleFrame {
  const _StyleFrame({
    required this.colorArgb,
    required this.bold,
    required this.italic,
    required this.underline,
  });

  final int? colorArgb;
  final bool bold;
  final bool italic;
  final bool underline;

  _StyleFrame mergeWith({
    int? colorArgb,
    bool? bold,
    bool? italic,
    bool? underline,
  }) {
    return _StyleFrame(
      colorArgb: colorArgb ?? this.colorArgb,
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
    );
  }
}

/// Regex matching `<...>` subtitle markup tags (SSA/HTML-like inline tags).
///
/// Exposed for reuse across transcript / lookup consumers so the same pattern
/// is not recompiled per call site.
final tagStripRegExp = RegExp(r'<[^>]*>');

/// Regex matching runs of whitespace (used to normalize spacing in cue text).
///
/// Exposed for reuse across transcript / lookup consumers so the same pattern
/// is not recompiled per call site.
final whitespaceSplitRegExp = whitespaceRunRegExp;

final _parseCache = <String, List<SubtitleTextSegment>>{};
const _maxParseCacheSize = 256;

/// Plain text with markup tags removed (preserves inner text and `<br>` breaks).
String plainTextFromSubtitleMarkup(String input) {
  final segments = parseSubtitleMarkup(input);
  if (segments.isEmpty) {
    final plain = input.replaceAll(tagStripRegExp, '').trim();
    return plain.isEmpty ? input.trim() : plain;
  }
  return segments.map((s) => s.text).join().trim();
}

/// Parses [input] into styled segments for rich text rendering.
List<SubtitleTextSegment> parseSubtitleMarkup(String input) {
  if (input.isEmpty) return const [];

  final cached = _parseCache[input];
  if (cached != null) return cached;

  final out = <SubtitleTextSegment>[];
  final stack = <_StyleFrame>[
    const _StyleFrame(
      colorArgb: null,
      bold: false,
      italic: false,
      underline: false,
    ),
  ];

  final buf = StringBuffer();

  void flush() {
    if (buf.isEmpty) return;
    final raw = buf.toString();
    buf.clear();
    final top = stack.last;
    if (raw.isEmpty) return;
    out.add(
      SubtitleTextSegment(
        raw,
        colorArgb: top.colorArgb,
        bold: top.bold,
        italic: top.italic,
        underline: top.underline,
      ),
    );
  }

  var i = 0;
  while (i < input.length) {
    if (input[i] == '&') {
      final semi = input.indexOf(';', i);
      if (semi > i) {
        buf.write(_decodeEntityAt(input, i, semi));
        i = semi + 1;
        continue;
      }
      buf.write('&');
      i++;
      continue;
    }
    if (input[i] != '<') {
      buf.write(input[i]);
      i++;
      continue;
    }

    final close = input.indexOf('>', i);
    if (close == -1) {
      buf.write('<');
      i++;
      continue;
    }

    final tagRaw = input.substring(i + 1, close).trim();
    flush();
    i = close + 1;

    if (tagRaw.isEmpty) continue;

    final isClosing = tagRaw.startsWith('/');
    final tagInner = isClosing ? tagRaw.substring(1).trim() : tagRaw;
    final tagLower = tagInner.toLowerCase();
    final firstToken = tagLower.split(whitespaceSplitRegExp).first;

    if (!isClosing) {
      if (firstToken == 'br') {
        buf.write('\n');
        continue;
      }
      if (firstToken == 'font') {
        final color = _extractColorAttribute(tagInner);
        final p = stack.last;
        stack.add(
          _StyleFrame(
            colorArgb: color ?? p.colorArgb,
            bold: p.bold,
            italic: p.italic,
            underline: p.underline,
          ),
        );
        continue;
      }
      if (firstToken == 'b' || firstToken == 'strong') {
        final p = stack.last;
        stack.add(p.mergeWith(bold: true));
        continue;
      }
      if (firstToken == 'i' || firstToken == 'em') {
        final p = stack.last;
        stack.add(p.mergeWith(italic: true));
        continue;
      }
      if (firstToken == 'u') {
        final p = stack.last;
        stack.add(p.mergeWith(underline: true));
        continue;
      }
      continue;
    }

    if (firstToken == 'font' ||
        firstToken == 'b' ||
        firstToken == 'strong' ||
        firstToken == 'i' ||
        firstToken == 'em' ||
        firstToken == 'u') {
      if (stack.length > 1) stack.removeLast();
    }
  }

  flush();

  final result = _mergeAdjacentSameStyle(out);
  if (_parseCache.length >= _maxParseCacheSize) {
    _parseCache.remove(_parseCache.keys.first);
  }
  _parseCache[input] = result;
  return result;
}

/// Decodes `&...;` between [start] and [semi] (inclusive of semicolon at [semi]).
String _decodeEntityAt(String input, int start, int semi) {
  final entity = input.substring(start, semi + 1);
  switch (entity) {
    case '&amp;':
      return '&';
    case '&lt;':
      return '<';
    case '&gt;':
      return '>';
    case '&quot;':
      return '"';
    case '&apos;':
      return "'";
    default:
      if (entity.startsWith('&#x')) {
        final hex = entity.substring(3, entity.length - 1);
        final code = int.tryParse(hex, radix: 16);
        if (code != null) return String.fromCharCode(code);
      } else if (entity.startsWith('&#')) {
        final dec = entity.substring(2, entity.length - 1);
        final code = int.tryParse(dec);
        if (code != null) return String.fromCharCode(code);
      }
      return entity;
  }
}

final _colorAttrRegExp = RegExp(
  r'''color\s*=\s*["']([^"']+)["']''',
  caseSensitive: false,
);

int? _extractColorAttribute(String tagInner) {
  final m = _colorAttrRegExp.firstMatch(tagInner);
  if (m == null) return null;
  return parseSubtitleColorToArgb(m.group(1)!);
}

/// Converts SSA/HTML color strings to 0xAARRGGBB or null if unknown.
int? parseSubtitleColorToArgb(String raw) {
  final t = raw.trim().toLowerCase();
  if (t.startsWith('#')) {
    var hex = t.substring(1);
    if (hex.length == 3) {
      hex = hex.split('').map((c) => '$c$c').join();
    }
    if (hex.length == 8) {
      return int.parse(hex, radix: 16);
    }
    if (hex.length == 6) {
      return int.parse(hex, radix: 16) | 0xFF000000;
    }
  }

  const named = <String, int>{
    'white': 0xFFFFFFFF,
    'black': 0xFF000000,
    'red': 0xFFFF0000,
    'green': 0xFF008000,
    'blue': 0xFF0000FF,
    'yellow': 0xFFFFFF00,
    'cyan': 0xFF00FFFF,
    'magenta': 0xFFFF00FF,
    'silver': 0xFFC0C0C0,
    'gray': 0xFF808080,
    'grey': 0xFF808080,
    'lime': 0xFF00FF00,
    'navy': 0xFF000080,
    'teal': 0xFF008080,
    'aqua': 0xFF00FFFF,
    'maroon': 0xFF800000,
    'olive': 0xFF808000,
    'orange': 0xFFFFA500,
  };
  return named[t];
}

List<SubtitleTextSegment> _mergeAdjacentSameStyle(
  List<SubtitleTextSegment> segments,
) {
  if (segments.isEmpty) return segments;
  final merged = <SubtitleTextSegment>[segments.first];
  for (var i = 1; i < segments.length; i++) {
    final prev = merged.last;
    final cur = segments[i];
    if (prev.colorArgb == cur.colorArgb &&
        prev.bold == cur.bold &&
        prev.italic == cur.italic &&
        prev.underline == cur.underline) {
      merged[merged.length - 1] = SubtitleTextSegment(
        prev.text + cur.text,
        colorArgb: prev.colorArgb,
        bold: prev.bold,
        italic: prev.italic,
        underline: prev.underline,
      );
    } else {
      merged.add(cur);
    }
  }
  return merged;
}
