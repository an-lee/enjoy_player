# Data Model: Word Pronounce Playback

**Feature**: `031-word-pronounce`  
**Date**: 2026-07-30

No Drift schema changes. All entities are in-memory / network DTOs.

## PronounceTarget

What a surface asks to speak.

| Field | Type | Rules |
|-------|------|--------|
| `text` | string | Trimmed; empty → control disabled; max 200 chars (Worker limit) |
| `localeTag` | string | Surface BCP-47 / app language tag before resolution |
| `resolvedLocale` | string \| null | Worker allowlist locale after mapping (learning/lookup tags); `null` → unsupported → disabled |
| `surfaceId` | enum/string | `lookup` \| `flashcard` \| `assessment` (for cancel scoping / analytics if needed) |

Identity for session cache: `(normalizedText, resolvedLocale)` where normalization matches Worker expectations as closely as practical (trim; client may rely on server for full normalize).

## PronounceResult (API DTO)

Maps Worker JSON (snake_case → Dart camelCase in parser).

| Field | Type | Notes |
|-------|------|--------|
| `audioUrl` | Uri/string | Absolute URL to MP3 |
| `cached` | bool | Informational; UI need not show |
| `locale` | string | Canonical after server alias |
| `voice` | string | Resolved voice |
| `format` | string | e.g. audio-16khz-128kbitrate-mono-mp3 |
| `text` | string | Echo of trimmed input |
| `provider` | string | `"azure"` |

## PronouncePlaybackSession

App-wide session owned by one notifier.

| Field | Type | Notes |
|-------|------|--------|
| `state` | enum | `idle` \| `loading` \| `playing` \| `error` |
| `target` | PronounceTarget? | Active target when not idle |
| `audioUrl` | string? | Last successful URL |
| `errorMessage` | string? | Transient; cleared on next play |
| `requestGeneration` | int | Bumps to ignore stale async completions |

### State transitions

```text
idle --tap play--> loading --success--> playing --complete/stop--> idle
loading --cancel/stop/new target--> idle (or loading for new target)
playing --tap stop--> idle
loading|playing --failure--> idle (+ error notice)
any --surface dismiss / flip / new chip--> idle (stop)
```

At most one session active; a new play always stops the previous player first.

## Session URL cache (optional)

| Field | Type | Notes |
|-------|------|--------|
| `entries` | Map key→audioUrl | Key = hash(text+locale); LRU max ~32 |
| TTL | session lifetime | Cleared on sign-out |

Does not replace Worker R2; only reduces duplicate POSTs while reviewing the same card.

## Relationships

- Lookup sheet → PronounceTarget(text=selection, localeTag=source language)
- Flashcard → PronounceTarget(text=headword, localeTag=card/learning language)
- Assessment selected word → PronounceTarget(text=chip word, localeTag=assessment/learning language)
- PronouncePlaybackSession ← PronounceService.pronounce ← PronounceApi ← Worker
