/// Sample rate of every PCM buffer accepted by this package.
const int kAlignmentSampleRate = 16000;

/// Minimum extractable audio duration (whole clip or a single cue).
const double kMinAudioSeconds = 1.0;

/// Whole-clip [align] refuses longer source audio; use [alignSegments].
const double kMaxWholeClipSeconds = 90.0;

/// Allowed overshoot of per-cue word times past the cue window.
const double kCuePadSeconds = 0.050;

const Duration kDefaultWholeClipTimeout = Duration(minutes: 2);

const Duration kDefaultPerCueTimeout = Duration(seconds: 30);

/// Sakoe-Chiba band as a fraction of max(sequence lengths).
const double kSakoeChibaWindowPct = 0.20;
