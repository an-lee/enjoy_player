/// Captured eSpeak-NG word events for issue #621 cues and edge-case
/// sentences, recorded verbatim from the vendored library.
library;

import 'package:forced_alignment/src/synth/espeak_ng_synthesizer.dart';

/// One synthesized cue with its en-US word events (textPosition, length,
/// audioMs) and the reference duration the tests assume.
final class CapturedCue {
  const CapturedCue(this.text, this.durationSeconds, this.events);

  final String text;
  final double durationSeconds;
  final List<(int, int, int)> events;
}

/// Issue #621 cue 1: swallowed articles and `Manhattan`.
const cueArticles = CapturedCue(
  'One of the pictures hanging in my office in mid-Manhattan is a '
  'photograph of the writer E. B. White.',
  5.0,
  [
    (1, 3, 0),
    (5, 2, 165),
    (12, 8, 420),
    (21, 7, 929),
    (29, 2, 1236),
    (32, 2, 1411),
    (35, 6, 1512),
    (42, 2, 1861),
    (45, 3, 1980),
    (59, 2, 2703),
    (62, 1, 2819),
    (64, 10, 2874),
    (75, 2, 3431),
    (82, 6, 3660),
    (89, 1, 3951),
    (92, 1, 4128),
    (95, 5, 4357),
  ],
);

/// Issue #621 cue 2: `77` expands into two shifted events.
const cueNumeral = CapturedCue(
  'It was taken by Jill Krementz when White was 77 years old, at his home '
  'in North Brooklin, Maine.',
  6.5,
  [
    (1, 2, 0),
    (4, 3, 146),
    (8, 5, 345),
    (14, 2, 768),
    (17, 4, 905),
    (22, 8, 1166),
    (31, 4, 1713),
    (36, 5, 1887),
    (42, 3, 2160),
    (46, 2, 2368),
    (47, 2, 2848),
    (49, 5, 3215),
    (55, 3, 3517),
    (60, 2, 4056),
    (63, 3, 4213),
    (67, 4, 4421),
    (72, 2, 4626),
    (75, 5, 4780),
    (81, 8, 5079),
    (91, 5, 5695),
  ],
);

/// Issue #621 cue 3: hyphens, em-dashes, and two `length == 0` events.
const cueHyphens = CapturedCue(
  'A white-haired man is sitting on a plain wooden bench at a plain wooden '
  'table—three boards nailed to four legs—in a small boathouse.',
  7.0,
  [
    (1, 1, 0),
    (3, 5, 62),
    (16, 3, 636),
    (20, 2, 807),
    (23, 7, 989),
    (31, 2, 1268),
    (34, 1, 1433),
    (36, 5, 1523),
    (42, 6, 1857),
    (49, 5, 2171),
    (55, 2, 2502),
    (60, 5, 2651),
    (66, 6, 2985),
    (73, 0, 3293),
    (79, 5, 3791),
    (85, 6, 4030),
    (92, 6, 4454),
    (99, 2, 4807),
    (102, 4, 4938),
    (107, 0, 5196),
    (112, 2, 5684),
    (115, 1, 5745),
    (117, 5, 5822),
    (123, 9, 6155),
  ],
);

/// Typographic apostrophe: eSpeak speaks `don’t` as one word.
const cueCurlyApostrophe = CapturedCue('don’t stop the music.', 1.5, [
  (1, 3, 0),
  (7, 4, 316),
  (12, 3, 666),
  (16, 5, 775),
]);

/// Non-BMP character shifts eSpeak code-point positions by one.
const cueEmoji =
    CapturedCue('The crowd cheered 🎉 loudly when the team scored.', 3.0, [
      (1, 3, 0),
      (5, 5, 108),
      (11, 7, 469),
      (19, 1, 832),
      (20, 1, 1176),
      (21, 6, 1534),
      (28, 4, 1881),
      (33, 3, 2070),
      (37, 4, 2177),
      (42, 6, 2467),
    ]);

/// Leading punctuation: the first event lands at 109 ms, not 0.
const cueQuoted = CapturedCue(
  '“Well,” she said, “why not?” 1,234 people (about 5%) agreed.',
  6.7,
  [
    (2, 4, 109),
    (9, 3, 738),
    (13, 4, 924),
    (20, 3, 1565),
    (24, 3, 1737),
    (30, 2, 2505),
    (31, 2, 2749),
    (32, 3, 3233),
    (33, 3, 3877),
    (33, 3, 4197),
    (36, 6, 4440),
    (44, 5, 4909),
    (50, 1, 5214),
    (51, 1, 5528),
    (54, 6, 6120),
  ],
);

/// All cues with captured en-US word events.
const capturedCues = [
  cueArticles,
  cueNumeral,
  cueHyphens,
  cueCurlyApostrophe,
  cueEmoji,
  cueQuoted,
];

/// The cue's word events as [EspeakWordEvent]s.
List<EspeakWordEvent> cueWordEvents(CapturedCue cue) => [
  for (final (position, length, audioMs) in cue.events)
    EspeakWordEvent(textPosition: position, length: length, audioMs: audioMs),
];
