# Tasks: Feature Onboarding Guides

**Input**: Design documents from `/specs/034-feature-onboarding/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/, quickstart.md

**Tests**: Included — constitution and plan require automated coverage for behavior changes (unit + widget); desktop overlay chrome validated manually per quickstart M6.

**Organization**: Tasks are grouped by user story (US1–US4). Shared onboarding module, `showcaseview` host, progress store, and tip ARBs land in Foundational so stories only wire targets + triggers.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Maps to spec user stories (US1–US4)
- Include exact file paths in descriptions

---

## Phase 1: Setup

**Purpose**: Branch hygiene, dependency, and feature module skeleton.

- [x] T001 Confirm branch `034-feature-onboarding` is checked out and design docs exist under `specs/034-feature-onboarding/` (`spec.md`, `plan.md`, `research.md`, `data-model.md`, `contracts/`, `quickstart.md`)
- [x] T002 Add `showcaseview: ^5.1.0` (or latest compatible ^5.x) to `pubspec.yaml` and run `flutter pub get`
- [x] T003 Create package directories `lib/features/onboarding/{domain,application,presentation}/` and `test/features/onboarding/{domain,application,presentation}/`

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Tip catalog, Drift progress keys, Riverpod store/controller, showcase host, shared ARB tip chrome — no Home/Player tip auto-start yet.

**CRITICAL**: No user story wiring begins until this phase is complete.

- [x] T004 [P] Add tip id / sequence enums and catalog constants in `lib/features/onboarding/domain/onboarding_tip_id.dart` per `specs/034-feature-onboarding/contracts/tip-catalog.md`
- [x] T005 [P] Add `TipStatus`, `TipProgressSnapshot`, and JSON parse/serialize helpers in `lib/features/onboarding/domain/tip_progress.dart` per `specs/034-feature-onboarding/data-model.md`
- [x] T006 [P] Add pure `TipEligibility` + `TriggerContext` in `lib/features/onboarding/domain/tip_eligibility.dart` (home / empty-transcript / practice rules from C1; include `blockingOverlay` and zero-size/unpainted target → skip/defer per `contracts/showcase-host.md`)
- [x] T007 [P] Register `SettingsKeys.onboardingTipProgressV1` and `SettingsKeys.onboardingEmptyTranscript(mediaId)` plus `isKnown` prefix `onboarding.empty_transcript.` in `lib/data/db/settings_keys.dart`
- [x] T008 Implement `OnboardingProgress` keepAlive Riverpod notifier in `lib/features/onboarding/application/onboarding_progress_provider.dart` (load/markGlobal/markEmptyTranscript/resetAll via signed-in `appDatabaseProvider` + `SettingsDao`) per `contracts/tip-progress-store.md`
- [x] T009 Implement single-flight `OnboardingController` in `lib/features/onboarding/application/onboarding_controller.dart` (`tryStart*`, complete/skip, dismiss on route/media change, practice chain hook stubs) per `contracts/showcase-host.md`
- [x] T010 [P] Add Enjoy-aligned tooltip styling helper in `lib/features/onboarding/presentation/onboarding_tooltip_theme.dart`
- [x] T011 [P] Add `OnboardingTarget` Showcase wrapper + tip-id → `GlobalKey` registry in `lib/features/onboarding/presentation/onboarding_target.dart` (`disposeOnTap` / `onTargetClick` learn-by-doing)
- [x] T012 Wrap shell once with showcase host in `lib/features/player/presentation/root_shell.dart` (or `lib/app.dart` `_shellBuilder` if preferred) via `lib/features/onboarding/presentation/onboarding_showcase_host.dart`
- [x] T013 [P] Add shared tip ARB keys (titles/bodies for all v1 tips + Next/Skip) in `lib/l10n/app_en.arb` per C1
- [x] T014 [P] Add matching ZH strings in `lib/l10n/app_zh.arb` and `lib/l10n/app_zh_CN.arb`
- [x] T015 Run `dart run build_runner build` and `flutter gen-l10n`; commit generated `*.g.dart` / l10n outputs for new `@Riverpod` providers
- [x] T016 [P] Unit tests for catalog + eligibility in `test/features/onboarding/domain/tip_eligibility_test.dart`
- [x] T017 [P] Unit tests for progress JSON + per-media mark/reset in `test/features/onboarding/application/onboarding_progress_provider_test.dart`

**Checkpoint**: Foundation ready — US1–US4 can wire surfaces independently.

---

## Phase 3: User Story 1 — Discover Craft and Import on Home (Priority: P1) 🎯 MVP

**Goal**: First-time (or reset) Home visit shows Import → Craft showcase tips; skip/dismiss persists; tap-through opens real actions.

**Independent Test**: Reset tips → open Home → tips introduce Import then Craft; skip leaves Home usable and does not return; reset → tap highlighted Import/Craft → real flows open without stuck overlay.

### Tests for User Story 1

- [x] T018 [P] [US1] Widget test Home tip trigger + skip persistence in `test/features/onboarding/presentation/home_onboarding_test.dart` (fake progress; assert sequence order Import then Craft)

### Implementation for User Story 1

- [x] T019 [US1] Wrap Craft and Import controls with `OnboardingTarget` in `lib/features/library/presentation/home_screen.dart` (`_HomeHeaderActions`) using tip ids `home.craft` / `home.import`
- [x] T020 [US1] After first frame on Home, call `OnboardingController.tryStartHomeEntries` from `lib/features/library/presentation/home_screen.dart` when eligibility holds
- [x] T021 [US1] Wire learn-by-doing: target tap invokes existing Craft `push('/craft')` / Import `showImportChooser` and marks tip complete/advances in `lib/features/onboarding/presentation/onboarding_target.dart` + Home callbacks
- [x] T022 [US1] On Skip/dismiss of home sequence, mark pending home tips skipped via `OnboardingProgress` so they do not auto-show again until reset

**Checkpoint**: MVP — Home discovery works without Player tips.

---

## Phase 4: User Story 2 — Get a transcript when the player has none (Priority: P1)

**Goal**: Empty-transcript tips for local vs YouTube; progress per `mediaId`; YouTube gains Fetch CTA; tap-through starts real obtain flows; success auto-completes.

**Independent Test**: Reset → open no-transcript local media → tip; dismiss → same media no re-nag; other no-transcript media may tip again; YouTube shows Fetch CTA tip; obtaining transcript completes that media’s progress.

### Tests for User Story 2

- [x] T023 [P] [US2] Unit tests per-media empty-transcript progress + auto-complete-on-transcript in `test/features/onboarding/application/empty_transcript_progress_test.dart`
- [x] T024 [P] [US2] Widget/unit coverage for YouTube empty Fetch CTA visibility in `test/features/transcript/presentation/transcript_empty_state_test.dart` (or new onboarding-focused test under `test/features/onboarding/`)

### Implementation for User Story 2

- [x] T025 [US2] Add YouTube **Fetch transcript** CTA on empty state calling existing cloud refresh path in `lib/features/transcript/presentation/transcript_empty_state.dart` (+ wire from `transcript_panel.dart`)
- [x] T026 [US2] Wrap the **primary** local empty control (Extract if `showExtractButton`, else Add subtitle) and YouTube Fetch CTA with `OnboardingTarget` tip ids `player.empty_transcript.local` / `player.empty_transcript.youtube` in `lib/features/transcript/presentation/transcript_empty_state.dart` (Generate is not a showcase step in v1)
- [x] T027 [US2] Trigger `OnboardingController.tryStartEmptyTranscript` from `lib/features/transcript/presentation/transcript_panel.dart` when panel shows empty eligible state for current `mediaId`
- [x] T028 [US2] On dismiss/skip/complete empty tip, `markEmptyTranscript(mediaId, …)` so only that media is resolved; learn-by-doing target tap starts real extract/import/generate/fetch
- [x] T029 [US2] When transcript lines become available for `mediaId`, auto-mark empty-transcript progress `completed` in `lib/features/onboarding/application/onboarding_controller.dart` (or progress helper) even if tip never shown

**Checkpoint**: US1 + US2 cover getting into content + obtaining transcript.

---

## Phase 5: User Story 3 — Learn echo, record, and pronunciation assessment (Priority: P2)

**Goal**: With transcript present, same-visit chain echo → record → assess when each control is ready; skip anytime; tap-through runs real controls.

**Independent Test**: Reset tips; open media with transcript; echo tip then record then assess can appear in one visit as ready; skip keeps playback usable; no stacked overlays.

### Tests for User Story 3

- [x] T030 [P] [US3] Unit tests practice-chain eligibility ordering + same-visit next tip in `test/features/onboarding/domain/practice_chain_eligibility_test.dart`


### Implementation for User Story 3

- [x] T031 [US3] Wrap echo toggle with `OnboardingTarget` (`player.echo`) in `lib/features/player/presentation/widgets/global_transport_bar.dart`
- [x] T032 [P] [US3] Wrap record control with `OnboardingTarget` (`player.record`) in `lib/features/shadow_reading/presentation/widgets/shadow_record_fab.dart` (or host that owns the FAB)
- [x] T033 [P] [US3] Wrap assessment control with `OnboardingTarget` (`player.assess`) in `lib/features/shadow_reading/presentation/recording_assessment_button.dart`
- [x] T034 [US3] Implement `tryStartPracticeChain` in `lib/features/onboarding/application/onboarding_controller.dart`: start echo when eligible; after resolve, same-visit start record then assess when `recordUiReady` / `assessUiReady`; enforce single-flight
- [x] T035 [US3] Hook practice chain starts from player/transcript echo region ready state (e.g. after transcript present in expanded player / `transcript_echo_region_merged_card.dart` or transport) without fighting empty-transcript tips
- [x] T036 [US3] Soft auto-complete `player.echo` when echo already active at eligibility time (FR-004b), then proceed to record tip if pending

**Checkpoint**: Full practice discovery loop works on top of US2.

---

## Phase 6: User Story 4 — Reset product tips (Priority: P3)

**Goal**: About → Reset product tips clears all global + per-media onboarding progress after confirmation.

**Independent Test**: Seed completed Home + dismissed empty tip on media A → Reset → confirm → both can show again; library/account untouched; cancel leaves progress intact.

### Tests for User Story 4

- [x] T037 [P] [US4] Widget test About reset row confirm/cancel in `test/features/settings/presentation/reset_product_tips_test.dart` (or under `test/features/onboarding/presentation/`)

### Implementation for User Story 4

- [x] T038 [P] [US4] Add reset ARB keys (`settingsResetProductTips*`) in `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, `lib/l10n/app_zh_CN.arb` per `contracts/reset-product-tips.md`; run `flutter gen-l10n`
- [x] T039 [US4] Add `SettingsRow` + confirmation dialog calling `OnboardingProgress.resetAll()` in `lib/features/settings/presentation/widgets/about_section_card.dart`
- [x] T040 [US4] Ensure `resetAll` deletes `onboarding.tip_progress_v1` and all `onboarding.empty_transcript.*` keys only (extend unit coverage in `test/features/onboarding/application/onboarding_progress_provider_test.dart` if needed)

**Checkpoint**: Learners can rediscover tips without wiping the library.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Docs, ADR, dismiss-on-navigate hardening, CI green, quickstart validation.

- [x] T041 [P] Add feature doc `docs/features/onboarding.md` (catalog, triggers, reset, showcaseview boundary) and link from `docs/README.md`
- [x] T042 [P] Add ADR `docs/decisions/` for feature-onboarding + `showcaseview` choice; update `docs/decisions/README.md`
- [x] T043 Harden `OnboardingController.dismissActive` on route/`mediaId` change and blocking overlays; enforce start guards (zero-size target / `blockingOverlay`) before `startShowCase`; log via `logNamed` in `lib/features/onboarding/application/onboarding_controller.dart` (never `print`)
- [ ] T044 [P] Manual QA checklist pass for quickstart M1–M6 (document results in PR); verify dismiss &lt;2s, desktop resize safety, and tip start feels post-frame (&lt;300ms perceived)
- [x] T045 Run `flutter analyze`, `flutter test test/features/onboarding`, and `bash .github/scripts/validate_ci_gates.sh --fix`; fix until green

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 Setup**: No dependencies
- **Phase 2 Foundational**: Depends on Setup — **BLOCKS** all user stories
- **Phase 3 US1 (P1)**: After Foundational — MVP
- **Phase 4 US2 (P1)**: After Foundational — can proceed in parallel with US1 (different files); practice tips in US3 assume transcript path exists
- **Phase 5 US3 (P2)**: After Foundational; ideally after US2 empty-transcript gating exists so chains do not fight empty tips
- **Phase 6 US4 (P3)**: After Foundational (needs `resetAll`); can parallel US1–US3 once progress API exists
- **Phase 7 Polish**: After desired stories complete

### User Story Dependencies

| Story | Depends on | Notes |
|-------|------------|-------|
| US1 Home | Foundational | No dependency on US2–US4 |
| US2 Empty transcript | Foundational | Independent of US1; adds YouTube CTA |
| US3 Practice chain | Foundational (+ US2 gating recommended) | Must not start while empty-transcript tip active |
| US4 Reset | Foundational | Independently testable with seeded progress |

### Parallel Opportunities

- T004–T007, T010–T011, T013–T014, T016–T017 in Foundational (after T003)
- US1 (T018–T022) ‖ US2 (T023–T029) after Foundational
- US4 (T037–T040) ‖ US1/US2 once `OnboardingProgress.resetAll` exists (T008)
- T031 ‖ T032 ‖ T033 within US3 after controller practice API sketched
- T041 ‖ T042 in Polish

---

## Parallel Example: After Foundational

```bash
# Developer A — MVP Home
Task: T018 home_onboarding_test.dart
Task: T019–T022 home_screen.dart wiring

# Developer B — Empty transcript
Task: T023–T024 tests
Task: T025–T029 transcript_empty_state.dart + transcript_panel.dart

# Developer C — Reset (once T008 done)
Task: T037–T040 about_section_card.dart + ARBs
```

---

## Parallel Example: User Story 3 targets

```bash
Task: "Wrap echo in lib/features/player/presentation/widgets/global_transport_bar.dart"
Task: "Wrap record in lib/features/shadow_reading/presentation/widgets/shadow_record_fab.dart"
Task: "Wrap assess in lib/features/shadow_reading/presentation/recording_assessment_button.dart"
# Then: T034–T036 controller chain + host trigger
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1 + Phase 2
2. Complete Phase 3 (US1 Home)
3. **STOP and VALIDATE** independent test for Home tips
4. Demo Craft/Import discovery

### Incremental Delivery

1. Setup + Foundational → module + host ready
2. US1 Home → MVP demo
3. US2 Empty transcript (+ YouTube Fetch CTA)
4. US3 Practice chain (echo → record → assess)
5. US4 Reset + Polish (docs/ADR/CI)

### Suggested MVP scope

**US1 only** (Home Import/Craft tips + foundational host/progress) — proves the maintainable onboarding system before Player complexity.

---

## Notes

- [P] = different files, no wait on incomplete sibling tasks
- Tip showcase **start order** for Home is Import → Craft (catalog); visual LTR may still be Craft then Import
- YouTube Fetch CTA is required for US2 spotlight (research R3) — not optional polish
- Commit generated `*.g.dart` after Riverpod changes
- Avoid `print()`; use `logNamed`
- Format validation: all tasks below use `- [x] Tnnn …` with paths
