# ADR-0068: Move share practice poster trigger into the shadow-reading toolbar

## Status

Proposed

## Context

`SharePracticePosterButton` was previously rendered as a `Stack`-overlay
on top of the transcript panel: a small floating pill at the top-right
corner of the transcript, sitting on a translucent black background. The
button was visible whenever the active target had at least one local
recording.

The overlay conflicted with the look the rest of the player chrome was
moving toward — a single, structured toolbar row inside the echo
region — and it competed with the transcript header for the same
top-right pixel. On mobile the pill was also easy to miss because the
transcript scrolls independently of the overlay.

We want the share affordance to live next to the other echo-mode
actions: the pitch toggle, the record FAB, and the takes cluster. That
keeps the transcript panel clean and clusters every share / record /
take action behind the same visual group.

## Decision

Move `SharePracticePosterButton` from the transcript overlay into the
leftmost slot of the new `leadingShare` parameter on
`ShadowReadingToolbarRow`. The button is now passed by
`shadow_reading_panel.dart` into the toolbar that already owns the
record FAB.

The button still self-hides via `SizedBox.shrink()` when there are no
recordings for the active target. The only remaining visibility
condition is whether echo mode is active — the shadow-reading toolbar
is only mounted inside the echo region's `_EchoShadowReadingPanel`.

### Visibility

| Condition                                | Share button visible? |
|------------------------------------------|-----------------------|
| Echo mode **off**, any recordings        | No                   |
| Echo mode **on**, no recordings          | No (self-hides)      |
| Echo mode **on**, ≥ 1 recording          | Yes                  |

This is a deliberate narrowing of the previous surface.

### Rationale for the narrower scope

1. **Practice is the prerequisite.** Sharing a poster that
   advertises "talking about X" only makes sense after the learner has
   practiced at least one take on the active echo region. Echo mode is
   the practice surface; gating share on echo mode is the simplest
   signal that recording has happened.
2. **The takes cluster is the richer sharepoint.** When echo mode is
   off, the shadow-reading toolbar is not mounted, so the takes
   cluster (play / assess / more) is also not mounted. Putting share
   there would either require a separate chrome site or duplicate the
   record FAB. The toolbar already groups all post-recording actions.
3. **The poster is already echo-tailored.** The cover frame and the
   hero quote both depend on the active echo region. Hosting the share
   trigger inside the echo region matches the artifact it produces.

### What changed

- `lib/features/player/presentation/expanded_player_widgets.dart` —
  dropped the `Stack` overlay; `transcript` is now the bare
  `TranscriptPanel`.
- `lib/features/shadow_reading/presentation/widgets/shadow_reading_toolbar_row.dart` —
  gained an optional `leadingShare` slot rendered before the pitch
  toggle inside the left `Expanded`. The FAB stays on the true horizontal
  center; the existing takes cluster still uses `FittedBox(scaleDown)` on
  the right.
- `lib/features/shadow_reading/presentation/shadow_reading_panel.dart` —
  passes `SharePracticePosterButton(mediaId: mediaId, iconColor: scheme.onSurface)`
  into the toolbar in the idle branch only (the recording branch keeps
  the centered FAB + caption row and does not host a row).

### What did not change

- `SharePracticePosterButton` itself — the widget, its gating on
  `recordings.isNotEmpty`, and its preview sheet launcher are unchanged.
- Recording-state UI — the centered-FAB + caption row stays as-is.
- The takes cluster — play / assess / more order is unchanged.

## Consequences

- **Users who want to share before entering echo mode** will not see a
  share button. They enter echo mode first or use the Library row's
  share affordance (separate surface). This is acceptable because the
  poster is only meaningfully populated with echo-region data.
- **The `ExpandedPlayerChromeBody` chrome no longer references the share
  widget** — the `iconColor: cs.onSurface` we passed through is no
  longer needed in that file.
- **Localization strings are unchanged** (`practicePosterShareTooltip`,
  `practicePosterPreviewTitle`, `practicePosterShareAction`,
  `practicePosterShareSuccess`).
- **Tests**: `test/features/share_poster/presentation/share_practice_poster_button_test.dart`
  continues to cover the widget's self-hide behavior. A new test in
  `test/features/shadow_reading/shadow_reading_toolbar_row_test.dart`
  asserts the toolbar's left-half layout when `leadingShare` is supplied
  (and the original layout when it is not).
