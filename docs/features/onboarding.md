# Feature onboarding (product tips)

Post-sign-in spotlight tips that teach Craft/Import, empty-transcript obtain flows, and the echo → record → assess practice loop.

## Behavior

- Tips use short coach-mark overlays on real controls (learn-by-doing: tap the highlight to act).
- Progress is stored with the **signed-in user** on device (global tip JSON + per-`mediaId` empty-transcript keys).
- Empty-transcript tips resolve **per media item**; Home and practice tips are global.
- Settings → About → **Reset product tips** clears all tip progress after confirmation.
- Overlay package choice and host wiring live under `lib/features/onboarding/`; see ADR-0069.

## v1 tip catalog

| Tip id | Surface |
|--------|---------|
| `home.import` / `home.craft` | Home header |
| `player.empty_transcript.local` | Extract (else Add subtitle) |
| `player.empty_transcript.youtube` | Fetch transcript CTA |
| `player.echo` / `player.record` / `player.assess` | Transport + shadow toolbar |

## Related

- Spec: `specs/034-feature-onboarding/`
- ADR: [0069-feature-onboarding-showcaseview.md](../decisions/0069-feature-onboarding-showcaseview.md)
