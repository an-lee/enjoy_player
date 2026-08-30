/// Single source of truth for player position quantization buckets and the
/// position-stream tuning constants that must stay coherent with them.
///
/// See [lib/features/player/application/quantized_position.dart] for the
/// dedup behavior and the rationale for per-bucket tuning. The transport
/// scrubber uses finer buckets than the transcript highlight so the slider
/// tracks finger drags while the cue highlight skips per-tick rebuilds
/// that flood the Windows accessibility bridge (flutter/flutter#182444).
library;

/// Session emit + persistence cadence. The in-memory [PlaybackSession] and
/// the debounced DB write are updated once per 400 ms bucket so the recorded
/// clip window lines up across runs. Echo *enforcement* itself runs on every
/// position event (see `EchoEnforcer`); only the heavy session emit is gated
/// to this bucket.
const int kPositionBucketSessionEmitMs = 400;

/// Debounce window for coalescing rapid position updates into one DB write.
///
/// Coherent with [kPositionBucketSessionEmitMs]: see
/// [kMaxPendingPositionAgeMs] for why the two must move together.
const int kPlaybackSessionDebounceMs = 450;

/// Upper bound on how long a position update can stay unwritten, regardless of
/// debounce. The position tracker emits on the [kPositionBucketSessionEmitMs]
/// (400 ms) grid, so at 1x the 450 ms [kPlaybackSessionDebounceMs] would
/// otherwise be re-armed forever and never fire during continuous playback —
/// and at 2x the emit cadence (200 ms) is even faster. Forcing a flush once
/// pending data is older than this guarantees a crash never loses more than
/// ~2 s of progress (issue #280, P9).
const int kMaxPendingPositionAgeMs = 2000;

const int kPositionBucketDisplayMs = 400;

const int kPositionBucketScrubberMs = 50;

/// Karaoke current-word highlight. Finer than [kPositionBucketDisplayMs] so
/// short words are not skipped; must not replace the 400 ms display bucket
/// (Windows accessibility flood — flutter/flutter#182444).
const int kPositionBucketKaraokeMs = 50;

/// A position jump larger than this between two ticks is treated as a user /
/// programmatic seek (not linear playback) and forces an immediate echo
/// re-evaluation + session emit regardless of the [kPositionBucketSessionEmitMs]
/// bucket. Kept just under the 400 ms bucket so a seek that lands inside the
/// same bucket still triggers enforcement.
const double kLikelySeekDeltaSeconds = 0.35;

/// Two durations within this many seconds are considered equal (dedup guard
/// for the engine duration stream, which can re-emit near-identical values).
const double kDurationEpsilonSeconds = 0.001;
