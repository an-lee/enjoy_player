# Data Model: Karaoke Word Highlight

**Feature**: `040-karaoke-word-highlight` | **Date**: 2026-08-16

No Drift schema change. Nested word times stay inside existing `transcripts.timeline_json` (ADR-0070). The new persisted fact is one SettingsDao row.

## Entities

### Karaoke setting

| Field | Type | Rules |
|-------|------|--------|
| key | `transcript.karaokeHighlight` | `SettingsKeys` static allowlist |
| value | `'true'` \| `'false'` \| missing | Missing ≡ off |
| default | off | Fresh profile / wiped DB |
| store | Device-global `SettingsDao` | Same file as enrichment |

Riverpod notifier exposes `AsyncValue<bool>`. `setEnabled` writes immediately; the next playback honors it (await the future on first read so loading ≠ off).

Independent of `transcript.timelineEnrichment`.

### Timed word span (existing)

| Field | Storage | Karaoke use |
|-------|---------|-------------|
| text | string | Locate paint range in plain line text |
| start / duration | ms **relative to parent line** | Time window on media: `line.startMs + start` … `+ duration` |
| phones[] | unused | Must not be rendered |

### Current word (ephemeral)

Not persisted.

| Field | Type | Rules |
|-------|------|--------|
| lineIndex | int | Same as `transcriptPlaybackHighlight` (echo-aware current cue) |
| wordIndex | int? | Index into that cue’s `timeline`; null if karaoke off, line-only, gap, or unusable times |
| highlightStart / highlightEnd | int? | UTF-16 offsets in `transcriptPlainForSelection(line.text)`; null if the word text cannot be located |

At most one current word per media session.

### Karaoke position

| Input | Source |
|-------|--------|
| media position | Engine position quantized to `kPositionBucketKaraokeMs` (50) |
| current line | Existing echo-aware highlight index |
| setting | Karaoke notifier (awaited) |

## Validation

- `wordIndex` is null unless karaoke is on **and** the current cue has a timed word whose window contains position **and** that window intersects the line window.
- Overlap: last matching word in list order.
- Out-of-window words never become current and never change line start/duration.
- Empty or unreadable `timeline` → line-only presentation.
- Paint range must lie inside the plain primary text; otherwise skip paint (do not invent tokens).

## State transitions

```text
playback position (50 ms buckets)
        │
        ▼
karaoke setting off? ──yes──► wordIndex = null (line chrome only)
        │ no
        ▼
current cue (line highlight, 400 ms / echo-aware)
        │
        ▼
currentWordIndex(line, positionMs)
        │
   ┌────┴────┐
   │ null    │ some i
   ▼         ▼
 no paint   wordHighlightRange(plain, words, i)
                    │
               null? ──yes──► no paint (line still shown)
                    no
                    ▼
               in-place span style on primary text
```

## Relationships

- Karaoke setting → gates panel paint only (not Craft save).
- Enrichment setting → gates Craft **save** nested writes (slice 3); not required at play time.
- Current word → derived from stored `TranscriptWord` times + media position.
- Line identity (`cueIdFor`, echo, blur, lookup, auto-translate) ignores nested spans and karaoke.
