# Contract C3: Showcase host & learn-by-doing

## Purpose

Define how `showcaseview` is hosted and how tips interact with real controls (FR-001, FR-005, FR-005a, FR-012, FR-013).

## Host

| Rule | Detail |
|------|--------|
| Placement | Single host under `RootShell` (or equivalent shell builder wrapping shell child + transport) |
| Package | `showcaseview` ^5.x |
| Start | Post-frame `startShowCase` with ordered `GlobalKey`s for eligible pending tips |
| Single-flight | Controller rejects/defers a second start while a showcase is active |
| Teardown | `dismiss()` on route change, mediaId change, or blocking overlay; no stuck barrier |

## Target wrapping

Presentation hosts wrap existing controls with a thin `OnboardingTarget` (or `Showcase`) that:

1. Owns/registers a `GlobalKey` for the tip id.
2. Sets localized title/description from ARB.
3. Sets **learn-by-doing**: target tap runs real `onPressed` / callback **and** advances/completes the tip (`disposeOnTap` + `onTargetClick` or 5.x equivalents).
4. Exposes Skip (and Next for multi-step) on the tooltip.

Targets (v1): Home Craft, Home Import, primary local empty CTA (Extract or Add subtitle per C1) + YouTube Fetch CTA, echo toggle, record FAB/control, assess button.

## Controller responsibilities

```text
OnboardingController
  tryStartHomeEntries(context)
  tryStartEmptyTranscript(context, mediaId, isYoutube)
  tryStartPracticeChain(context)   # echo→record→assess as eligible
  onTipCompleted(tipId)
  onTipSkipped(tipId)              # per-media when empty transcript
  onShowcaseFinished()
  dismissActive()
```

Practice chain: after a practice tip resolves, if still same player visit and next tip eligible, start next **after** overlay close (FR-004a). Soft-complete echo when already active (FR-004b).

### Start guards (off-screen / blocking)

Do **not** start a tip if:

1. Its target’s render box has **zero size** / is not painted, or
2. A **blocking** dialog/route owns the focus barrier (permissions, fatal error, forced sign-in).

Defer or skip that tip; never point at empty space. `TriggerContext.blockingOverlay` is `true` when such UI is active. Controllers also `dismissActive()` on route / `mediaId` change.

## Styling

Tooltip chrome should use Enjoy theme colors/typography (custom tooltip builder if needed). Barrier must not permanently block dismiss. Longer ZH copy must keep Skip visible.

## Non-goals

- Custom physics/animations beyond package defaults (unless needed for desktop bugfix)
- Tips outside catalog without new tip id + target wiring
