# Contract: Recording Preview Clip Playback

**Consumer**: Assessment result UI (and existing shadow take toolbar via shared player)  
**Provider**: `RecordingPreviewPlayer` / `recordingPreviewPlayerProvider`  
**Related**: [ADR-0003](../../../docs/decisions/0003-player-core-media-kit.md)

## Scope

Extend the **existing** shadow take preview player. Do **not** construct another `media_kit` `Player`. Do **not** use `PlayerController` for take/clip audio.

## Required behaviors

### Full take

| Operation | Contract |
|-----------|----------|
| Play full take | Open `path`, play from **start** (position 0). Stops any current preview first. |
| Stop | Stop playback and clear loaded path (existing `stop` semantics). |
| Toggle (toolbar) | Existing `playOrPauseTake` may remain for toolbar; result full-take control uses **play from start / stop** (tap-to-play, tap-to-stop), not pause-resume mid-file, unless product later aligns them. |

### Seek / clip

| Operation | Contract |
|-----------|----------|
| Seek | `seek(Duration position)` — seek within currently loaded (or just-opened) media. |
| Play clip | Given `path`, `start`, `end` (`Duration`): open path if needed, seek to `start`, play, and **stop** when `position >= end` (or natural end if sooner). |
| Invalid clip | If `end <= start`, or file missing → fail fast / no hang; caller disables control. |
| Concurrent calls | Newer play/clip/stop cancels prior clip end-watcher; no stacked audible streams from this player. |

### Streams (existing + usage)

| Stream | Use |
|--------|-----|
| `position` | Karaoke active-word mapping; clip end detection |
| `playing` | Control busy/playing affordances |
| `duration` | Optional UI; not required for karaoke |
| `loadedPath` | Know which file is loaded |

## Non-goals

- Trimming/exporting WAV files
- Pitch/speed controls
- Playing lesson media or remote URLs
- Converting Azure ticks (callers convert to `Duration` in ms)

## Verification

- Unit/integration: playClip stops near `end`; stop clears playing; missing file errors without stuck state.
- Manual: same take plays from result and from takes toolbar without needing a second engine.
