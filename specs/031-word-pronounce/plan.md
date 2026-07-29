# Implementation Plan: Word Pronounce Playback

**Branch**: `031-word-pronounce` | **Date**: 2026-07-30 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/031-word-pronounce/spec.md`

**Note**: `/speckit-clarify` was skipped; defaults locked in [research.md](./research.md) (Worker `/pronounce`, stop-not-pause, learning/lookup locale coverage via Azure).

## Summary

Add tap-to-play **model pronunciation** on three learning surfaces—lookup header, flashcard headword (front/back), and assessment selected-word panel—via Enjoy Worker `POST /pronounce` + public `audio_url` playback. One shared icon button and one app-wide playback session (`audioplayers`, not `media_kit`) keep the UX responsive and prevent overlapping audio.

## Technical Context

**Language/Version**: Dart 3.x / Flutter (stable channel per repo)

**Primary Dependencies**: Flutter, Riverpod, `package:audioplayers`, existing `aiApiClientProvider` / `guardAiCall` / `AppNotice` / `EnjoyTappable*` / ARB l10n; Enjoy Worker pronounce HTTP API

**Storage**: No Drift changes. Optional in-memory session LRU for `(text, locale) → audio_url`

**Testing**: `flutter test` (locale resolve, API DTO, playback notifier state machine, widget button states), `flutter analyze`, `bash .github/scripts/validate_ci_gates.sh --fix`; `dart run build_runner build` for new `@Riverpod` / commit `*.g.dart`

**Target Platform**: Android, iOS, macOS, Windows, Linux (no web)

**Project Type**: Cross-platform Flutter desktop/mobile app

**Performance Goals**: Busy affordance on tap within one frame; audible start &lt;2s on cache hit / &lt;5s cold miss (SC-002); no heavy work in `build`; single `AudioPlayer` instance for pronounce

**Constraints**: No `media_kit` `Player()` outside player engine; no `print()`; widgets must not call HTTP directly; Worker locales = learning + lookup catalog (en/zh/ja/ko/es/fr/de/it/pt/ru regional tags); text ≤200 chars; login + credits for miss path

**Scale/Scope**: New `lib/features/pronounce/` (application + domain + presentation) + thin `PronounceApi` under `lib/data/api/services/ai/` + wiring into lookup / vocabulary flashcard / shadow-reading assessment result; docs + ADR

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Plan response |
|-----------|--------|---------------|
| I. Architecture | Pass | Feature module `lib/features/pronounce/{application,domain,presentation}`; HTTP in `PronounceApi` + `PronounceService` with `guardAiCall`; surfaces only compose shared button / call `stop()` |
| II. Testing | Pass | Unit tests for locale map + notifier transitions; API parse test; widget tests for idle/loading/playing/disabled; manual quickstart for E2E |
| III. UX consistency | Pass | `EnjoyTappableIcon` (or equivalent), tooltips, haptics, ARB; placements per spec; update feature docs |
| IV. Performance | Pass | One player; session URL cache; cancel stale futures; no synth on build |
| V. Documentation | Pass | Update dictionary-lookup / vocabulary / shadow-reading docs; ADR for pronounce client (lookup TTS follow-up from ADR-0019) |
| Flutter Quality Gates | Pass | format + codegen drift + analyze + test; no web; no new media_kit Player |

**Post-design re-check**: Pass — contracts bound Worker HTTP, playback controller, and UI placement only; no unjustified cross-feature imports beyond composing the shared control.

## Project Structure

### Documentation (this feature)

```text
specs/031-word-pronounce/
├── plan.md
├── research.md
├── data-model.md
├── quickstart.md
├── contracts/
│   ├── README.md
│   ├── worker-pronounce-api.md
│   ├── pronounce-playback-controller.md
│   └── pronounce-control-ui.md
└── tasks.md             # /speckit-tasks (not this command)
```

### Source Code (repository root)

```text
lib/data/api/services/ai/
  pronounce_api.dart                 # POST /pronounce
  ai_api_providers.dart              # pronounceApi provider

lib/features/pronounce/
  domain/
    pronounce_target.dart
    pronounce_result.dart
    pronounce_locale.dart            # tag → Worker allowlist locale | null
  application/
    pronounce_service.dart           # guardAiCall + API
    pronounce_playback_controller.dart  # single session + AudioPlayer
  presentation/
    pronounce_icon_button.dart       # shared control

lib/features/lookup/presentation/
  dictionary_lookup_sheet.dart       # header action + dispose stop

lib/features/vocabulary/presentation/
  vocabulary_flashcard.dart          # headword row front/back + flip/rate stop

lib/features/shadow_reading/presentation/
  assessment_result_dialog.dart      # selected-word panel + chip change stop

lib/l10n/app_en.arb (+ zh / zh_CN)
docs/features/dictionary-lookup.md
docs/features/vocabulary.md
docs/features/shadow-reading.md
docs/decisions/00xx-word-pronounce-client.md
docs/decisions/README.md

test/features/pronounce/...
test/data/api/services/ai/pronounce_api_test.dart
```

**Structure Decision**: New `pronounce` feature owns playback + shared control so lookup/vocabulary/shadow_reading stay presentation composers. HTTP stays with other Worker AI clients under `lib/data/api/services/ai/`. Do not extend Craft TTS or `TtsService` for this product path ([research.md](./research.md) R1).

## Complexity Tracking

> No constitution violations requiring justification.

## Phase 0 & 1 outputs

| Artifact | Path |
|----------|------|
| Research | [research.md](./research.md) |
| Data model | [data-model.md](./data-model.md) |
| Contracts | [contracts/](./contracts/) |
| Quickstart | [quickstart.md](./quickstart.md) |

Next: `/speckit-tasks` to decompose by user story (P1 lookup → P2 flashcard → P3 assessment).
