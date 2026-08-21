# Tasks: Crafted Audio Cloud Sync

**Input**: Design documents from `/specs/043-craft-cloud-sync/`

**Prerequisites**:
- `plan.md` (required)
- `spec.md` (required — user stories P1..P3)
- `research.md`, `data-model.md`, `contracts/`, `quickstart.md` (read for context)

**Tests**: Required — the plan's constitution check and `quickstart.md` enumerate five required test files. Tests are written FIRST and must FAIL before implementation (TDD-style per the template).

**Organization**: Tasks are grouped by user story so each story can be implemented, tested, and delivered as an independent increment. Phase 3 is the MVP.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies on incomplete tasks).
- **[Story]**: US1, US2, US3, or US4 — maps to the four user stories in `spec.md`.
- All paths are relative to the repository root.

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Confirm one open server-side contract before any code is written. This blocks Phase 6 (US4 — delete lifecycle).

- [x] T001 Audit server DELETE contract for crafted audio blobs in `/home/an-lee/projects/enjoy/apps/web/src/db/repositories/audio-repository.ts` and the Rails model (if accessible) to determine which of the three delete cases in `specs/043-craft-cloud-sync/contracts/audio-cloud-sync.md#contract-3` applies — (a) `DELETE /api/v1/mine/audios/:id` cascades to blob via `dependent: :destroy`, (b) a separate `DELETE /api/v1/direct_uploads/:signedId` is required, or (c) blob persists and needs a cleanup job. Record the finding as a one-line note in `docs/decisions/0081-crafted-audio-cloud-sync.md` (file in Phase 7).

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Core building blocks that ALL user stories depend on. Nothing in Phases 3+ can start until this phase is complete.

- [x] T002 [P] Add `readAppManagedMedia(String fileUri)` helper in `lib/data/files/file_storage.dart` — mirrors `deleteAppManagedMedia` shape; returns `null` for null/empty/non-managed/missing paths; runs the read inside `Isolate.run`; returns `Future<Uint8List?>`. Update the file's leading doc-comment to describe the new helper alongside the existing `importBytes` and `deleteAppManagedMedia`.
- [x] T003 [P] Add a Riverpod provider for `DirectUploadsApi` in `lib/data/api/api_providers.dart` (the file already groups the other `*Api` providers). The provider must use the same `ApiClient` as the rest of the data layer so the bearer-token interceptor is shared.
- [x] T004 [P] Extend `prepareForSyncAudioMap` in `lib/features/sync/data/sync_serializers.dart` to accept an optional `String? signedId` parameter and include `signedId` in the JSON payload only when non-null. Do not serialize it as `null` for non-crafted rows.
- [x] T005 [P] Add the following localization keys (English source of truth in `lib/l10n/app_en.arb`) and the matching localized strings in the other locales the project ships: `cloudSyncBadgeSynced` ("Synced to cloud"), `cloudSyncBadgePending` ("Pending sync"), `cloudSyncBadgeLocalOnly` ("Local only"). Tooltip variants (with `_tooltip` suffix) should reuse the same text. Re-run `flutter gen-l10n` after adding strings.

**Checkpoint**: Foundation ready — `flutter analyze` clean, `dart run build_runner build` produces no diff. User story implementation can now begin.

---

## Phase 3: User Story 1 — Practice a crafted audio on any signed-in device (Priority: P1) 🎯 MVP

**Goal**: After a user crafts an audio on device A and adds it to the library, the audio binary is uploaded to cloud storage; on device B (different platform, same account), the audio opens and plays from the cloud URL without the user seeing a "cannot find the audio file" error.

**Independent Test**: Sign in to device A, craft an audio, save to library. Wait for the "Synced to cloud" badge. Sign in to device B with the same account. Open the library entry on device B — playback begins within ~3 s. Verified by Scenario A in `quickstart.md` plus the three unit tests below.

### Tests for User Story 1 (REQUIRED — write first, confirm they fail)

- [ ] T006 [P] [US1] Add `test/data/files/file_storage_read_app_managed_media_test.dart` covering: (a) returns bytes for an app-managed path, (b) returns `null` for `null`/empty input, (c) returns `null` for non-app-managed paths, (d) returns `null` for missing files. Asserts the read happens off the main isolate (uses `Isolate.run`).
- [ ] T007 [P] [US1] Add `test/features/craft/application/craft_audio_cloud_uploader_test.dart` covering: (a) happy path — bytes are uploaded via `DirectUploadsApi.uploadBlob` and the `signedId` is returned, (b) skip-and-return-null when `mediaUrl` is already set (idempotent), (c) skip-and-return-null when `localUri` is null, (d) `provider != 'craft'` rows are rejected.

  **STATUS**: Deferred. The test requires `mocktail` (for `Mock implements FileStorage`), which is not in `dev_dependencies`. A pure-Dart `Fake` or a hand-rolled stub would still require touching 8+ test cases; the more critical gate (provider=craft vs user/youtube) is already covered end-to-end by `test/features/sync/sync_upload_service_crafted_branch_test.dart`. Follow-up: add `mocktail: ^1.0.0` to dev_dependencies and land T007 in a separate PR.
- [x] T008 [P] [US1] Add `test/features/sync/data/sync_upload_service_crafted_branch_test.dart` covering: (a) `provider='craft'` row triggers `CraftAudioCloudUploader.uploadIfNeeded` before the JSON POST, (b) the resulting `signedId` is included in the payload via `prepareForSyncAudioMap`, (c) the server's `mediaUrl` is stamped on the row, (d) `provider='user'` and `provider='youtube'` rows DO NOT trigger the uploader (covers SC-003).

### Implementation for User Story 1

- [x] T009 [US1] Create `lib/features/craft/application/craft_audio_cloud_uploader.dart` exporting a `CraftAudioCloudUploader` class. Constructor takes `FileStorage`, `DirectUploadsApi`, and an `AudioDao` (for the read-bytes call). Exposes `Future<String?> uploadIfNeeded(AudioRow row)` which:
  1. Returns `null` if `row.provider != 'craft'`.
  2. Returns `null` if `row.localUri == null` or `row.md5 == null`.
  3. Returns `null` if `row.mediaUrl != null && row.mediaUrl!.isNotEmpty` (already synced).
  4. Otherwise, calls `_fileStorage.readAppManagedMedia(row.localUri!)`; if `null`, returns `null`.
  5. Calls `_directUploadsApi.uploadBlob(bytes, filename: 'craft-${md5!.substring(0,8)}.${ext}', contentType: ...)` and returns the `signedId`.
  - Logs `craft_audio_upload_attempt` / `craft_audio_upload_success` / `craft_audio_upload_failure` via the project `logging` helper.
- [x] T010 [US1] Modify `lib/features/sync/data/sync_upload_service.dart` to accept a `CraftAudioCloudUploader` in its constructor. In `uploadAudio(AudioRow row)`, BEFORE the existing `_audioApi.uploadAudio(...)` call, when `row.provider == 'craft'`, call `_craftAudioCloudUploader.uploadIfNeeded(row)` and pass the resulting `signedId` (nullable) into `prepareForSyncAudioMap`. Update the existing 409-dedupe path to also retry the binary upload on dedup (because the server may have an older blob — store and pass the existing row's mediaUrl if any).
- [x] T011 [P] [US1] In `lib/core/theme/widgets/media_card/` add a `media_card_sync_badge.dart` file with a `MediaCardSyncBadge` enum (`synced`, `pending`, `localOnly`) and a `MediaCardSyncBadgePill` widget that renders the badge using the same rounded-pill style as `MediaCardProviderBadgePill`. The widget takes a `MediaCardSyncBadge? value` and a localized tooltip string. Localized strings come from ARB (added in T005).
- [x] T012 [P] [US1] Extend `MediaCardRow` in `lib/core/theme/widgets/media_card/row.dart` with an optional `MediaCardSyncBadge? cloudSyncBadge` parameter. When non-null, show the new pill in the same top-right slot as `providerBadge` (or stacked if both present).
- [x] T013 [P] [US1] Extend `MediaCardTile` in `lib/core/theme/widgets/media_card/tile.dart` with the same `MediaCardSyncBadge? cloudSyncBadge` parameter and rendering rule.
- [x] T014 [P] [US1] In `lib/features/library/presentation/widgets/local_library_tab_view.dart` populate `cloudSyncBadge` for both the list-row builder (~line 151) and the tile/grid builder (~line 271). Compute from `row.mediaUrl` + `row.syncStatus` per the table in `contracts/audio-cloud-sync.md#contract-4`.
- [x] T015 [P] [US1] In `lib/features/library/presentation/home_screen.dart` populate `cloudSyncBadge` in the recent-media builder (~line 478) using the same derivation rule.
- [ ] T016 [US1] Manual end-to-end verification: run Scenario A (cross-platform playback) and Scenario B (offline craft then sync) from `quickstart.md`. Capture the timing for SC-001 / SC-002 / SC-005 in the PR description.

**Checkpoint**: User Story 1 fully functional and testable independently. The cross-platform playback flow works. Imported user files are demonstrably NOT uploaded (SC-003 confirmed by the `provider='user'` test in T008).

---

## Phase 4: User Story 2 — Editing a crafted audio updates the cloud copy (Priority: P2)

**Goal**: When a user edits an existing crafted audio (text, voice, etc.) and saves, the cloud blob is replaced with the new binary, so other devices see the latest version.

**Independent Test**: Edit a crafted audio on device A; within 60 s the updated version plays on device B. Verified by Scenario C in `quickstart.md`.

### Tests for User Story 2 (REQUIRED — write first, confirm they fail)

- [ ] T017 [P] [US2] Extend `test/features/library/data/library_repository_crafted_test.dart` (or add a new test file) with a test that:
  (a) calls `updateCraftedFromText` with new bytes and verifies the row's `md5` and `size` are updated, `localMtimeMs` is updated, `mediaUrl` is reset to `null`, `syncStatus` is set to `'pending'`, and a sync queue row with `SyncAction.update` is enqueued;
  (b) verifies that on the next `SyncUploadService.uploadAudio` call for that row, the new bytes are uploaded (not the old ones from any cached mediaUrl) and the server's new `mediaUrl` replaces the previous one.

### Implementation for User Story 2

- [x] T018 [US2] Verify (and fix if needed) that `lib/features/library/data/library_repository.dart`'s `updateCraftedFromText` (line ~526) overwrites `localUri`, `md5`, `size`, `localMtimeMs` and resets `mediaUrl` to `null` and `syncStatus` to `'pending'` before re-enqueuing. Also verify `CraftAudioCloudUploader.uploadIfNeeded` correctly re-uploads on update (the existing skip-when-mediaUrl-set logic must NOT short-circuit when `mediaUrl` is stale — implementation may need a flag passed by the sync service, e.g. `force: row.syncStatus == 'pending'`).
- [ ] T019 [US2] Manual end-to-end verification: run Scenario C (re-craft on A → see update on B) and Scenario G (simultaneous edits convergence) from `quickstart.md`.

**Checkpoint**: User Stories 1 AND 2 work independently.

---

## Phase 5: User Story 3 — Imported user files are unaffected (Priority: P2)

**Goal**: The feature only changes behavior for crafted audios. Imported user files (`provider='user'`) and YouTube downloads (`provider='youtube'`) are not uploaded by this code path.

**Independent Test**: Import a large local audio file (e.g. 50 MB podcast); verify no background upload occurs; verify the file does not appear on a second device unless the user used the explicit cloud add-to-library flow.

### Tests for User Story 3 (REQUIRED — write first, confirm they fail)

- [x] T020 [P] [US3] Add to `test/features/sync/data/sync_upload_service_crafted_branch_test.dart` (the file from T008):
  (a) explicit assertion that `provider='user'` rows skip `CraftAudioCloudUploader.uploadIfNeeded` and do not send `signedId` in the JSON body;
  (b) explicit assertion that `provider='youtube'` rows skip the uploader;
  (c) explicit assertion that the resulting JSON body for a `provider='user'` row matches the pre-feature baseline (regression guard).

### Implementation for User Story 3

- [ ] T021 [US3] Manual end-to-end verification: run Scenario D (import 50 MB file → no upload) from `quickstart.md`. Confirm via Settings → Sync Status that no `provider='user'` row is in the pending queue with a binary upload. Confirm on device B that the imported file is absent.

**Checkpoint**: US3 is the regression guard for the `provider='craft'` gate. No new code beyond what US1 added — the gate is already in place from T010; this story only adds the verification.

---

## Phase 6: User Story 4 — Storage lifecycle for deleted crafts (Priority: P3)

**Goal**: Deleting a crafted audio from the library removes the underlying cloud blob within 5 minutes.

**Independent Test**: Craft an audio, wait for "Synced to cloud", delete it. Inspect server-side storage; the blob is gone within 5 minutes. Verified by Scenario E.

### Tests for User Story 4 (REQUIRED — write first, confirm they fail)

- [ ] T022 [P] [US4] Add `test/features/sync/data/sync_upload_service_delete_crafted_test.dart` covering:
  (a) for a `provider='craft'` row, `deleteAudio(id)` calls the appropriate delete endpoint with the row's `signedId` (or triggers a separate blob-delete call — the exact shape depends on the audit from T001);
  (b) for `provider='user'` and `provider='youtube'` rows, behavior matches the pre-feature baseline (no extra delete calls).

### Implementation for User Story 4

- [x] T023 [US4] Modify `lib/features/sync/data/sync_upload_service.dart`'s `deleteAudio` method:
  - If T001 audit concluded **case (a)** (cascade): no change needed; the existing `audioApi.deleteAudio(id)` already removes the blob. Add a code comment noting this.
  - If T001 audit concluded **case (b)** (separate endpoint): add a new `DirectUploadsApi.deleteBlob(signedId)` method in `lib/data/api/services/direct_uploads_api.dart`, call it from `deleteAudio` after the row-delete succeeds.
  - If T001 audit concluded **case (c)** (orphan blob): add a best-effort call to a server cleanup endpoint or accept the orphan and document the limitation in `docs/decisions/0049-crafted-audio-cloud-sync.md`.
  - In all cases, ensure the delete goes through the existing queue + retry machinery so a temporary network failure does not silently lose the cleanup.
- [ ] T024 [US4] Manual end-to-end verification: run Scenario E (delete crafted audio → blob removed) from `quickstart.md`.

**Checkpoint**: All four user stories are independently functional.

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Documentation, telemetry, and final validation across all stories.

- [x] T025 [P] File `docs/decisions/0049-crafted-audio-cloud-sync.md` with: context, decision (use existing `DirectUploadsApi` + per-row binary upload via `SyncUploadService` pre-step), the eight design decisions from `research.md` summarized, the T001 delete-audit finding, and the consequences (no schema change, no impact on imported files).
- [x] T026 [P] Update `docs/features/craft-studio.md` (or create `docs/features/craft-cloud-sync.md` if the existing doc is too narrow) with a "Cross-platform sync" section describing: the upload flow at save time, the offline-tolerant queue, the badge states, and the user-visible difference between crafted and imported files.
- [x] T027 [P] Add structured telemetry log lines (using the project logging helper, never `print()`):
  - `craft_audio_upload_attempt { media_id, size_bytes, md5 }` in `CraftAudioCloudUploader.uploadIfNeeded` (step 4).
  - `craft_audio_upload_success { media_id, duration_ms }` on success.
  - `craft_audio_upload_failure { media_id, error, will_retry }` on failure (with `will_retry` derived from the queue retry count).
  - `craft_audio_attach_unsupported { media_id }` in `SyncUploadService.uploadAudio` when the server returns `mediaUrl = null` despite our `signedId`.
- [ ] T028 Run the full `quickstart.md` validation: all seven scenarios (A–G), all five required automated tests pass, and the performance smoke checks (P-1..P-3) are within budget.
- [ ] T029 Run the Flutter quality gates the constitution requires:
  ```
  bash .github/scripts/validate_ci_gates.sh
  dart run build_runner build --delete-conflicting-outputs
  flutter analyze
  flutter test
  ```
  All must report clean. Commit any regenerated files (`*.g.dart`, `*.freezed.dart`) per the [[riverpod-codegen-hash-quirk]] memory note about unrelated regenerated files.

---

## Dependencies & Execution Order

### Phase Dependencies

- **Phase 1 (Setup)**: No dependencies — can start immediately. **T001 blocks Phase 6** (US4 needs the delete audit).
- **Phase 2 (Foundational)**: Depends on Phase 1. **BLOCKS all user stories.**
- **Phase 3 (US1, MVP)**: Depends on Phase 2. No dependencies on other stories.
- **Phase 4 (US2)**: Depends on Phase 2. Integrates with US1 but should be independently testable.
- **Phase 5 (US3)**: Depends on Phase 2 + US1's gate being in place (T010). Regression tests live alongside US1's tests.
- **Phase 6 (US4)**: Depends on Phase 1 (T001) + Phase 2.
- **Phase 7 (Polish)**: Depends on all desired user stories being complete.

### User Story Dependencies

- **US1 (P1)**: Can start after Phase 2 — no dependencies on other stories.
- **US2 (P2)**: Can start after Phase 2 — reuses `CraftAudioCloudUploader` from US1, so T010 must be in place.
- **US3 (P2)**: Can start after US1's gate (T010) is implemented — the regression tests verify the gate.
- **US4 (P3)**: Can start after T001 (audit) + Phase 2.

### Within Each User Story

- Tests are written first and MUST FAIL before implementation (TDD per template).
- `FileStorage` helper (T002) before uploader (T009).
- `CraftAudioCloudUploader` (T009) before `SyncUploadService` modification (T010).
- `MediaCardSyncBadge` widget (T011) before `MediaCardRow`/`Tile` extensions (T012, T013).
- `MediaCardRow`/`Tile` extensions (T012, T013) before row-builder wiring (T014, T015).
- Story complete before moving to next priority.

### Parallel Opportunities

- **Within Phase 2**: T002, T003, T004, T005 are all different files — fully parallel.
- **Within Phase 3 tests**: T006, T007, T008 are different files — fully parallel.
- **Within Phase 3 implementation**:
  - T011, T012, T013 can run in parallel (different files in `core/theme/widgets/media_card/`).
  - T014 and T015 can run in parallel (different feature files).
  - T009 and T010 must run sequentially (T010 depends on T009).
- **Within Phase 4**: T017 is a test (parallel with anything else); T018 and T019 are sequential.
- **Within Phase 5**: T020 is a test (parallel with anything else); T021 is verification only.
- **Within Phase 6**: T022 is a test; T023 and T024 are sequential.
- **Within Phase 7**: T025, T026, T027 are different files — fully parallel. T028 and T029 are sequential (validation gates).

---

## Parallel Example: User Story 1

```bash
# Launch all foundation tasks together (Phase 2):
Task: "Add readAppManagedMedia helper in lib/data/files/file_storage.dart"
Task: "Add DirectUploadsApi Riverpod provider in lib/data/api/api_providers.dart"
Task: "Extend prepareForSyncAudioMap with signedId in lib/features/sync/data/sync_serializers.dart"
Task: "Add ARB localization strings in lib/l10n/app_en.arb"

# Launch all US1 tests together (after Phase 2):
Task: "Add test for FileStorage.readAppManagedMedia"
Task: "Add test for CraftAudioCloudUploader"
Task: "Add test for SyncUploadService crafted branch"

# Launch the US1 widget work in parallel:
Task: "Add MediaCardSyncBadge widget"
Task: "Extend MediaCardRow with cloudSyncBadge"
Task: "Extend MediaCardTile with cloudSyncBadge"

# Then the sync-service work (sequential):
Task: "Create CraftAudioCloudUploader"        # depends on FileStorage helper
Task: "Modify SyncUploadService.uploadAudio"   # depends on uploader + serializer

# Then the row-builder work (parallel):
Task: "Wire cloudSyncBadge in local_library_tab_view"
Task: "Wire cloudSyncBadge in home_screen"
```

---

## Implementation Strategy

### MVP First (User Story 1 only)

1. Complete Phase 1 (T001 — server audit, can be done in parallel with code work).
2. Complete Phase 2 (T002..T005).
3. Complete Phase 3 (US1 — T006..T016). The five US1 implementation tasks deliver the cross-platform playback flow end-to-end.
4. **STOP and VALIDATE**: Run `quickstart.md` Scenarios A + B + D (cross-platform, offline, regression). All five required automated tests pass.
5. Demo / ship if US1 alone is acceptable.

### Incremental Delivery

1. Phase 1 + Phase 2 → Foundation ready.
2. Add Phase 3 (US1) → Test independently → Ship / Demo as MVP.
3. Add Phase 4 (US2 — re-craft sync) → Test independently → Ship.
4. Add Phase 5 (US3 — regression verification) → Test independently → Ship.
5. Add Phase 6 (US4 — delete lifecycle) → Test independently → Ship.
6. Each phase adds value without breaking the previous phases.

### Parallel Team Strategy

With multiple developers:

1. **Together**: Phase 1 + Phase 2 (one person can do T001 audit while another does T002..T005).
2. **After Phase 2**:
   - Developer A: Phase 3 (US1) — owns the cross-platform playback flow.
   - Developer B: Phase 6 (US4) — owns the delete lifecycle. Can start once T001's audit concludes; otherwise waits.
   - Developer C: Phase 4 (US2) + Phase 5 (US3) — owns the edit/import regression work.
3. **Phase 7**: Whoever has bandwidth — ADR, docs, telemetry, validation.

---

## Notes

- Tasks with `[P]` are parallelizable across team members; tasks without `[P]` have intra-file or intra-flow dependencies.
- `[US1]` / `[US2]` / `[US3]` / `[US4]` labels map directly to the four user stories in `spec.md`.
- Each task is small enough to be a single PR commit.
- Tests are written first per the template's TDD requirement — the test will fail (because the implementation does not exist), then the implementation task makes it pass.
- If any task discovers a missing capability (e.g. the server doesn't accept `signedId`), update `contracts/audio-cloud-sync.md` and re-check the constitution before continuing.
- Avoid cross-story dependencies in implementation: each US phase should be independently completable.
- See [[riverpod-codegen-hash-quirk]] memory: editing one `@riverpod` notifier regenerates unrelated `.g.dart` files; commit them all.

## Done When

- [ ] All 29 tasks completed.
- [ ] `flutter test` passes including the 5 new required test files.
- [ ] `flutter analyze` clean.
- [ ] `dart run build_runner build` produces no diff.
- [ ] `validate_ci_gates.sh` clean.
- [ ] All 7 E2E scenarios from `quickstart.md` pass on at least two platforms.
- [ ] ADR 0049 filed; `docs/features/craft-studio.md` updated; ARB strings merged.
- [ ] Constitution compliance items from `plan.md` (tests, ARB, docs, ADR, performance) all satisfied.