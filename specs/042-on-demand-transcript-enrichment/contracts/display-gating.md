# Contract: Display gating

Karaoke and IPA remain on the CC subtitle sheet (`TranscriptDisplaySettingsSection`). Preferences stay `transcript.karaokeHighlight` and `transcript.ipaOverlay` (default off). This slice changes **availability**, not defaults.

## Switch enablement

| Switch | `onChanged` non-null when | Visible value |
|--------|---------------------------|---------------|
| Karaoke | `hasTimedWords && canTrustWordTimes` | `preference && capability` |
| IPA | `hasPhones` | `preference && hasPhones` |

`canTrustWordTimes` is false for YouTube (`provider == youtube` / YouTube engine) and for remote items without a local media file.

Turning a disabled switch is impossible. Opening a gated item MUST NOT write `'false'` over a stored `'true'`.

## Paint / overlay

- Karaoke highlight (`karaokeWordIndex`) MUST be null when capability is false, even if preference is true (SC-006 YouTube).
- IPA stacked columns still require overlay preference **and** phones on that cue (existing tile gate). Untimed words with phones MAY show IPA.
- Empty / no primary lines: both switches disabled; do not imply nested data exists.

## Non-goals

- Do not move switches back to Settings → Transcript.
- Do not enable karaoke because nested words exist if those words are untimed or the media is YouTube.
