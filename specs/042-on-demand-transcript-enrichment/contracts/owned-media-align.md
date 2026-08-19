# Contract: Owned-media timed enrich

Applies when `canTrustWordTimes` is true (local/Craft file **or** owned cloud `mediaUrl`). HTTP(S) cloud URLs are downloaded with Dart HTTP to a temp file first; FFmpeg then reads that local path (FFmpegKit on Android/iOS/macOS, CLI on Windows/Linux). Never fetch YouTube.

## Pipeline

1. Resolve primary lines + transcript language → `alignmentLanguageForTranscript` (fail if unsupported).
2. If the source is an owned HTTP(S) URL, download it with Dart HTTP to a temp file. Then extract 16 kHz mono PCM in `lib/data/audio` from the **local** path (FFmpeg). Do **not** import `AsrAudioExtractor` or `CraftTimelineEnricher`.
3. Short item (last cue end ≤ ~90 s): `alignSegments` at medium granularity (words + phones), segment `id` = line index.
4. Longer item: per-cue window extract + `align()`; do not one-shot whole-file fine alignment of multi-minute media.
5. `attachAlignmentToLines` — line text/start/duration/`sourceKey` unchanged; nested words have relative ms clocks; phones keep media-timeline seconds when the engine provides them.
6. `TranscriptRepository.replaceTimeline` in place.

## Fail closed

Extract failure, `AlignmentFailed`, cancel, timeout → do not invent nested spans. If some cues already attached in a partial long-file run, keep those; remaining cues stay line-only.

Never play the spoken reference. Never replace lesson audio.

## After success

`karaokeSwitchEnabled` and `ipaSwitchEnabled` follow [display-gating.md](./display-gating.md). Karaoke highlight and tap-IPA-to-play keep slice 4/5 contracts on **timed** words.
