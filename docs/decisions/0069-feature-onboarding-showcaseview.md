# ADR-0069: Feature onboarding with showcaseview

**Status**: Accepted  
**Date**: 2026-08-06

## Context

New learners need contextual guidance for Craft/Import, obtaining transcripts, and the echo → record → assess practice loop. We need a maintainable tip system (stable ids, triggers, Drift progress) with spotlight overlays, without a pre-sign-in marketing carousel (ADR-0031).

## Decision

1. Own tip catalog, eligibility, sequencing, and progress in `lib/features/onboarding/`.
2. Persist progress via Drift `SettingsKv` on the signed-in user DB (`onboarding.tip_progress_v1` + `onboarding.empty_transcript.<mediaId>`).
3. Present tips with **`showcaseview` ^5.x** (`ShowcaseView.register` + `Showcase` targets), registered once under `RootShell`.
4. Keep the stakeholder feature spec toolkit-agnostic; this ADR and the feature plan name the package.

## Consequences

- Adding a tip is mostly: new tip id, ARB copy, wrap one control, eligibility rule.
- Overlay behavior (desktop resize, GlobalKeys) depends on `showcaseview`; we skip missing targets and dismiss on route/media change.
- Progress does not sync across devices in v1.
