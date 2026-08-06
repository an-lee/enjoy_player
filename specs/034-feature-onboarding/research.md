# Research: Feature Onboarding Guides

**Date**: 2026-08-06 | **Feature**: 034-feature-onboarding

## R1. Presentation package: `showcaseview`

**Decision**: Depend on **`showcaseview` ^5.x** (Simform). Register a single app-scoped showcase host; start sequences with `ShowcaseView.get().startShowCase([...keys])` (or current 5.x equivalent) **after** the first frame when targets are laid out. Tip identity/triggers/progress remain Enjoy-owned.

**Rationale**: Clarify session chose `showcaseview`; high adoption, MIT, supports multi-step tours, `disposeOnTap` + `onTargetClick` for learn-by-doing, skip/dismiss callbacks. Spec requires maintainable product logic independent of overlay kit.

**Alternatives considered**:
- `tutorial_coach_mark` — equally viable; rejected after product choice for widget-wrapper API fit.
- Custom overlay — higher maintenance for cutouts/tooltips/a11y.
- `feature_discovery` — older Material pattern, lower traction.

## R2. Showcase host placement

**Decision**: Wrap once at **`RootShell`** (or `EnjoyApp._shellBuilder` immediately around shell content) so Home (`/`) and Player (`/player/:mediaId`) share one host under `ShellRoute`. Expose dismiss/finish hooks into `OnboardingController`.

**Rationale**: Both tip surfaces live under `ShellRoute` → `RootShell`. One host enforces FR-012 (single active overlay). Per-screen hosts risk stacked overlays when navigating Home ↔ Player.

**Alternatives considered**:
- Per-screen `ShowCaseWidget` — rejected (stacking / lifecycle complexity).
- Only `MaterialApp.builder` without shell awareness — workable but farther from transport/player chrome; RootShell preferred.

## R3. YouTube empty-transcript spotlight target

**Decision**: Extend `TranscriptEmptyState` for YouTube (`provider == 'youtube'`) with an explicit **Fetch transcript** CTA that calls the existing `refreshFromCloud` / `TranscriptFetchCtrl` path. Spotlight that CTA (local media keeps Generate / Add subtitle / Extract as today).

**Rationale**: Today YouTube empty UI is hint-only (`noTranscriptHintRemote`); auto-fetch on open is silent and not a tap target. Spec FR-003 + FR-005a require a real control for learn-by-doing.

**Alternatives considered**:
- Spotlight CC picker “Refresh cloud” only — weaker empty-state teaching; extra sheet step.
- Rely on auto-fetch alone — fails “guide user to fetch” when auto-fetch fails or is skipped.

## R4. Tip progress persistence

**Decision**: Store progress in **signed-in** Drift DB (`appDatabaseProvider`) via `SettingsDao`:
- Global tips: single JSON blob `SettingsKeys.onboardingTipProgressV1`
- Per-media empty-transcript: `SettingsKeys.onboardingEmptyTranscript(mediaId)` → `done` | `skipped`
- Register static key + `onboarding.empty_transcript.` prefix in `SettingsKeys.isKnown`
- `OnboardingProgress` `@Riverpod(keepAlive: true)` for read/mark/resetAll

**Rationale**: Spec ties tips to signed-in profile on device; mirrors other prefs. Per-media keys match ASR attempt pattern. JSON blob keeps global tip set cheap to reset and evolve.

**Alternatives considered**:
- `deviceGlobalAppDatabaseProvider` — tips would leak across accounts; rejected for v1.
- New Drift table — unnecessary for sparse KV tip state.
- `shared_preferences` — not used for app prefs; constitution prefers Drift DAOs.

## R5. Tip catalog & Home order

**Decision**: Maintain a static catalog in domain code (`OnboardingTipId` + sequences). v1 ids:

| Id | Sequence | Scope |
|----|----------|-------|
| `home.import` | `home.entries` | global |
| `home.craft` | `home.entries` | global |
| `player.empty_transcript.local` | `player.empty_transcript` | per mediaId |
| `player.empty_transcript.youtube` | `player.empty_transcript` | per mediaId |
| `player.echo` | `player.practice` | global |
| `player.record` | `player.practice` | global |
| `player.assess` | `player.practice` | global |

Home visual order matches header LTR: **Craft then Import** (029 layout). Showcase start order: **Import then Craft** (bring media first, then create) — document in catalog; copy explains each.

**Rationale**: Stable string ids satisfy FR-011. Import-before-Craft in the *tour* teaches the primary content path first even if Craft is leftmost visually.

**Alternatives considered**:
- Showcase order = visual LTR Craft→Import — acceptable; prefer Import-first pedagogy.
- Config file / remote JSON — out of scope (no server-driven tips).

## R6. Learn-by-doing interaction

**Decision**: For each `Showcase` target: `disposeOnTap: true` (or 5.x equivalent) + `onTargetClick` that (1) marks tip complete/advances controller, (2) invokes the real control callback. Tooltip always offers Skip (dismiss sequence / mark skipped) and Next where multi-step. On navigation away, call `ShowcaseView.get().dismiss()` and persist skip/complete as already decided by the action.

**Rationale**: Clarify A for FR-005a; package example supports navigate-on-target with dispose.

**Alternatives considered**:
- Tooltip-only navigation — rejected in clarify.
- Completing tip only on Next — weaker learn-by-doing.

## R7. Eligibility & single-flight controller

**Decision**: Pure `TipEligibility` functions take a `TriggerContext` (route, mediaId, isYoutube, hasTranscript, echoActive, hasRecordingForAssess, blockingOverlay). `OnboardingController` ensures **one** in-flight sequence; conflicting starts are deferred or dropped. Practice chain: after finish/dismiss of `player.echo`, if still on player with transcript and `player.record` pending → start record tip same visit; same for assess when recording+assess UI ready. Empty-transcript tips block practice tips until `hasTranscript` for current media.

**Rationale**: FR-004a / FR-012 / edge cases. Pure eligibility is unit-testable without Flutter.

**Alternatives considered**:
- Fire all tips via timers — fragile with layout.
- Hard-wire sequences in widgets — fails maintainability (FR-011).

## R8. Auto-complete empty-transcript on success

**Decision**: When transcript lines become available for `mediaId`, mark that media’s empty-transcript progress `done` (even if tip was never shown). If echo is already active when the echo tip would show, mark echo tip `completed` without showing and proceed to record when eligible (**FR-004b**).

**Rationale**: Spec edge case “already use feature”; soft auto-complete for obvious state avoids pointing at an already-on toggle.

**Alternatives considered**:
- Always show tip even if echo on — noisy.
- Auto-complete all practice tips from telemetry of past use — deferred (no usage analytics store).

## R9. Reset product tips UX

**Decision**: About section `SettingsRow` → confirmation dialog → `OnboardingProgress.resetAll()` deletes global JSON + all `onboarding.empty_transcript.*` keys for current user DB. Optional short snackbar success. Searchable via settings search if About entries are indexed.

**Rationale**: Clarify A; About already hosts diagnostics/export (device hygiene). Confirmation prevents accidental wipe.

**Alternatives considered**:
- Per-surface reset — rejected in clarify.
- Reset without confirm — too easy to mis-tap.

## R10. Testing & desktop overlay risk

**Decision**: Unit-test catalog/eligibility/progress; widget-test Home + empty-transcript + reset with fakes (mock progress; pump Showcase host). Manual matrix: Windows + one mobile — open/dismiss, resize mid-tip, tap-through Craft, YT fetch CTA, practice chain. If `showcaseview` misbehaves on desktop resize, dismiss on metrics change (controller listens to route/media changes).

**Rationale**: Overlay geometry is hard to fully automate; constitution allows documented manual verification for platform chrome.

**Alternatives considered**:
- Integration-only — slower feedback for eligibility bugs.
- Skip desktop QA — unacceptable for Windows-primary users.
