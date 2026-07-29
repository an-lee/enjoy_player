# Tasks: Word Pronounce Playback

**Input**: Design documents from `specs/031-word-pronounce/`

**Prerequisites**: plan.md (required), spec.md (required for user stories), research.md, data-model.md, contracts/, quickstart.md

**Tests**: Required for changed contracts (constitution + plan). Manual E2E per [quickstart.md](./quickstart.md).

**Organization**: Tasks are grouped by user story to enable independent implementation and testing of each story.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (e.g., US1, US2, US3)
- Include exact file paths in descriptions

## Path Conventions

- **Feature**: `lib/features/pronounce/{application,domain,presentation}/`
- **API**: `lib/data/api/services/ai/pronounce_api.dart`
- **Surfaces**: `lib/features/lookup/presentation/dictionary_lookup_sheet.dart`, `lib/features/vocabulary/presentation/vocabulary_flashcard.dart`, `lib/features/shadow_reading/presentation/assessment_result_dialog.dart`
- **Tests**: `test/features/pronounce/`, `test/data/api/services/ai/`
- **l10n**: `lib/l10n/app_*.arb`
- **Docs**: `docs/features/dictionary-lookup.md`, `vocabulary.md`, `shadow-reading.md`, `docs/decisions/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Scaffold feature module and confirm touch points

- [X] T001 Create directory scaffolding `lib/features/pronounce/{application,domain,presentation}/` and `test/features/pronounce/{application,domain,presentation}/` per [plan.md](./plan.md)
- [X] T002 [P] Confirm surface edit points: header actions in `lib/features/lookup/presentation/dictionary_lookup_sheet.dart`, headword layout in `lib/features/vocabulary/presentation/vocabulary_flashcard.dart`, selected-word panel in `lib/features/shadow_reading/presentation/assessment_result_dialog.dart`; confirm `package:audioplayers` already in `pubspec.yaml`
- [X] T003 [P] List ADR/doc/l10n targets: next free ADR under `docs/decisions/` for word-pronounce client; feature docs + ARB keys for play/stop/unavailable/loading tooltips and error notices

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Domain types, Worker API, service, app-wide playback controller, shared button, ARB — required before any surface wiring

**⚠️ CRITICAL**: No user story work can begin until this phase is complete

- [X] T004 [P] Implement locale resolver `resolvePronounceLocale` mapping learning/lookup tags to Worker allowlist (`en-UK`→`en-GB`; exact match for `zh-CN`/`ja-JP`/`ko-KR`/`es-*`/`fr-*`/`de-DE`/`it-IT`/`pt-*`/`ru-RU`; else `null`) in `lib/features/pronounce/domain/pronounce_locale.dart` per [research.md](./research.md) R4
- [X] T005 [P] Add `PronounceTarget` and playback state enums/types in `lib/features/pronounce/domain/pronounce_target.dart` (text, localeTag, resolvedLocale, surfaceId; idle/loading/playing/error)
- [X] T006 [P] Add `PronounceResult` DTO parse (snake_case JSON → Dart) in `lib/features/pronounce/domain/pronounce_result.dart` per [contracts/worker-pronounce-api.md](./contracts/worker-pronounce-api.md)
- [X] T007 Implement `PronounceApi` (`POST /pronounce`) in `lib/data/api/services/ai/pronounce_api.dart` and register `pronounceApi` provider in `lib/data/api/services/ai/ai_api_providers.dart`
- [X] T008 Implement `PronounceService` with `guardAiCall` in `lib/features/pronounce/application/pronounce_service.dart` (wire Riverpod provider; map 401/402 via existing failure helpers)
- [X] T009 Implement keepAlive `PronouncePlaybackController` (single `AudioPlayer` + `UrlSource`, generation guard, session URL LRU, `play`/`stop`) in `lib/features/pronounce/application/pronounce_playback_controller.dart` per [contracts/pronounce-playback-controller.md](./contracts/pronounce-playback-controller.md); use `package:logging` via `logNamed`, never `media_kit`
- [X] T010 [P] Add ARB strings (play/stop/loading/unavailable language/empty/errors) to `lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_CN.arb`; run `flutter gen-l10n`
- [X] T011 Implement shared `PronounceIconButton` (idle/loading/playing/disabled, tooltips, `EnjoyTappableIcon` or tonal icon chrome, haptics) in `lib/features/pronounce/presentation/pronounce_icon_button.dart` per [contracts/pronounce-control-ui.md](./contracts/pronounce-control-ui.md)
- [X] T012 Run `dart run build_runner build` for new `@Riverpod` annotations and commit generated `*.g.dart` under `lib/features/pronounce/` and `lib/data/api/services/ai/`
- [X] T013 [P] Unit test locale resolver in `test/features/pronounce/domain/pronounce_locale_test.dart`
- [X] T014 [P] Unit test `PronounceResult` / API JSON parse in `test/data/api/services/ai/pronounce_api_test.dart` (or domain parse test)
- [X] T015 [P] Unit test playback controller transitions (play→loading→playing→stop; stale generation ignored; second play same target stops) in `test/features/pronounce/application/pronounce_playback_controller_test.dart` with mocked service/player as needed
- [X] T016 [P] Widget test `PronounceIconButton` states (disabled unsupported locale, loading, playing tooltip) in `test/features/pronounce/presentation/pronounce_icon_button_test.dart`

**Checkpoint**: Foundation ready — button + controller work in isolation; user story surface wiring can begin

---

## Phase 3: User Story 1 - Hear a looked-up word (Priority: P1) 🎯 MVP

**Goal**: Lookup header offers tap-to-play model pronunciation for the selected term with responsive busy/stop and auth/credits/error handling.

**Independent Test**: Open lookup on English selection → tap header pronounce → audio plays → tap stops; non-English source disables control; signed-out/credits/errors non-destructive ([spec.md](./spec.md) US1, [quickstart.md](./quickstart.md) §1).

### Tests for User Story 1

- [X] T017 [P] [US1] Widget/pump test: lookup header includes pronounce control and dispose calls stop (mock controller) in `test/features/lookup/presentation/dictionary_lookup_sheet_pronounce_test.dart`

### Implementation for User Story 1

- [X] T018 [US1] Wire `PronounceIconButton` into lookup header action row (with bookmark/copy/close) in `lib/features/lookup/presentation/dictionary_lookup_sheet.dart`; target = selection text + source language; disable when empty/over 200 chars/unsupported locale
- [X] T019 [US1] On lookup sheet dispose (and language change if needed), call `PronouncePlaybackController.stop()` from `dictionary_lookup_sheet.dart`
- [X] T020 [US1] Map `AuthFailure` / `CreditsFailure` / network errors from pronounce taps to existing lookup patterns (`AuthRequiredCallout` and/or `AppNotice`) without stuck loading in `dictionary_lookup_sheet.dart` / `pronounce_icon_button.dart` as appropriate

**Checkpoint**: US1 MVP — lookup pronounce independently demoable without flashcard/assessment work

---

## Phase 4: User Story 2 - Hear the flashcard headword (Priority: P2)

**Goal**: Flashcard front and back headword rows play model pronunciation; distinct from Context “Play segment”; stop on flip/rate.

**Independent Test**: Review card → tap speaker beside headword front/back → audio matches headword; Context media chips unchanged; flip/rate while playing stops audio ([spec.md](./spec.md) US2, [quickstart.md](./quickstart.md) §2).

### Tests for User Story 2

- [X] T021 [P] [US2] Widget test: flashcard exposes pronounce beside headword and flip triggers stop (mock controller) in `test/features/vocabulary/presentation/vocabulary_flashcard_pronounce_test.dart`

### Implementation for User Story 2

- [X] T022 [US2] Add pronounce control beside headword on card front in `lib/features/vocabulary/presentation/vocabulary_flashcard.dart` (not in Context `_MediaAction` row); locale from card/learning language via `resolvePronounceLocale`
- [X] T023 [US2] Add pronounce control beside back header headword in `vocabulary_flashcard.dart` (above tabs); same target as front
- [X] T024 [US2] Call `stop()` on flip, rate, and session dispose/next-card transitions from `vocabulary_flashcard.dart` and/or `lib/features/vocabulary/presentation/vocabulary_review_session_screen.dart` as needed

**Checkpoint**: US2 independently testable with mocked pronounce; does not require assessment UI

---

## Phase 5: User Story 3 - Hear the assessed word from results (Priority: P3)

**Goal**: Assessment selected-word panel plays model pronunciation for the chosen chip word; stop on chip change/dismiss.

**Independent Test**: Open assessment result → select chip → tap pronounce in selected-word detail → model audio; change chip stops prior play; no per-chip speakers ([spec.md](./spec.md) US3, [quickstart.md](./quickstart.md) §3).

### Tests for User Story 3

- [X] T025 [P] [US3] Widget test: selected-word panel shows pronounce only when a word is selected; chip change stops playback (mock) in `test/features/shadow_reading/presentation/assessment_result_pronounce_test.dart`

### Implementation for User Story 3

- [X] T026 [US3] Wire `PronounceIconButton` into `_SelectedWordPanel` (or equivalent) header next to selected word in `lib/features/shadow_reading/presentation/assessment_result_dialog.dart`; do not add controls on every chip
- [X] T027 [US3] Stop playback on chip selection change and dialog/sheet dispose in `assessment_result_dialog.dart`
- [X] T028 [US3] Ensure pronounce plays **model** Worker audio only (never user take / `recordingPreviewPlayerProvider`) in assessment wiring

**Checkpoint**: All three surfaces independently functional

---

## Phase 6: Polish & Cross-Cutting Concerns

**Purpose**: Docs, ADR, quality gates, quickstart validation

- [X] T029 [P] Write ADR `docs/decisions/00xx-word-pronounce-client.md` (Worker `/pronounce` + shared control; lookup TTS follow-up to ADR-0019); link from `docs/decisions/README.md`
- [X] T030 [P] Update `docs/features/dictionary-lookup.md` with header pronounce behavior and learning/lookup locale coverage
- [X] T031 [P] Update `docs/features/vocabulary.md` with flashcard headword pronounce vs Play segment
- [X] T032 [P] Update `docs/features/shadow-reading.md` with assessment selected-word model pronounce
- [X] T033 Verify no overlapping streams / stuck spinners across surfaces; spot-check SC-002/003 manually per [quickstart.md](./quickstart.md)
- [X] T034 Run `bash .github/scripts/validate_ci_gates.sh --fix`, `flutter analyze`, and `flutter test` for pronounce + touched surface tests; fix until green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies — start immediately
- **Foundational (Phase 2)**: Depends on Setup — **BLOCKS** all user stories
- **User Stories (Phase 3–5)**: Depend on Foundational; then US1 → US2 → US3 recommended (shared button already done; stories are mostly surface wiring)
- **Polish (Phase 6)**: After desired stories complete (minimum: US1 for MVP)

### User Story Dependencies

- **US1 (P1)**: After Phase 2 only — MVP
- **US2 (P2)**: After Phase 2; reuses shared button/controller; independently testable
- **US3 (P3)**: After Phase 2; independently testable

### Within Each User Story

- Tests marked first where listed; implementation follows
- Surface wire → cancel hooks → error UX
- Story complete before next priority unless parallel staffing

### Parallel Opportunities

- Phase 1: T002, T003 in parallel after T001
- Phase 2: T004–T006 parallel; T013–T016 parallel after T012; T010 parallel with domain/API once keys known
- After Phase 2: US1/US2/US3 surface tasks can run in parallel on different files
- Phase 6: T029–T032 docs in parallel

---

## Parallel Example: Foundational

```bash
# After scaffolding:
Task: "Locale resolver in lib/features/pronounce/domain/pronounce_locale.dart"
Task: "PronounceTarget in lib/features/pronounce/domain/pronounce_target.dart"
Task: "PronounceResult in lib/features/pronounce/domain/pronounce_result.dart"

# After controller + button + codegen:
Task: "Locale unit tests in test/features/pronounce/domain/pronounce_locale_test.dart"
Task: "API parse tests in test/data/api/services/ai/pronounce_api_test.dart"
Task: "Controller tests in test/features/pronounce/application/pronounce_playback_controller_test.dart"
Task: "Button widget tests in test/features/pronounce/presentation/pronounce_icon_button_test.dart"
```

## Parallel Example: User Stories (post-foundation)

```bash
Task: "Lookup header wire in dictionary_lookup_sheet.dart"          # US1
Task: "Flashcard headword wire in vocabulary_flashcard.dart"       # US2
Task: "Assessment selected-word wire in assessment_result_dialog.dart"  # US3
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1: Setup
2. Phase 2: Foundational (API + controller + shared button)
3. Phase 3: Lookup header pronounce
4. **STOP and VALIDATE** via quickstart §1
5. Ship/demo MVP

### Incremental Delivery

1. Setup + Foundational → shared pronounce stack ready
2. US1 Lookup → MVP
3. US2 Flashcard → review loop
4. US3 Assessment → practice feedback loop
5. Polish docs + CI gates

### Parallel Team Strategy

1. Pair completes Phase 1–2
2. Then: Dev A US1, Dev B US2, Dev C US3 (different presentation files)
3. Merge polish/docs together

---

## Notes

- Do **not** use Craft `TtsService` or `media_kit` `Player` for this feature ([research.md](./research.md) R1/R3)
- Omit `voice` on POST; Worker defaults ([contracts/worker-pronounce-api.md](./contracts/worker-pronounce-api.md))
- Unsupported locales only: disable with tooltip — never fall back to a different language’s voice
- Commit after each logical group; regenerate `*.g.dart` when annotations change
