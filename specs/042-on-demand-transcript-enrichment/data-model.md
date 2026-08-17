# Data Model: On-Demand Transcript Enrichment

**Feature**: `042-on-demand-transcript-enrichment` | **Date**: 2026-08-17

No new Drift tables. Nested spans stay in `transcripts.timeline_json`. Karaoke/IPA prefs stay existing SettingsDao keys.

## Entities

### TranscriptWord (existing, clocks optional)

| Field | Required | Notes |
|-------|----------|-------|
| `text` | yes | Word substring. Empty skipped on parse. |
| `startMs` | no | ms relative to parent line. JSON `start`. **Omit** when untimed. |
| `durationMs` | no | ms. JSON `duration`. **Omit** when untimed. Missing or `≤ 0` ⇒ not a karaoke / tap-IPA target. |
| `phones` | no | `TranscriptPhone[]`. Null when absent/empty. |

### TranscriptPhone (existing, clocks optional)

| Field | Required | Notes |
|-------|----------|-------|
| `phone` | yes | IPA label. Empty skipped. |
| `text` | yes | Display; defaults to `phone`. |
| `startTime` | no | Seconds on media timeline. **Omit** for IPA-only YouTube writes. Overlay ignores clocks. |
| `endTime` | no | Seconds. Omit with `startTime`. |
| `wordIndex` | no | Index in parent `timeline`. |

### TranscriptLine (unchanged identity)

Line `text` / `startMs` / `durationMs` / `sourceKey` / `confidence` unchanged. Optional `timeline` still means nested words. Empty/missing `timeline` ⇒ line-only.

`cueIdFor` still ignores nested data.

### Display capability (derived, not stored)

Computed from current **primary** lines + media extractability:

| Flag | True when |
|------|-----------|
| `hasNestedWords` | Any cue `timeline` non-empty |
| `hasTimedWords` | Any word with a usable media window (`wordMediaWindowMs != null`) |
| `hasPhones` | Any word with displayable phone labels (`transcriptWordsHavePhones`) |
| `canTrustWordTimes` | Media is owned/extractable (local or Craft file). False for YouTube and remote-without-file |
| `karaokeSwitchEnabled` | `hasTimedWords && canTrustWordTimes` |
| `ipaSwitchEnabled` | `hasPhones` |
| `showEnrich` | Primary lines exist and `!hasNestedWords` |

### Enrichment run (session-ephemeral)

Not persisted. Riverpod notifier per `mediaId`:

| State | Meaning |
|-------|---------|
| idle | No run |
| running | In-flight; cancel allowed |
| failed | Typed reason; previous JSON intact (or partial lines already committed); retry allowed |
| succeeded | Timeline replaced; switches recompute from new lines |

Reasons: `unsupportedLanguage`, `audioUnavailable`, `cancelled`, `timedOut`, `internal`, `spokenReferenceUnavailable`.

### Transcript row write

`replaceTimeline` updates `timelineJson` + `updatedAt` on the existing primary id. Does not change `source`, `language`, `label`, `targetId`.

## JSON examples

Timed (owned / Craft) — unchanged:

```json
{
  "text": "hello",
  "start": 40,
  "duration": 320,
  "phones": [
    { "phone": "h", "text": "h", "startTime": 1.04, "endTime": 1.12, "wordIndex": 0 }
  ]
}
```

Untimed (YouTube IPA-only):

```json
{
  "text": "hello",
  "phones": [
    { "phone": "h", "text": "h", "wordIndex": 0 }
  ]
}
```

## Validation

| Rule | Behavior |
|------|----------|
| Omit word `start`/`duration` | Untimed; valid |
| `duration` missing or `≤ 0` | Not a karaoke/seek target |
| Fake equal-split times on non-extractable media | Forbidden |
| Phone clocks omitted | IPA overlay still uses `phone` labels |
| Malformed nested object | Skip element; keep line |
| Enrich with no lines | No-op; do not create a track |

## Relationships

```text
TranscriptRow.timelineJson
  └── List<TranscriptLine>
        └── timeline? → List<TranscriptWord>   # optional clocks
              └── phones? → List<TranscriptPhone>  # labels required; clocks optional
```

```text
idle --start--> running --success--> idle (lines now nested)
                 running --fail/cancel--> failed --retry--> running
                 failed --dismiss/open other item--> idle
```
