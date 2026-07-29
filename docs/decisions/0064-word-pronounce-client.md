# ADR-0064: Word pronounce client (Worker `/pronounce`)

## Status

Accepted

## Context

Learners need **model** pronunciation (not their own takes) for a looked-up
term, a flashcard headword, and a selected word on pronunciation assessment
results. Craft already owns TTS via Azure Speech (`TtsService` /
`EnjoyTtsCapability`) for longer authored utterances. Lookup historically had
no tap-to-play for the selected term (see ADR-0019). Assessment plays user takes
via `recordingPreviewPlayerProvider` / Azure scores — a different path from
hearing the reference pronunciation of a chip word.

Constraints:

- Do not instantiate `media_kit` `Player` outside the player engine (ADR-0003 /
  ADR-0015).
- Prefer one app-wide stream so surfaces do not overlap audio.
- Learning / lookup language tags must map to the Worker allowlist; never fall
  back to a different language’s voice.

## Decision

1. **Worker HTTP**: Client calls Enjoy Worker `POST /pronounce` (text + locale;
   omit `voice` so the Worker picks the default). Success returns a public
   `audio_url` under the Worker origin (`/pronounce/files/…`).
2. **Shared feature module**: `lib/features/pronounce/` owns locale resolve,
   `PronounceService` (`guardAiCall`), keepAlive `PronouncePlaybackController`
   (single `package:audioplayers` player + URL LRU + generation guard), and
   `PronounceIconButton`.
3. **Surfaces**: Wire the shared button into lookup header, flashcard headword
   (front + back; not Context “Play segment”), and assessment **selected-word
   panel only**. Stop on dismiss, language change, flip/rate, and chip change.
4. **Unsupported locale**: Disable the control with an explanatory tooltip —
   never coerce to another language.

## Consequences

- Lookup TTS follow-up from ADR-0019 is satisfied for short terms via Worker
  pronounce, not Craft `TtsService`.
- Pronounce audio is independent of shadow-reading take preview and of
  `media_kit`.
- Locale coverage tracks Worker `voices.ts` / learning+lookup catalogs; client
  resolver must stay in sync when the allowlist changes.
- Credits / auth failures reuse existing `AuthFailure` / `CreditsFailure` →
  `AppNotice` patterns.
