---
description: "Task list for PostHog product analytics integration (feature 046)"
---

# Tasks: PostHog Product Analytics Integration

**Input**: Design documents from `/specs/046-posthog-analytics-integration/`

**Prerequisites**: plan.md, spec.md, research.md (decisions D1–D10), data-model.md, contracts/analytics-facade.md, contracts/event-catalog.md, quickstart.md

**Tests**: Included — Constitution Principle II requires the narrowest automated tests proving each changed contract. Test tasks are first-class per story, not cleanup.

**Organization**: Grouped by user story (spec.md: US1 P1 → US2 P2 → US3 P2 → US4 P2 → US5 P3).

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks)
- **[Story]**: Which user story this task belongs to (US1…US5)
- Exact repo paths included in every description

## Path Conventions

Single Flutter project: `lib/` and `test/` at repository root (test/ mirrors lib/). New capability: `lib/core/analytics/`. Generated Riverpod code: sibling `*.g.dart` (build_runner).

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Vendor dependency + platform manifests ready for manual init

- [x] T001 Add `posthog_flutter: ^5.39.0` to `pubspec.yaml` dependencies and run `flutter pub get`; resolve any dependency conflicts (none expected — repo currently has no posthog reference)
- [x] T002 [P] Verify platform minimums per research D9: `android/app/build.gradle` `minSdkVersion` ≥ 23, `ios/Podfile` `platform :ios` ≥ 13.0, `macos/Runner/Podfile` deployment target per posthog-ios requirement — bump only if a value is below the vendor minimum, and record original values in the PR description
- [x] T003 [P] Disable vendor auto-init (research D1): add `<meta-data android:name="com.posthog.posthog.AUTO_INIT" android:value="false"/>` to `android/app/src/main/AndroidManifest.xml`, and `<key>com.posthog.posthog.AUTO_INIT</key><false/>` to `ios/Runner/Info.plist` and `macos/Runner/Info.plist`

**Checkpoint**: `flutter pub get` clean; plugin present; no auto-init on any Apple/Android target.

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: The `lib/core/analytics/` capability — every user story depends on it

**⚠️ CRITICAL**: No user story work until this phase is complete.

- [x] T004 Create `lib/core/analytics/analytics_config.dart`: `POSTHOG_API_KEY` / `POSTHOG_HOST` via `const String.fromEnvironment`, `kDebugMode` isolation (debug without explicit token ⇒ no token), `host` default empty ⇒ disabled — exactly per research D2/D10 and the `distribution_channel.dart` precedent
- [x] T005 [P] Create `lib/core/analytics/analytics_platform_gate.dart`: `bool analyticsSupported()` = `Platform.isAndroid || Platform.isIOS || Platform.isMacOS` (vendor-supported list; Windows/Linux/web excluded — research D3)
- [x] T006 Create `lib/core/analytics/analytics.dart`: `abstract interface class Analytics` (capture / identify / reset / setEnabled / flag with required fallback / flush) + `final class NoopAnalytics` — signatures exactly per `specs/046-posthog-analytics-integration/contracts/analytics-facade.md`
- [x] T007 Create `lib/core/analytics/posthog_analytics.dart`: guarded `Posthog()` wrapper — every method swallows vendor errors into `logNamed('analytics')`, returns synchronously (except flush), applies `beforeSend` drop-guard and never throws; identity uses `UserProfile.id`, flags return `fallback` on any failure
- [x] T008 Create `lib/core/analytics/analytics_provider.dart`: `@Riverpod(keepAlive: true) Analytics analytics(Ref)` with the contract gate order: platform gate → token gate → kDebugMode gate → opted-out gate → `PosthogAnalytics`, else `NoopAnalytics`
- [x] T009 Create `lib/core/analytics/analytics_bootstrap.dart`: idempotent `@Riverpod(keepAlive: true)` init that builds `PostHogConfig` (manual `setup()`, `personProfiles: identifiedOnly`, `debug: kDebugMode`), registers super properties (`display_locale`, `learning_language`, `distribution_channel` — data-model E5), applies the stored opt-out (default ON), and runs against a short internal timeout — never on the first-frame path (research D8)
- [x] T010 Wire the fire-and-forget kick: read `analyticsInitProvider` once from `EnjoyApp` init in `lib/app.dart` (idempotent guard, unawaited) — `runApp`/first frame must not wait on it
- [x] T011 Run `dart run build_runner build` and commit the generated `lib/core/analytics/*.g.dart`; `flutter analyze` must pass
- [x] T012 Create unit tests in `test/core/analytics/`: config isolation (no token / debug ⇒ inert config), platform gate predicate, provider gate order (each gate ⇒ `NoopAnalytics`), `NoopAnalytics.flag` returns fallback, `PosthogAnalytics` swallows vendor exceptions (mock method channel via `TestDefaultBinaryMessengerBinding.setMockMethodCallHandler`)

**Checkpoint**: Facade compiles, gates proven by tests; tokenless `flutter test`/`flutter run` fully inert. User story implementation can begin.

---

## Phase 3: User Story 1 — App usage measured from first launch (Priority: P1) 🎯 MVP

**Goal**: On Android/iOS/macOS with a configured token, app-open/lifecycle sessions appear in the test PostHog project from the first launch; everywhere else the app is byte-for-byte unchanged.

**Independent Test**: Install the defines-enabled build on a supported platform, open the app → `Application Opened` in PostHog Activity within ~2 min (quickstart Scenario 1).

### Implementation for User Story 1

- [x] T013 [US1] Test: `PosthogAnalytics` setup contract in `test/core/analytics/posthog_analytics_test.dart` — mocked method channel receives `setup` with expected `host`/`debug`/`captureApplicationLifecycleEvents`; lifecycle autocapture config flows from `analytics_bootstrap.dart`
- [ ] T014 [US1] On-device verification (quickstart Scenario 1): `flutter run` an Android emulator with test `--dart-define`s → verify `Application Opened`, `Application Backgrounded`, `Application Updated` arrive and attribute to one session stream; capture evidence for the PR
- [ ] T015 [US1] Inert verification: tokenless `flutter run` and `flutter run -d linux` produce zero PostHog traffic, zero analytics errors/log noise, unchanged behavior (quickstart Scenarios 1.3 + 5)
- [ ] T016 [US1] Performance evidence (constitution IV): cold-start the defines build vs tokenless build — first meaningful frame indistinguishable; confirm in code review that no `await` of analytics sits on the startup path

**Checkpoint**: MVP — real usage numbers exist; all other platforms provably unaffected.

---

## Phase 4: User Story 2 — Usage attributed to the signed-in account (Priority: P2)

**Goal**: Events attribute to `UserProfile.id` after sign-in, survive reinstall, and never leak across account switches.

**Independent Test**: Sign in as account A on a new device → events land on person A; sign out → sign in as B → attribution switches (quickstart Scenario 2).

### Implementation for User Story 2

- [x] T017 [US2] Add the auth-sync listener in `lib/core/analytics/analytics_bootstrap.dart`: watch `authCtrlProvider` → on `AuthSignedIn(profile)` call `identify(profile.id, userProperties: {email, name, learningLanguage, subscriptionTier})` (skip when id unchanged); on `AuthSignedOut` call `reset()` (data-model E2; no auth-feature code changes)
- [x] T018 [US2] Create `test/core/analytics/analytics_auth_sync_test.dart` using a fake `AuthCtrl` override (pattern from `test/core/application/app_preferences_provider_test.dart`): sign-in ⇒ identify with the **id** (assert email is not the distinct id), re-emit same profile ⇒ no second identify, sign-out ⇒ `reset()`
- [ ] T019 [US2] On-device verification (quickstart Scenario 2): A → events on person A (email as property only); sign-out/sign-in as B → clean switch; reinstall + A ⇒ same person continues

**Checkpoint**: US1 + US2 both independently demonstrable.

---

## Phase 5: User Story 3 — Core product journeys measurable (Priority: P2)

**Goal**: The documented catalog fires exactly once per occurrence, and `$screen` autocapture works for every named route.

**Independent Test**: Walk each journey once (quickstart Scenario 3) → exactly one well-named event with allowlisted properties per occurrence.

### Implementation for User Story 3

- [x] T020 [US3] Create `lib/core/analytics/analytics_events.dart`: typed constants for all catalog events + property keys + `FailureReason` enum (`network|credits|auth|server|cancelled`) + per-event property builders — 1:1 with `specs/046-posthog-analytics-integration/contracts/event-catalog.md`
- [x] T021 [US3] Create `test/core/analytics/analytics_events_test.dart`: every name/property key in code appears in the catalog contract; `beforeSend` drop-guard drops events carrying non-allowlisted/UGC-shaped properties (extends `posthog_analytics_test.dart`)
- [x] T022 [US3] Screen autocapture (research D6): add `name:` to `GoRoute` entries in `lib/core/routing/app_router.dart` (sign-in, home, discover, library, player, craft, settings, profile, vocabulary, credits, subscription, …) and add `PosthogObserver()` to the root `observers:` and ShellRoute `observers:` lists
- [x] T023 [P] [US3] Instrument practice: capture `practice_session_started`/`practice_session_completed` (`surface`, `duration_seconds`, `items_completed`) at session start/end in `lib/features/shadow_reading/application/` and the flashcard/word-practice session controllers in `lib/features/vocabulary/application/`
- [x] T024 [P] [US3] Instrument transcripts: `transcript_generation_requested/completed/failed` (`source`, `duration_seconds`, `reason` enum only) at job submit/complete/fail in `lib/features/transcript/application/`
- [x] T025 [P] [US3] Instrument lookup + translation: `dictionary_lookup_performed` (`source`, `cache_hit`) in `lib/features/lookup/application/` and `translation_requested` (`kind`, `cache_hit`) at the translation request site
- [x] T026 [P] [US3] Instrument craft: `craft_project_created` (`mode`) and `craft_practice_completed` (`mode`, `duration_seconds`) in `lib/features/craft/application/`
- [x] T027 [P] [US3] Instrument vocabulary review: `vocabulary_review_completed` (`reviewed_count`, `correct_count`) at the due-review session end in `lib/features/vocabulary/application/`
- [x] T028 [P] [US3] Instrument purchases: `subscription_purchase_started/completed` (`tier`) in `lib/features/subscription/` and `credits_package_purchased` (`package_id`) in `lib/features/credits/`
- [x] T029 [US3] Create failure-mapping unit test `test/core/analytics/failure_reason_test.dart`: `AppFailure` variants (network, 402/credits, auth, server, cancelled) map to the closed `FailureReason` enum — and nothing else can leak into `reason`
- [ ] T030 [US3] On-device verification (quickstart Scenario 3): walk all six journeys once; assert exactly one event each, common-context properties present, no payload-like property values anywhere

**Checkpoint**: Catalog live end-to-end; funnels buildable in the dashboard with no further app changes.

---

## Phase 6: User Story 4 — Users can turn analytics off (Priority: P2)

**Goal**: A localized Settings switch stops all capture immediately (including queued events), persists, and resumes in-session.

**Independent Test**: Toggle off → zero events across sessions; restart keeps it off; toggle on resumes immediately (quickstart Scenario 4).

### Implementation for User Story 4

- [x] T031 [US4] Add `SettingsKeys.analyticsCaptureEnabled = 'analytics.capture_enabled'` (+ `_staticKeys` registration) in `lib/data/db/settings_keys.dart`, and create `lib/core/analytics/analytics_capture_pref.dart`: `@Riverpod(keepAlive: true)` boolean notifier over `deviceGlobalAppDatabaseProvider`, default `true`, `'true'/'false'` storage — recipe from `lib/core/diagnostics/diagnostics_verbose_provider.dart` (device-global on purpose: covers anonymous events, survives sign-out)
- [x] T032 [US4] Apply the preference: opted-out ⇒ provider gate resolves `NoopAnalytics` (extend `analytics_provider.dart`), and `analytics_bootstrap.dart` calls `Posthog().disable()` at init when stored off; toggling calls `disable()`/`enable()` immediately (persist to Drift first)
- [x] T033 [P] [US4] Add localized strings to `lib/l10n/app_en.arb`, `app_zh.arb`, `app_zh_CN.arb` (`settingsAnalyticsCaptureTitle`, `settingsAnalyticsCaptureSubtitle`, lowerCamelCase convention); run codegen
- [x] T034 [US4] Add the "Usage analytics" switch row to `lib/features/settings/presentation/widgets/about_section_card.dart` next to the verbose-diagnostics row — `SettingsRow` + `Switch.adaptive` exactly mirroring that row (data: `ref.watch(pref).when`, mutate via notifier, Haptics via `SettingsRow`)
- [x] T035 [P] [US4] Register the row for Settings search: descriptor in `kSettingsRegistry` (`lib/features/settings/domain/settings_search_entry.dart`) + localize case in `lib/features/settings/application/settings_registry_localizer.dart`
- [x] T036 [US4] Create tests: pref persistence (in-memory `NativeDatabase.memory()` + `ProviderContainer` override, pattern from `test/features/settings/application/karaoke_highlight_settings_test.dart`), provider gate ⇒ `NoopAnalytics` when opted out, toggle flips vendor `disable()`/`enable()` via mocked channel, widget test for the row's on/off states
- [ ] T037 [US4] On-device verification (quickstart Scenario 4) — **and settle research D4's open item**: confirm no queued backlog arrives after opt-out (if it does, apply the documented fallback: kill `captureApplicationLifecycleEvents` + gate all capture behind the pref, and note the vendor gap in the ADR); check en + zh labels and in-session resume

**Checkpoint**: Opt-out honored end-to-end; D4 question closed with evidence.

---

## Phase 7: User Story 5 — Releases can be gated by remote flags (Priority: P3)

**Goal**: Flag evaluation works at startup and on demand with mandatory safe fallbacks; nothing existing is gated.

**Independent Test**: Flip `test_flag` remotely → app readout changes after reload without an app update; offline/Linux → instant fallback (quickstart Scenario 6).

### Implementation for User Story 5

- [x] T038 [US5] Add `onFeatureFlags` handling to `lib/core/analytics/analytics_bootstrap.dart`: after flags load, `logNamed('analytics')` the loaded values (debug builds) and expose a reload trigger; `PosthogAnalytics.flag` reads `isFeatureEnabled`/`getFeatureFlag` with the required `fallback` and its own error/timeout fallback
- [x] T039 [US5] Create `test/core/analytics/analytics_flag_test.dart`: mocked channel returns flag value ⇒ `flag()` returns it; channel error / timeout / `NoopAnalytics` ⇒ `fallback` — verifying the contract that every call site must pass a fallback
- [ ] T040 [US5] Verification (quickstart Scenario 6): remote flip reflected after reload; airplane-mode startup reads fallback instantly with no hang; Linux build always returns fallback with no errors

**Checkpoint**: Capability complete, zero existing behavior gated.

---

## Phase 8: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, traceability, and final quality gates (constitution V + Flutter Quality Gates)

- [x] T041 [P] Write `docs/decisions/0086-posthog-product-analytics.md`: vendor choice + manual-init rationale (D1/D2), opt-out default ON rationale, Windows/Linux inert split, D4 finding from T037
- [x] T042 [P] Write `docs/features/analytics.md` (behavior, opt-out, event catalog reference to `contracts/event-catalog.md`, verification commands) and update `docs/features/settings.md` About-section row list with the analytics toggle
- [ ] T043 Run the full `specs/046-posthog-analytics-integration/quickstart.md` end-to-end, then the quality gates: `bash .github/scripts/validate_ci_gates.sh`, `flutter analyze`, `flutter test` — all green before push

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: no dependencies — start immediately
- **Foundational (Phase 2)**: depends on Phase 1 — **blocks all user stories**
- **US1 (Phase 3)**: first story; device-level proof of the foundation
- **US2 → US3 → US4 → US5 (Phases 4–7)**: each depends only on the foundational checkpoint (US2's identify also retroactively links US3-style anonymous events per the vendor docs, so order between US2/US3 is not a data-correctness dependency)
- **Polish (Phase 8)**: depends on all desired stories being complete

### User Story Dependencies

- **US1**: Foundational only. No other story needed.
- **US2**: Foundational only (listens to `authCtrlProvider`; touches nothing in US1's files beyond shared bootstrap).
- **US3**: Foundational + T020 (events file) before T021/T023–T028. Independent of US2/US4.
- **US4**: Foundational; T031 → T032/T034; T033 → T034; T036 after T031–T034. Independent of US2/US3/US5.
- **US5**: Foundational only (flag surface exists in T007/T008).

### Within Each Story

Tests precede or accompany the code they prove; constants/models before call sites; implementation before on-device verification.

### Parallel Opportunities

- Phase 1: T002, T003 in parallel (after T001's pub get)
- Phase 2: T005 parallel to T004/T006; T012's config/gate tests parallel to wrapper work
- US3: T023–T028 all `[P]` (different feature directories, only shared dependency is T020)
- US4: T033, T035 `[P]`; US4 entirely parallel with US3/US5 (disjoint files)
- Different stories can be implemented in parallel by different contributors once Phase 2's checkpoint passes

---

## Parallel Example: User Story 3

```bash
# After T020 (events constants) lands, launch together — disjoint feature dirs:
Task: T023 "Instrument practice in lib/features/shadow_reading/application/ + lib/features/vocabulary/application/"
Task: T024 "Instrument transcripts in lib/features/transcript/application/"
Task: T025 "Instrument lookup/translation in lib/features/lookup/application/ + translation site"
Task: T026 "Instrument craft in lib/features/craft/application/"
Task: T027 "Instrument vocabulary review in lib/features/vocabulary/application/"
Task: T028 "Instrument purchases in lib/features/subscription/ + lib/features/credits/"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Phase 1 (setup) + Phase 2 (foundation: facade, gates, config, init) — tested inert by default
2. Phase 3 (US1) — lifecycle sessions verifiably arrive; other platforms provably untouched
3. **STOP and VALIDATE** with quickstart Scenario 1 → shippable increment (real usage numbers, zero risk surface)

### Incremental Delivery

- +US2 → per-person retention and cross-device truth
- +US3 → feature adoption/funnels (the product-decision payload)
- +US4 → user-facing privacy control (can ship any time after MVP)
- +US5 → remote gating capability for the *next* feature

### Notes

- `[P]` = different files, no dependency on an incomplete task
- Story labels trace tasks to spec.md acceptance scenarios; constitution's quality/test/UX/docs/verification work is embedded per story (T012–T021, T033–T036, T041–T043), not deferred to cleanup
- Commit after each task or logical group; stop at any checkpoint to validate the story independently
- The single tracked unknown (D4 queued-events-on-disable) is deliberately closed inside US4 (T037), where the evidence is produced
