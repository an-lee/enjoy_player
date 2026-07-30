# Implementation Plan: Craft Shadow-Friendly Transcript Cues

**Branch**: `032-craft-shadow-cues` | **Date**: 2026-07-30 | **Spec**: [spec.md](spec.md)

**Input**: Feature specification from `/specs/032-craft-shadow-cues/spec.md`

## Summary

Two independently-valuable slices that together make Craft transcripts ready for shadow reading on every platform that supplies word boundaries:

1. **Apple word-boundary capture (coverage, FR-001/FR-002)** — the `azure_speech` iOS/macOS Swift plugin currently calls `SPXSpeechSynthesizer.speakText` with no word-boundary handler, so every Apple Craft save produces a blank transcript (ADR-0063). The Azure Speech SDK pinned at `~> 1.49.0` exposes `addSynthesisWordBoundaryEventHandler` (stable since 1.7.0/1.21.0) — registering it before `speakText` and emitting the same `{text, audioOffset, duration}` JSON shape Android/Windows already emit closes the gap with **no podspec bump and no Dart parser change**. Cross-platform gotcha: Swift's `duration` is in **seconds**, not ticks — convert `Int(d * 10_000_000)`; the `boundaryType` enum collides on ObjC so punctuation is classified by text on the Dart side as today.

2. **Shadow-friendly segmentation (quality, FR-003–FR-008)** — replace the fixed 6-word chunking with a duration-aware segmenter sized to one shadowable thought/breath group. Research (research.md §R1–R7) grounds the window: **min 1.2 s, soft-max 6.0 s, hard-max 7.0 s**. Splits prefer, in order: sentence-end → clause punctuation (incl. CJK `、，；：`) → largest inter-word silence gap → hard cap. CJK text (detected via `primaryLanguageSubtag(synthLanguage) ∈ {zh,ja,ko}`) breaks by punctuation + duration, never by word count. No schema, wire-format, or domain-shape change (`timelineJson` stays `[{text, start, duration}]`; `CraftWordBoundary` keeps its 3 fields; `primaryTimelineJson: String?` stays nullable). Blank-transcript fallback (ADR-0063) is preserved for BYOK OpenAI TTS and Linux.

## Technical Context

**Language/Version**: Dart 3 (Flutter); Swift 5 (iOS/macOS native plugin). No new languages introduced.

**Primary Dependencies**: `media_kit` (unchanged), `azure_speech` vendored plugin (`packages/azure_speech/`, iOS/macOS Swift fix), `MicrosoftCognitiveServicesSpeechSDK` pod `~> 1.49.0` (already pinned — no bump). No new pub dependencies; no on-device ML runtime.

**Storage**: Drift (`AppDatabase`) — **no schema change**. `transcripts.timelineJson` (TEXT, JSON array `[{text, start, duration}]`) is reused verbatim. `primaryTimelineJson: String?` already nullable on `importCraftedFromText` / `updateCraftedFromText`.

**Testing**: `flutter test` (Dart unit + widget). Segmenter is pure Dart — unit-tested headlessly on all platforms. Native iOS/macOS change validated by device/simulator manual run (quickstart.md Scenario B) since the Swift plugin has no hostless test harness today. CI gates: `bash .github/scripts/validate_ci_gates.sh` (format + codegen drift + analyze + test).

**Target Platform**: Android, iOS, macOS, Windows (word-boundary paths). Linux and BYOK OpenAI TTS remain blank-transcript + STT fallback (unchanged, out of scope). No Flutter web.

**Project Type**: Cross-platform Flutter desktop/mobile app (feature-first layout under `lib/features/<feature>/{application,data,domain,presentation}`).

**Performance Goals**: SC-006 — Craft save latency for typical short paragraphs (< 500 chars) regresses ≤ 10% wall time. Segmentation is pure-Dart over a short boundary list (tens of items); native boundary capture adds only event-append overhead during an already-blocking synthesis call. No hot-path (playback/scroll/startup) impact — segmenter runs once at save.

**Constraints**: Segmentation must stay off the player's playback/scroll hot paths (runs once at Craft save, output persisted). Native handler appends to a captured array on a background SDK thread (no main-thread blocking). No new native binary deps; no model downloads; offline segmentation (synthesis itself still needs network).

**Scale/Scope**: 2 native files (iOS + macOS Swift plugin — shared implementation), 1 new Dart util (CJK language helper), 1 Dart segmenter redesign + its test suite, 1 controller call-site threading the synth language. No UI/screen changes; no new ADR-required decisions (behavior change documented in existing `docs/features/craft.md`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

Pre-research (constitution v1.2.0) — **PASS**:

| Principle | Status | Note |
|---|---|---|
| I. Architecture & Code Quality | PASS | Segmenter stays in `lib/features/craft/domain/`; new CJK helper in `lib/core/`; persistence via existing Drift DAO; Riverpod/controller orchestration unchanged. No feature-to-feature shortcuts. |
| II. Testing Defines the Contract | PASS | Segmenter redesign is pure Dart → unit tests (FR-003…FR-008, FR-011). Existing locked segmenter contracts preserved or intentionally updated (research.md §R9.3). Native Swift change has manual verification path (quickstart.md B). |
| III. UX Consistency | PASS | No new UI; no new strings (segmentation is invisible). Existing player transcript panel + empty/generate affordance reused unchanged. |
| IV. Performance Is a Requirement | PASS | SC-006 sets a ≤10% save-latency budget; segmentation runs once at save, off hot paths; evidence path in quickstart.md F. |
| V. Documentation & Traceability | PASS | `docs/features/craft.md` "Word-segmented transcript" section updated with the behavior change in the same PR. No new ADR needed (no costly-to-reverse architectural decision; ADR-0063 blank-policy is preserved, not superseded). |
| Flutter Quality Gates | PASS | `validate_ci_gates.sh` (format/codegen/analyze/test) is the gate. `dart run build_runner build` only if annotations change (none expected). No `media_kit` Player ownership change. Logging via `logNamed`. |

Post-Phase-1-design re-check — **PASS** (no change): the design introduces no new principle violation. The CJK helper is a small stateless util in `lib/core/`, not a singleton or cross-feature coupling. The Swift plugin change is confined to the vendored package's existing files. The method-channel contract is unchanged (contracts/azure-speech-word-boundaries.md documents the existing shape; Swift now produces it). No `Complexity Tracking` entries required.

## Project Structure

### Documentation (this feature)

```text
specs/032-craft-shadow-cues/
├── plan.md                                          # This file
├── spec.md                                          # /speckit.specify output
├── checklists/requirements.md                       # Spec quality checklist
├── research.md                                      # Phase 0: R1–R7 pedagogy, R8 Swift SDK, R9 architecture
├── data-model.md                                    # Phase 1: entities, segmentation algorithm, validation rules
├── quickstart.md                                    # Phase 1: validation scenarios A–G
├── contracts/
│   └── azure-speech-word-boundaries.md             # Phase 1: method-channel JSON contract
└── tasks.md                                         # Phase 2 (/speckit.tasks — NOT created here)
```

### Source Code (repository root)

```text
packages/azure_speech/
├── ios/Classes/AzureSpeechPlugin.swift              # EDIT: register addSynthesisWordBoundaryEventHandler
├── macos/Classes/AzureSpeechPlugin.swift            # EDIT: same as iOS (shared Swift impl)
├── android/src/main/kotlin/.../AzureSpeechPlugin.kt # REFERENCE (no change — contract source)
├── windows/azure_speech_plugin.cpp                  # REFERENCE (no change — contract source)
└── lib/src/
    ├── method_channel_azure_speech.dart             # NO CHANGE (already decodes the JSON)
    └── azure_speech_synthesis_outcome.dart          # NO CHANGE (AzureWordBoundary shape)

lib/core/
└── application/                  # NEW: small CJK language helper
    └── (e.g. cjk_language.dart)  # primaryLanguageSubtag(tag) ∈ {zh,ja,ko}; pure fn

lib/features/craft/
├── domain/
│   ├── craft_synthesizer.dart              # NO CHANGE (CraftWordBoundary 3-field shape kept)
│   └── word_boundary_segmenter.dart        # REWRITE: duration + clause + pause segmentation,
│                                           #   CJK branch, ShadowLineBudget, BreakPriority
└── application/
    └── craft_controller.dart               # EDIT: thread state.synthLanguage into
                                            #   buildCraftPrimaryTimelineJson at the single save call-site

lib/features/library/data/
└── library_repository.dart                 # NO CHANGE (primaryTimelineJson: String? already nullable)

lib/data/
├── db/                                     # NO CHANGE (no schema/migration)
└── subtitle/transcript_line.dart           # NO CHANGE ({text,start,duration} consumer)

docs/features/
└── craft.md                                # EDIT: "Word-segmented transcript" section updated

test/features/craft/domain/
└── word_boundary_segmenter_test.dart       # REWRITE: update word-count-chop expectations to the
                                            #   new duration/clause/pause algorithm; add CJK + clause +
                                            #   pause-gap + shadow-window cases; preserve empty/blank/timing/wire contracts
```

**Structure Decision**: Feature-first layout (constitution principle I) — the segmentation logic stays in `lib/features/craft/domain/` (its sole consumer is Craft), the CJK helper goes in `lib/core/` (language-agnostic, reusable), and the native change is confined to the vendored `azure_speech` package's existing Swift files. No new feature module, no new package, no new screen. The single external contract (method channel) is documented in `contracts/` and is an existing shape that Swift now conforms to.

## Complexity Tracking

No constitution violations to justify. None of the principles are bent: no new project/package, no repository-pattern shortcut, no singleton, no media_kit ownership change, no web target. The design reuses existing modules, primitives, storage, and contracts.
