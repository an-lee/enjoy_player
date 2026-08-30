# Implementation Plan: Friendly AI Credits-Exhausted Errors

**Branch**: `045-ai-credits-error-ux` | **Date**: 2026-08-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/045-ai-credits-error-ux/spec.md`

## Summary

Every Enjoy-hosted AI surface (ASR/transcripts, translation, contextual translation, dictionary lookup, TTS, craft/LLM, pronunciation assessment) must present the worker's credits-exhausted rejection (HTTP 402) as one consistent, friendly, localized message with credit numbers when available ("needs X credits, Y left today, resets at Z") and a single call-to-action that deep-links to the existing subscription screen. Today most surfaces leak the literal string `HTTP 402` because `ApiClient._throwApiError` parks the worker's structured envelope (`credits_exhausted` + `required` + `limit.*`) in `ApiException.body`, which nothing reads, and `mapApiExceptionToAppFailure` copies only `message`. Technical approach: enrich `CreditsFailure` with the parsed envelope at the single mapping seam, then route every surface's existing catch through one shared presentation helper with per-idiom variants (snackbar / inline / controller-state).

## Technical Context

**Language/Version**: Dart 3 / Flutter (stable channel, repo-pinned SDK)

**Primary Dependencies**: Flutter Material, Riverpod (providers/notifiers), go_router (`/subscription`, `/credits` routes), `package:logging` via project helpers, ARB-based `app_localizations`

**Storage**: None added — error presentation is ephemeral; credits usage data (`CreditsUsageLog`) stays read-only via the worker API. No Drift schema changes.

**Testing**: `flutter test` (unit + widget); mapping logic unit-tested, per-surface widget tests with the localized test harness (conventions in research.md)

**Target Platform**: Android, iOS, macOS, Windows, Linux — no platform-specific code in this feature

**Project Type**: Cross-platform Flutter desktop + mobile application

**Performance Goals**: Failure-path work only; envelope parsing is a handful of field reads. No hot-path or build-method changes; no jank budget impact.

**Constraints**: No server changes (worker contract consumed as-is); BYOK failures must never show the Enjoy upsell CTA; new strings delivered in every supported locale before merge.

**Scale/Scope**: ~8 user-facing AI surfaces; 1 core failure-model enrichment; 1 shared presentation helper; per-surface call-site updates; new ARB keys × existing locales.

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Architecture & code quality | Pass | Envelope parsing enriches the `AppFailure` family in `core/errors`; classification stays at the single `guardAiCall` seam in `features/ai/application`; presentation helper lives beside the existing `credits_failure_actions.dart` in `features/subscription/presentation`. No feature-to-feature shortcuts. |
| II. Testing defines the contract | Pass | Unit tests for envelope parsing + failure mapping; widget tests per surface idiom (snackbar action, inline error + CTA, controller state). Detailed in quickstart.md and tasks. |
| III. UX consistency | Pass | Transient feedback reuses `AppNotice` with `SnackBarAction`; inline variants reuse each section's existing error pattern; strings via ARB in every locale; `docs/features/` pages updated in the same change. |
| IV. Performance is a requirement | Pass | Failure-path only; O(1) field reads; nothing added to build methods or list builders. |
| V. Documentation & traceability | Pass | `docs/features/` updates identified in research.md; no ADR — single-seam enrichment is reversible, no costly-to-reverse decision. |
| Flutter Quality Gates | Pass | `flutter analyze`, `flutter test`, `bash .github/scripts/validate_ci_gates.sh` before push; `build_runner` only if provider codegen is touched (re-check at task time). |
| Development workflow | Pass | Tasks grouped by user story via `/speckit-tasks`. |

**Post-Phase-1 re-check (2026-08-30)**: still passing. Design artifacts ([research.md](research.md), [data-model.md](data-model.md), [contracts/](contracts/)) confirmed: envelope parsing lands in `core/errors` beside the failure types (no feature shortcut — both AI and subscription/credits repositories import core only); classification stays at the existing single seam; the presentation helper extends the existing subscription-feature file; tests enumerated per changed contract (parser unit, classification matrix, per-surface widget); docs list in research.md §D7. One documented exception recorded: AI playground keeps raw diagnostics output (internal screen, exempt from FR-004). No violations; no ADR required.

## Project Structure

### Documentation (this feature)

```text
specs/045-ai-credits-error-ux/
├── plan.md              # This file (/speckit-plan command output)
├── research.md          # Phase 0 output (/speckit-plan command)
├── data-model.md        # Phase 1 output (/speckit-plan command)
├── quickstart.md        # Phase 1 output (/speckit-plan command)
├── contracts/           # Phase 1 output (/speckit-plan command)
└── tasks.md             # Phase 2 output (/speckit-tasks command - NOT created by /speckit-plan)
```

### Source Code (repository root)

```text
lib/
├── core/
│   └── errors/
│       └── app_failure.dart              # CreditsFailure enriched with envelope fields
├── data/
│   └── api/
│       └── api_exception.dart            # shape unchanged; body already carries the envelope
├── features/
│   ├── ai/
│   │   └── application/
│   │       └── ai_api_failures.dart      # single mapping seam: parse envelope → CreditsFailure
│   ├── subscription/
│   │   └── presentation/
│   │       └── credits_failure_actions.dart  # shared presentation helper(s), snackbar + inline variants
│   ├── asr|transcript|lookup|pronounce|shadow_reading|craft|vocabulary/
│   │   └── …                              # per-surface catch-site updates (inventory in research.md)
│   └── credits|subscription/
│       └── data/                          # purchase-path 402s routed through same presentation
└── l10n/
    └── app_*.arb                          # new keys in every locale

test/
├── core/errors/                           # envelope parsing + mapping unit tests
└── features/…                             # per-surface widget tests mirroring changed surfaces
```

**Structure Decision**: Feature-first layout preserved (constitution I). The failure-model change is a core-type enrichment; classification stays inside the existing `guardAiCall` seam; the shared presentation helper extends `credits_failure_actions.dart` so the CTA's route knowledge stays inside the subscription feature. Per-surface changes stay inside each feature's presentation/application layer.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations — table intentionally empty.
