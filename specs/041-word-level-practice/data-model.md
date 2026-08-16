# Data Model: Word-Level Practice

**Feature**: `041-word-level-practice` | **Date**: 2026-08-16

No Drift schema change. Nested words/phones stay inside existing `transcripts.timeline_json` (ADR-0070). New persisted facts are two SettingsDao rows. Loop / chosen word are ephemeral.

## Entities

### IPA overlay setting

| Field | Type | Rules |
|-------|------|--------|
| key | `transcript.ipaOverlay` | `SettingsKeys` static allowlist |
| value | `'true'` \| `'false'` \| missing | Missing ≡ off |
| default | off | Fresh profile / wiped DB |
| store | Device-global `SettingsDao` | Same file as karaoke |

Riverpod notifier exposes `AsyncValue<bool>`. `setEnabled` writes immediately. Loading MUST NOT freeze a persisted `'true'` as off.

Independent of karaoke and enrichment.

### Word-level practice setting

| Field | Type | Rules |
|-------|------|--------|
| key | `transcript.wordPractice` | `SettingsKeys` static allowlist |
| value | `'true'` \| `'false'` \| missing | Missing ≡ off |
| default | off | Fresh profile / wiped DB |
| store | Device-global `SettingsDao` | Same file as karaoke |

Same notifier rules as overlay. Independent of overlay, karaoke, and enrichment.

### Timed word span (existing)

| Field | Storage | This slice |
|-------|---------|------------|
| text | string | Hit-test range; inspect title |
| start / duration | ms **relative to parent line** | Seek/loop media window: `line.startMs + start` … `+ duration` |
| phones[] | `TranscriptPhone` | Overlay concat + inspect list |

### Stored pronunciation spelling (derived)

Not persisted separately.

| Field | Type | Rules |
|-------|------|--------|
| spelling | `String?` | Join non-empty `phone` fields in list order. Null if none. |
| pieces | `List<String>` | Ordered non-empty `phone` labels for inspect |

Never invent labels. `text` on `TranscriptPhone` is not a fallback generator when `phone` is empty (skip that piece).

### Chosen word (ephemeral)

Not persisted.

| Field | Type | Rules |
|-------|------|--------|
| mediaId | string | Open session |
| lineIndex | int | Cue in the primary track |
| wordIndex | int | Index into that cue’s `timeline` |

Set by a successful seek-to-word, or by the current-word practice action. Cleared on media switch / stop / practice off.

### Current timed word (ephemeral)

Same time-match as slice 4 `currentWordIndex`. At most one per media. Used for karaoke paint (if karaoke on) and for selectable-row loop/inspect (if practice on).

### Word loop (ephemeral)

Not persisted. At most one per media.

| Field | Type | Rules |
|-------|------|--------|
| lineIndex | int | Must remain a valid cue |
| wordIndex | int | Timed word |
| mediaStartMs | int | `line.startMs + word.startMs` |
| mediaEndMs | int | start + `word.durationMs` (exclusive end) |

Active only while practice is on and the window is valid. Cancel rules: see [contracts/word-loop.md](./contracts/word-loop.md).

### Word media window (derived)

`[line.startMs + word.startMs, line.startMs + word.startMs + word.durationMs)` intersecting the parent line window. Out-of-line windows are not seek/loop targets (FR-012).

## Validation

- Overlay paints spelling only when overlay is on, the cue is revealed (or blur off), and `spelling != null`.
- Seek/loop only when practice is on, the word is timed, and the window intersects the line.
- Selectable rows never use word hit-test for seek.
- Lookup / `transcriptPlainForSelection` never include IPA spelling.
- Empty or unreadable `timeline` / `phones` → line-only presentation for that aspect (no blocking error).

## State transitions

```text
Settings (ipaOverlay / wordPractice)
        │
        ▼
both off ──► post-slice-4 panel (karaoke may still paint)

ipaOverlay on ──► annotation layer from stored phones (layout-time)

wordPractice on
        │
        ├─ tap non-selectable timed word ──► seekToWord + chosen word
        ├─ tap chrome / miss ──► line seek (today)
        ├─ selectable row tap ──► lookup / selection (today)
        ├─ loop icon ──► WordLoop active; ticks wrap until cancel
        └─ inspect icon ──► sheet of stored pieces (omit icon if none)
```

```text
position tick
        │
        ▼
word loop active? ──yes──► wrap at mediaEndMs; skip echo pause-and-rewind
        │ no
        ▼
EchoEnforcer.enforceTick (unchanged)
```

## Relationships

- Overlay setting → gates IPA annotation only.
- Practice setting → gates seek/loop/inspect only.
- Karaoke setting → gates in-place highlight only (ADR-0074).
- Enrichment setting → gates Craft **save** nested writes (slice 3); not required at play time.
- Line identity (`cueIdFor`, echo membership, blur, lookup, auto-translate) ignores nested spans and these settings.
- Word loop does not write echo start/end or `SessionDao` echo fields.
