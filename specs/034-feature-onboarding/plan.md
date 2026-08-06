# Implementation Plan: Feature Onboarding Guides

**Branch**: `034-feature-onboarding` | **Date**: 2026-08-06 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/034-feature-onboarding/spec.md`

## Summary

Ship a maintainable **post-sign-in** feature-discovery system: Enjoy-owned tip identities, triggers, sequencing, and Drift-backed progress; **`showcaseview`** for spotlight overlays only. v1 covers Home **Craft/Import**, Player **empty-transcript** (per-`mediaId`, local vs YouTube), then same-visit **echo → record → assess** when ready. Learners can tap highlighted controls (learn-by-doing), skip/dismiss, and **Reset product tips** from Settings → About.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: Flutter, Riverpod (`@Riverpod`), go_router, Drift (`AppDatabase` / `SettingsDao`), **`showcaseview` ^5.x**, existing ARB l10n, Enjoy UI primitives

**Storage**: Drift `SettingsKv` via `SettingsDao` — global tip progress JSON + dynamic per-media empty-transcript keys (signed-in `appDatabaseProvider`). No new tables.

**Testing**: Unit tests for tip catalog / eligibility / progress store; widget tests for Home + empty-transcript triggers + reset row; manual desktop/mobile overlay QA; `flutter analyze`, `flutter test`, `bash .github/scripts/validate_ci_gates.sh --fix`; codegen after new `@Riverpod` providers

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter desktop/mobile app

**Performance Goals**: Tip start after first frame of eligible surface &lt; 300ms perceived delay; dismiss restores interaction &lt; 2s (SC-005); no heavy work in tip eligibility beyond reading in-memory progress + already-watched player/transcript state; overlay must not jank playback scrubbing when idle

**Constraints**: Single `media_kit` player ownership unchanged; no `print()`; no feature↔feature shortcuts beyond routing/shared core; one active showcase at a time; tips must not show over blocking auth/permission dialogs; YouTube empty state today lacks a fetch CTA — v1 adds a spotlightable obtain-transcript action for YouTube (see research R3)

**Scale/Scope**: New `lib/features/onboarding/` module + thin presentation hooks on Home, transcript empty/player practice controls, About settings row, ARB strings, feature doc + ADR; **7 tip identities** in v1 catalog

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | New `lib/features/onboarding/{application,domain,presentation}`; progress via `SettingsDao` / `SettingsKeys`; Home/player/transcript/settings only wrap targets + call onboarding controller — no player engine ownership |
| II. Testing | Pass | Unit: eligibility + progress scope + reset; widget: Home sequence, empty-transcript per-media, About reset; document manual overlay QA for desktop resize |
| III. UX consistency | Pass | Tip copy in ARB; About uses `SettingsRow`; targets existing Craft/Import/echo/record/assess/transcript CTAs; update `docs/features/` |
| IV. Performance | Pass | Budgets above; start showcase post-frame; defer when overlay/dialog active; avoid rebuild storms (keepAlive progress notifier) |
| V. Documentation | Pass | ADR for onboarding system + `showcaseview`; feature doc for tip catalog / reset; link from docs index |
| Flutter Quality Gates | Pass | analyze, test, format/codegen gates; no web |

**Post-design re-check**: Pass — contracts isolate catalog/progress/UI host; YouTube CTA is a small transcript empty-state addition justified by FR-003 spotlight requirement; no unjustified complexity.

## Project Structure

### Documentation (this feature)

```text
specs/034-feature-onboarding/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── tip-catalog.md
│   ├── tip-progress-store.md
│   ├── showcase-host.md
│   └── reset-product-tips.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
lib/features/onboarding/
  domain/
    onboarding_tip_id.dart          # stable tip ids + sequences
    tip_progress.dart               # status enum / progress snapshot
    tip_eligibility.dart            # pure eligibility helpers (testable)
  application/
    onboarding_progress_provider.dart
    onboarding_controller.dart      # start/skip/complete/reset; single-flight
  presentation/
    onboarding_showcase_host.dart   # ShowCaseWidget / ShowcaseView registration
    onboarding_target.dart          # thin Showcase wrapper + GlobalKey registry
    onboarding_tooltip_theme.dart   # Enjoy-aligned tooltip styling

lib/features/library/presentation/
  home_screen.dart                  # wrap Craft/Import; trigger home sequence

lib/features/transcript/presentation/
  transcript_empty_state.dart       # YouTube fetch CTA + Showcase targets
  transcript_panel.dart             # wire empty-transcript tip trigger

lib/features/player/presentation/widgets/
  global_transport_bar.dart         # echo toggle Showcase target
lib/features/shadow_reading/presentation/
  widgets/shadow_record_fab.dart
  recording_assessment_button.dart  # record / assess targets + practice chain

lib/features/settings/presentation/widgets/
  about_section_card.dart           # Reset product tips row

lib/data/db/
  settings_keys.dart                # onboarding.* keys + isKnown prefixes

lib/app.dart / root_shell.dart      # host ShowCaseWidget once above shell content

lib/l10n/app_en.arb (+ zh / zh_CN)

docs/features/onboarding.md
docs/decisions/00XX-feature-onboarding-showcaseview.md

test/features/onboarding/...
```

**Structure Decision**: Own the system under `lib/features/onboarding/`; presentation hosts only attach keys and request `OnboardingController` starts. Persistence stays on Drift settings (same pattern as diagnostics / ASR attempt keys). Overlay package stays at the edges via `OnboardingTarget` / host.

## Complexity Tracking

> No constitution violations requiring justification.

| Concern | Why Needed | Simpler Alternative Rejected Because |
|---------|------------|-------------------------------------|
| YouTube empty-state fetch CTA | Spec requires a real control to spotlight for YT cloud fetch; empty UI currently has hint text only | Spotlighting CC sheet alone is discoverability-poor and fails learn-by-doing tap-through |

## Phase 0 / Phase 1 outputs

- [research.md](./research.md) — decisions R1–R10
- [data-model.md](./data-model.md) — tip ids, progress scopes, transitions
- [contracts/](./contracts/) — catalog, progress store, showcase host, reset
- [quickstart.md](./quickstart.md) — automated + manual validation

## Implementation notes (for `/speckit-tasks`)

1. **Foundation**: `showcaseview` dep, tip catalog domain, progress store + Riverpod, showcase host under shell, ARB tip strings.
2. **P1 Home**: Craft/Import targets + home sequence trigger after first frame.
3. **P1 Empty transcript**: Local CTA targets + YouTube fetch CTA + per-media progress + auto-complete on successful transcript.
4. **P2 Practice loop**: Echo → record → assess targets, same-visit chaining, single-flight gate.
5. **P3**: About **Reset product tips** + confirmation; docs/ADR; desktop resize smoke.
6. Verification: analyze, targeted tests, `validate_ci_gates.sh --fix`.
