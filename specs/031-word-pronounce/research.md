# Research: Word Pronounce Playback

**Feature**: `031-word-pronounce`  
**Date**: 2026-07-30

## R1 — Prefer Worker `/pronounce` over Craft `TtsService`

**Decision**: Client calls Enjoy Worker `POST /pronounce` (Bearer via `aiApiClientProvider`), then plays the returned public `audio_url`. Do **not** route vocabulary pronounce through Craft’s `TtsService` / Azure token + native SDK path.

**Rationale**:
- Spec assumes a shared, cache-friendly pronunciation service; Worker R2 cache + soft-gate credits match FR edge cases (free hits, charge only on miss).
- Craft TTS is long-form studio synthesis with different UX, credits, and no global word cache shared with other clients.
- Keeps `media_kit` ownership untouched; short preview already uses `package:audioplayers` in Craft.

**Alternatives considered**:
- Reuse `TtsService.synthesize` → rejected (no shared R2 URL cache; wrong product surface; heavier native SDK path).
- BYOK pronounce → rejected for v1 (Worker cache is Enjoy-account scoped; BYOK would bypass global cache).

## R2 — App-wide single playback session

**Decision**: One keepAlive Riverpod notifier owns pronounce load/play/stop for the whole app (`PronouncePlaybackController` or equivalent). Surfaces pass a `PronounceTarget` (text + locale) into a shared button; starting play stops any prior session.

**Rationale**: Spec requires zero overlapping streams and cancel on dismiss/flip/selection change. Centralizing state avoids three independent `AudioPlayer` instances fighting each other.

**Alternatives considered**:
- Per-widget `AudioPlayer` → rejected (overlap risk, harder cancel-on-navigate).
- Hook into `recordingPreviewPlayerProvider` → rejected (that path is file-path preview for user takes, not model TTS URLs).

## R3 — Playback via `audioplayers` + `UrlSource`

**Decision**: After a successful `POST /pronounce`, play with `AudioPlayer` + `UrlSource(audio_url)` (same package as Craft preview). Optionally keep a small in-memory LRU of `(text, locale) → audio_url` to skip duplicate POSTs within a session for rapid re-taps.

**Rationale**: `audio_url` is intentionally unauthenticated (`GET /pronounce/files/*`). URL play avoids buffering entire MP3 into Dart before start when the player can stream. Aligns with SC-002 latency goals for cache hits.

**Alternatives considered**:
- `http.get` → `BytesSource` → works but adds memory and delay; keep as fallback if URL play fails on a platform during implement.
- `media_kit` Player → forbidden (constitution / ADR single-owner rule).

## R4 — Locale resolution (learning + lookup languages)

**Decision**: Support every Enjoy Player **focus learning** and **lookup** language tag by mapping 1:1 onto the Worker pronounce allowlist (Azure neural defaults server-side):

| Client tags | Worker locale |
|-------------|----------------|
| `en-US`, bare/`en*` (non-GB) | `en-US` |
| `en-GB`, `en-UK` | `en-GB` |
| `zh-CN`, `ja-JP`, `ko-KR`, `es-ES`, `es-MX`, `fr-FR`, `fr-CA`, `de-DE`, `it-IT`, `pt-BR`, `pt-PT`, `ru-RU` | same tag |
| bare primaries / unknown regions (`ja`, `zh`, `es-AR`, …) | primary default (`ja-JP`, `zh-CN`, `es-ES`, …) when allowlisted |

- Lookup uses the sheet **source** language; flashcards use **`item.language`**; assessment uses the same practice-resolved locale as Azure assessment.
- If a tag somehow falls outside the allowlist, **disable** the control with tooltip (“Pronunciation unavailable for this language”) — never fall back to another language’s voice.
- Omit `voice` on POST; Worker picks the locale default.

**Rationale**: Azure Speech covers these locales; learners need model audio in the language they are studying, not English-only. Worker `voices.ts` is the shared allowlist; client resolver stays a thin mirror (+ `en-UK` alias).

**Alternatives considered**:
- English-only v1 → rejected (blocks focus learning languages ja/ko/es/fr/…).
- Always fall back to `en-US` → rejected (misleading).
- Client-side voice picker v1 → out of scope.

## R5 — Auth / credits UX

**Decision**: `PronounceService.pronounce` wraps HTTP with `guardAiCall` so `401` → `AuthFailure`, `402` → `CreditsFailure`. Shared button maps failures to:
- Lookup: same compact `AuthRequiredCallout` / credits messaging patterns as dictionary sections (or `AppNotice` for ephemeral errors from header tap).
- Flashcard / assessment: `AppNotice` (or existing snackbar/notice) for auth/credits/network; do not crash the card/dialog.

**Rationale**: FR-008/009; header pronounce is not inside `LookupSectionAuthGate`, so the button itself must check signed-in / surface errors without burying the control.

## R6 — Shared control placement (implementation mapping)

**Decision**: One presentation widget (e.g. `PronounceIconButton`) used in:
1. Lookup header action row (with bookmark / copy / close)
2. Flashcard front & back headword rows
3. Assessment `_SelectedWordPanel` header

States: idle / loading / playing / disabled. Tap idle→play; tap playing→stop; loading ignores duplicate play taps (or treats as stop-cancel).

**Rationale**: FR-001–004; matches explored layout in dictionary sheet / flashcard / assessment result.

## R7 — Clarification skipped

**Decision**: Proceeded to plan without `/speckit-clarify`. Defaults: stop-not-pause, Worker `/pronounce`, UrlSource, **learning/lookup locale coverage** (R4). BYOK pronounce remains out of scope.

**Rationale**: Spec already chose placements and interaction; locale coverage corrected to match Azure + player catalogs.
