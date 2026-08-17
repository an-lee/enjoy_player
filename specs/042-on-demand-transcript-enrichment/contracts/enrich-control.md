# Contract: Enrich control

Shown in the same CC-sheet display card as karaoke/IPA, using `TranscriptBusyListTile` (spinner while running).

## Visibility

Show when the current **primary** transcript has ≥1 line and **no** cue has a nested `timeline`.

Hide when nested words already exist (including YouTube IPA-only words). Optional re-run is out of scope.

Hide when there is no primary track / no lines (empty-state import / ASR / YouTube fetch stay as today).

## Copy (ARB)

| Media | Title intent | Subtitle intent |
|-------|----------------|-----------------|
| Owned extractable | Generate word timings and pronunciation | Alignment uses this item’s audio |
| YouTube / non-extractable | Generate pronunciation | Karaoke stays unavailable; no download of the video |

Exact strings in `lib/l10n/*.arb`.

## Lifecycle

1. Tap → start enrich for this `mediaId` (explicit only). Opening the sheet, playing, seeking, or toggling switches MUST NOT start it.
2. Running → tile busy; transport remains usable; tap becomes **Cancel** (or an adjacent cancel affordance on the same tile).
3. Success → tile disappears (`showEnrich` false); switches recompute without app restart.
4. Failure / cancel → previous captions remain; inline retryable status on the tile; no blocking dialog that prevents playback. Recovery to a usable sheet in **< 2 s** (SC-005).

## Isolation

Presentation MUST NOT import `package:forced_alignment/`. It calls a transcript application notifier only.
