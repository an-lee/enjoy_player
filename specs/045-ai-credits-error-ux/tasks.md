---
description: "Task list for feature 045-ai-credits-error-ux"
---

# Tasks: Friendly AI Credits-Exhausted Errors

**Input**: Design documents from `/specs/045-ai-credits-error-ux/`

**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/worker-402-envelope.md, contracts/client-presentation-api.md, quickstart.md — all present.

**Tests**: Included throughout. The tasks template marks tests optional, but Enjoy Player's constitution (Principle II: "Testing Defines the Contract") requires the narrowest automated tests for every behavior change; the plan's Constitution Check commits to them. Each surface task bundles its test update so tasks stay atomic.

**Organization**: Grouped by user story (US1 P1 message everywhere → US2 P2 recovery CTA → US3 P3 resume after purchase), preceded by shared infrastructure.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: parallelizable — different files, no dependency on incomplete tasks in the same phase
- **[Story]**: US1/US2/US3 per spec.md; Setup/Foundational/Polish carry no label

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: The localized strings every later task consumes.

- [x] T001 Add new ARB keys to `lib/l10n/app_en.arb`, `lib/l10n/app_zh.arb`, and `lib/l10n/app_zh_CN.arb`: `creditsExhaustedDetailed` (placeholders: required, remaining), `creditsExhaustedResets` (placeholder: time), `byokProviderBillingMessage`. Then regenerate and commit localized files (`flutter gen-l10n` → `lib/l10n/app_localizations.dart` + locale parts). English copy per contracts/client-presentation-api.md; zh/zh_CN translated consistently; reuses existing `subscriptionCreditsLimitMessageWithPackages` and `subscriptionViewPlansAndPackages` (do not duplicate).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Failure model, classification seam, and presentation seam every story builds on. Consume the worker contract per contracts/worker-402-envelope.md.

- [x] T002 Enrich `CreditsFailure` in `lib/core/errors/app_failure.dart` with `requiredCredits`, `usedCredits`, `limitCredits`, `resetAt` (nullable, const-compatible) and derived `remainingCredits` getter; add `CreditsFailure.fromApiException(ApiException e)` best-effort parser (camelCase envelope keys `error`/`required`/`limit.used`/`limit.limit`/`limit.resetAt`; non-map/missing/garbage → nulls; never throws; negatives clamp to null) and new `ProviderBillingFailure extends AppFailure`. Per data-model.md §1–3.
- [x] T003 Unit-test the envelope parser by extending `test/core/errors/app_failure_test.dart`: full envelope populates all fields; `resetAt` parsed as UTC; each field independently missing → null; non-map body, null body, raw-string body (JSON-decode fallback), negative/non-numeric values → nulls; `remainingCredits` math and null propagation.
- [x] T004 Add `final bool byokProvider` (default `false`) to `ApiException` in `lib/data/api/api_exception.dart`; set it `true` in `throwByokHttpError` in `lib/features/ai/data/byok/byok_http_client.dart` (only BYOK HTTP exit point). Extend `test/features/ai/data/byok/byok_http_client_test.dart` to assert the flag on a canned 402.
- [x] T005 Update classification: in `lib/features/ai/application/ai_api_failures.dart` `mapApiExceptionToAppFailure` — `402 && byokProvider` → `ProviderBillingFailure`, `402 && !byokProvider` → `CreditsFailure.fromApiException(e)`, 401/other statuses unchanged; switch the repository mappers in `lib/features/credits/data/credits_packages_repository.dart` and `lib/features/subscription/data/subscription_repository.dart` to construct `CreditsFailure` via the same factory. Per contracts/client-presentation-api.md classification table.
- [x] T006 Create `test/features/ai/application/ai_api_failures_test.dart` with the classification matrix (Enjoy 402 → CreditsFailure with envelope fields; BYOK 402 → ProviderBillingFailure; 401 → AuthFailure(sessionRevoked); 409 subscription → SubscriptionConflictFailure; 5xx → NetworkFailure), and update the existing 402 pin in `test/features/ai/chat_service_test.dart` if it constructs `CreditsFailure` positionally.
- [x] T007 Build the presentation seam in `lib/features/subscription/presentation/credits_failure_actions.dart`: `creditsFailureMessage(CreditsFailure, AppLocalizations)` (numbered message + reset time when envelope present, `subscriptionCreditsLimitMessageWithPackages` fallback, never returns `failure.message`), `creditsCtaLabel(AppLocalizations)`, and `showCreditsFailureNotice(BuildContext, CreditsFailure)` using `AppNotice.error` + `SnackBarAction(creditsCtaLabel, → context.push('/subscription'))`. Absorb `showCreditsFailureWithUpgradeAction` (single new API; remove the old name) per research.md D3.
- [x] T008 Update `test/features/subscription/presentation/credits_failure_actions_test.dart`: numbered message renders (required/remaining/time), fallback copy when envelope absent, CTA label, and action tap navigates to `/subscription` (existing GoRouter harness); assert no raw `HTTP 402`/server text in rendered output.

**Checkpoint**: Foundation ready — `flutter analyze` and `flutter test test/core/errors/ test/features/ai/application/ test/features/subscription/presentation/credits_failure_actions_test.dart` green.

---

## Phase 3: User Story 1 — Understandable error on every AI feature (Priority: P1) 🎯 MVP

**Goal**: No surface shows `HTTP 402` or raw server text for a credits rejection; every surface shows the localized (numbered when available) credits message.

**Independent Test**: Force a 402 (exhausted free account or canned envelope) on each surface in quickstart.md's table → localized credits message; non-402 failures unchanged.

- [x] T009 [P] [US1] Dictionary section: in `lib/features/lookup/presentation/sections/dictionary_lookup_section.dart`, route the existing `CreditsFailure` branch's message through `creditsFailureMessage` (bypass `lookupErrorUserMessage` for this branch or special-case it in `lib/features/lookup/presentation/widgets/lookup_error_row.dart`); update the credits case in `test/features/lookup/presentation/sections/dictionary_lookup_section_test.dart` to assert the friendly message and no raw text.
- [x] T010 [P] [US1] Translation section: same swap in `lib/features/lookup/presentation/sections/translation_lookup_section.dart` (no dedicated test file exists — add the credits-message assertion alongside the dictionary harness pattern, e.g. extend `test/features/lookup/presentation/sections/dictionary_lookup_section_test.dart` or create `translation_lookup_section_test.dart`).
- [x] T011 [P] [US1] Contextual section: add a `CreditsFailure` branch (mirrors the sibling sections) in `lib/features/lookup/presentation/sections/contextual_translation_lookup_section.dart` with `creditsFailureMessage`; add the credits case to `test/features/lookup/presentation/sections/contextual_translation_lookup_section_test.dart` (file covers generic + auth today).
- [x] T012 [P] [US1] Pronounce: in `lib/features/pronounce/presentation/pronounce_icon_button.dart`, replace the static `pronounceCreditsExhausted` body with `creditsFailureMessage` (keep `AppNotice.warning` severity); extend `test/features/pronounce/presentation/pronounce_icon_button_test.dart` with a credits-failure case.
- [x] T013 [P] [US1] Auto-translate render site: in `lib/features/transcript/presentation/subtitle_track_picker_sheet.dart` (blocked-credits row, ~:415-429), swap `subtitlesAutoTranslateBlockedCredits` for `creditsFailureMessage` (state machine `AutoTranslateBlockReason.credits` in `lib/features/transcript/application/auto_translate_controller.dart` stays as-is); extend the credits case in `test/features/transcript/auto_translate_controller_test.dart` if it asserts the rendered key, plus a render assertion in the sheet's test if one exists.
- [x] T014 [P] [US1] ASR: carry the credits failure kind/envelope through the job state — `lib/features/asr/application/asr_generation_controller.dart` (`_mapProviderError` keeps `asrErrorCreditsExhausted` as lead-in; add failure-kind flag or envelope next to `errorMessage`) — and render the numbered body in `lib/features/asr/presentation/asr_generation_launcher.dart` (optionally use the currently-unused `asrErrorCreditsExhaustedHint` from the ARB as supporting line); extend the `CreditsFailure → asrErrorCreditsExhausted` test in `test/features/asr/application/asr_generation_controller_test.dart` (~:174) to cover the new state field.
- [x] T015 [P] [US1] Shadow-reading assessment: add `RecordingAssessmentFailureKind.credits` and a `CreditsFailure` catch branch (no `debugMessage` leak) in `lib/features/shadow_reading/application/recording_assessment_controller.dart`; map the new kind to `creditsFailureMessage` in the failure-message switch used by `lib/features/shadow_reading/presentation/recording_assessment_flow.dart`; add the credits branch case to `test/features/shadow_reading/recording_assessment_controller_test.dart` (asserting kind, not `serviceError`).
- [x] T016 [P] [US1] Craft: add a credits kind to `CraftTranslateFailure`/`CraftAsrFailure`/`CraftTtsFailure` in `lib/features/craft/domain/craft_failure.dart` (raw-exception-text ban preserved) and map `CreditsFailure` in the catches/`_mapTtsFailure` of `lib/features/craft/application/craft_controller.dart`; render `creditsFailureMessage` at the five surfaces — `lib/features/craft/presentation/translate_tool.dart`, `capture_stage.dart`, `rewrite_stage.dart`, `audio_stage.dart`, `synthesize_tool.dart` (message text only in this story; CTA is US2); update `test/features/craft/domain/craft_failure_test.dart` + `test/features/craft/presentation/craft_failure_card_test.dart` for the new kind.
- [x] T017 [P] [US1] Vocabulary: add a `'credits'` error token (distinct from `'fetch_failed'`) in the catches of `lib/features/vocabulary/application/vocabulary_review_session.dart` (dictionary + contextual), and render `creditsFailureMessage` instead of the network-flavored copy in `lib/features/vocabulary/presentation/widgets/vocabulary_flashcard_dictionary_tab.dart` and `vocabulary_flashcard_context_tab.dart`; add widget tests for both tabs' credits token.
- [x] T018 [P] [US1] Purchase-path surfaces (FR-010): locate where `CreditsFailure` from `lib/features/credits/data/credits_packages_repository.dart` and `lib/features/subscription/data/subscription_repository.dart` is displayed (grep their consumers under `lib/features/subscription/presentation/` and `lib/features/credits/presentation/`, e.g. packages purchase button) and route those error slots through `creditsFailureMessage`; assert in the closest existing widget test that no raw `HTTP 402` renders.
- [x] T019 [US1] Story verification: run `flutter test` for all touched suites plus `flutter analyze`; confirm quickstart.md rows 1–11 "message" expectations manually (or via canned-envelope stub) and that non-402 failures (network/auth/5xx) render exactly as before on the surfaces touched.

**Checkpoint**: MVP complete — every AI surface shows the friendly localized credits message; zero raw `HTTP 402` in user-visible UI (AI playground exempt, documented).

---

## Phase 4: User Story 2 — One-tap path to resolve (Priority: P2)

**Goal**: Every credits error carries the single CTA (`View plans & packages`) that lands on `/subscription` in one tap.

**Independent Test**: From each surface, force a 402 and tap the CTA → `/subscription` opens (quickstart.md rows 1–11 "CTA" expectations; widget nav tests).

*Per-surface CTA tasks depend on the same surface's US1 task (branch/kind/state introduced there).*

- [x] T020 [P] [US2] Lookup sections: relabel the existing inline CTA to `creditsCtaLabel` in `lib/features/lookup/presentation/sections/dictionary_lookup_section.dart` and `translation_lookup_section.dart` (replacing `subscriptionViewPlans`); keep `context.push('/subscription')`.
- [x] T021 [P] [US2] Contextual section: add the `creditsCtaLabel` action (TextButton → `/subscription`) next to the retry row in `lib/features/lookup/presentation/sections/contextual_translation_lookup_section.dart`; extend its test with a tap-navigates assertion.
- [x] T022 [P] [US2] Pronounce: attach the `SnackBarAction` CTA by switching `lib/features/pronounce/presentation/pronounce_icon_button.dart` credits branch to `showCreditsFailureNotice` (keeps warning tone via copy, or `AppNotice.warning` + action if supported); assert action presence/tap in `test/features/pronounce/presentation/pronounce_icon_button_test.dart`.
- [x] T023 [P] [US2] Auto-translate: add a `creditsCtaLabel` `TextButton` to the blocked-credits row in `lib/features/transcript/presentation/subtitle_track_picker_sheet.dart` (→ `/subscription`).
- [x] T024 [P] [US2] ASR: attach the snackbar action in `lib/features/asr/presentation/asr_generation_launcher.dart` using the failure-kind flag from T014 (action appears only for credits kind); cover in the launcher/controller tests.
- [x] T025 [P] [US2] Assessment: add the CTA action to the credits-kind notice in `lib/features/shadow_reading/presentation/recording_assessment_flow.dart` (other kinds keep the plain error).
- [x] T026 [P] [US2] Craft: add a View-plans action variant to `lib/features/craft/presentation/widgets/craft_failure_card.dart` (alongside Retry, using `creditsCtaLabel` → `/subscription`) and wire it for credits kinds at `capture_stage.dart`, `rewrite_stage.dart`, `audio_stage.dart` (and `translate_tool.dart`/`synthesize_tool.dart` inline slots); extend `test/features/craft/presentation/craft_failure_card_test.dart`.
- [x] T027 [P] [US2] Vocabulary tabs: add the `creditsCtaLabel` button (→ `/subscription`) beside the retry control in `lib/features/vocabulary/presentation/widgets/vocabulary_flashcard_dictionary_tab.dart` and `vocabulary_flashcard_context_tab.dart`; extend both tests.
- [x] T028 [US2] Story verification: every surface's CTA navigates to `/subscription` exactly once (no duplicate actions); repeat-retry while exhausted does not stack snackbars (AppNotice error/warning `clearSnackBars()` behavior) — add/extend a snackbar-replacement widget test near `test/core/notices/app_notice_test.dart` if not already covered.

**Checkpoint**: US1 + US2 — users understand the failure and can act on it in one tap from anywhere.

---

## Phase 5: User Story 3 — Painless resume after resolving (Priority: P3)

**Goal**: After purchasing, users return to intact state and complete the original action without re-entry or restart.

**Independent Test**: quickstart.md recovery loop — exhaust → error → buy (or simulate) → return → retry succeeds; automated preservation tests per surface.

- [x] T029 [P] [US3] Add preservation/retry regression tests for the mid-task surfaces: lookup selection survives a credits error and retry works (`test/features/lookup/presentation/sections/`); ASR media item untouched + regenerate works (`test/features/asr/application/asr_generation_controller_test.dart`); shadow-reading recording kept + re-assess works (`test/features/shadow_reading/recording_assessment_controller_test.dart`); craft captured audio/source text kept + retry works (`test/features/craft/`); auto-translate already-translated lines kept (`test/features/transcript/auto_translate_controller_test.dart`). Pattern: fake capability throws `CreditsFailure` once, then succeeds.
- [x] T030 [P] [US3] BYOK regression (FR-008): with a BYOK provider returning 402 (fake via `byokProvider` ApiException), translation/dictionary/ASR surfaces show the provider-billing message (`byokProviderBillingMessage`) with **no** subscription CTA and no `/subscription` navigation; unit coverage in `test/features/ai/application/ai_api_failures_test.dart` (T006) plus one surface-level widget test.
- [ ] T031 [US3] Story verification: run the quickstart.md recovery loop manually on ≥2 surfaces (one snackbar-idiom, one inline-idiom), including the smallest-package-still-insufficient edge (friendly error reappears cleanly, no stacking, CTA still works), and the pending-entitlement note (retry shows in-progress, not hard failure).

**Checkpoint**: All stories complete — full loop: fail → understand → act → resume.

---

## Phase 6: Polish & Cross-Cutting Concerns

- [x] T032 [P] Update `docs/features/ai.md`: error-translation table gains envelope fields + Enjoy/BYOK 402 split and the presentation seam (contracts/client-presentation-api.md is the source of truth).
- [x] T033 [P] Update user-facing docs: `docs/features/subscription.md` (entry points now every AI surface), `docs/features/dictionary-lookup.md`, `docs/features/transcript.md`, `docs/features/asr.md`, `docs/features/shadow-reading.md`, `docs/features/craft.md`, `docs/features/credits-usage.md` (marginal — message wording only if referenced).
- [x] T034 Run quality gates before push: `flutter analyze`, `flutter test`, `bash .github/scripts/validate_ci_gates.sh` (format + codegen drift; `flutter gen-l10n` output committed by T001; `dart run build_runner build` only if any annotated provider was touched — none planned). Then full quickstart.md manual pass (real exhausted account / real purchase — deferred to T031/manual verification). Status: `flutter analyze` clean of new issues (pre-existing infos remain in untouched test files); `flutter test` 5777 passing; format ok; Riverpod hash drift fixed via `dart run build_runner build` (the `.g.dart` updates commit with this feature — the drift check diffs against HEAD, so it goes green at commit time).

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (T001)**: no dependencies; blocks all rendering tasks (string keys).
- **Phase 2 (T002–T008)**: depends on T001 (T007/T008 render strings); blocks all stories. Within: T003 after T002; T006 after T004+T005; T008 after T007.
- **Phase 3 (US1, T009–T019)**: after Phase 2; all surface tasks T009–T018 parallel (distinct features/files); T019 last.
- **Phase 4 (US2, T020–T028)**: after the corresponding US1 surface task (per spec, US2 builds on US1's message); T020–T027 parallel; T028 last.
- **Phase 5 (US3, T029–T031)**: after US2 (CTA absence assertions for BYOK need final labels); T029–T030 parallel; T031 last.
- **Phase 6 (T032–T034)**: after all stories; T032/T033 parallel; T034 final.

### User Story Independence

- **US1**: independently shippable MVP (message sweep only).
- **US2**: independently testable per surface once its US1 branch exists (navigation/CTA contract).
- **US3**: verification + BYOK split on top of US1/US2 outputs; no controller redesign (state preservation verified already true).

### Parallel Opportunities

- Phase 2: T002/T004 parallel; then T003+T005 parallel; then T006+T007 parallel; T008.
- Phase 3: T009–T018 all parallel (nine distinct feature areas).
- Phase 4: T020–T027 all parallel (same files as US1 but sequential phase → no conflict).
- Phase 5: T029/T030 parallel. Phase 6: T032/T033 parallel.

## Parallel Example: Phase 3 (US1)

```text
T009 dictionary section     T012 pronounce button      T015 shadow reading
T010 translation section    T013 auto-translate sheet  T016 craft (5 files)
T011 contextual section     T014 ASR state+launcher    T017 vocabulary tabs   T018 purchase paths
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. T001 → Phase 2 (T002–T008) → T009–T019 → **stop and validate**: no raw 402 anywhere; ship if desired.
2. US2 (T020–T028): recovery CTA everywhere.
3. US3 (T029–T031): resume guarantees + BYOK split locked by tests.
4. Polish (T032–T034): docs + gates + full manual pass.

### Notes

- Verify per-story with the quickstart.md table column relevant to that story before proceeding.
- Commit after each task or logical group; follow AGENTS.md verification (`flutter analyze` + targeted `flutter test` after every edit).
- AI playground stays raw (internal diagnostics; documented exception to FR-004).
- No server changes; if the Rails 402 body ever needs verified shape, that is a follow-up outside this feature.
