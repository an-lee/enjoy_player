# Quickstart Validation Guide: Crafted Audio Cloud Sync

**Date**: 2026-08-21
**Feature**: [spec.md](./spec.md) | [plan.md](./plan.md) | [research.md](./research.md)

This guide describes how to validate the feature end-to-end. It is intended for the implementation phase and for manual QA / integration testing — not as a substitute for the unit/widget/integration tests that the implementation phase adds (see "Required automated tests" below).

## Prerequisites

- A development build of `enjoy_player` installed on two devices with different platforms (e.g. Android + Windows, macOS + Linux, iOS + Android). They must sign in with the **same** user account.
- A test server (`https://enjoy.bot` staging or a local Rails backend) reachable from both devices, with Active Storage configured.
- The user account must have permission to upload blobs (`/api/v1/direct_uploads`).
- `flutter` CLI on PATH for the automated checks.

## Setup

```bash
# 1. From the repo root, ensure deps are up to date and codegen has run.
flutter pub get
dart run build_runner build --delete-conflicting-outputs

# 2. Run the Flutter quality gates the constitution requires.
bash .github/scripts/validate_ci_gates.sh

# 3. Build a debug app on device A and device B.
flutter run -d <deviceA>      # in one terminal
flutter run -d <deviceB>      # in another terminal
```

## Required automated tests

The implementation phase adds the following tests. Each maps to one or more requirements in the spec:

| Test file | What it proves | Maps to |
|---|---|---|
| `test/data/files/file_storage_read_app_managed_media_test.dart` | `FileStorage.readAppManagedMedia` reads app-managed bytes, returns `null` for non-managed paths, runs off-isolate | FR-001, P-3 |
| `test/features/craft/application/craft_audio_cloud_uploader_test.dart` | `CraftAudioCloudUploader.uploadIfNeeded` calls `DirectUploadsApi.uploadBlob`, returns `signedId` when bytes exist, returns `null` when `mediaUrl` is already set (idempotent) or when no `localUri` | FR-001, FR-008, FR-009 |
| `test/features/sync/data/sync_upload_service_crafted_branch_test.dart` | `SyncUploadService.uploadAudio` calls `CraftAudioCloudUploader` for `provider='craft'`, includes `signedId` in JSON body, populates `mediaUrl` from server response, **does NOT** call the uploader for `provider='user'`/`'youtube'` | FR-001, FR-005, FR-009, SC-003 |
| `test/features/library/data/library_repository_crafted_test.dart` | `importCraftedFromText` and `updateCraftedFromText` enqueue sync, `mediaUrl` is `null` initially, `syncStatus` is `'pending'` | FR-002, FR-003, FR-004 |
| `test/core/theme/widgets/media_card/row_cloud_sync_badge_test.dart` | The badge renders `synced` when `mediaUrl != null`, `pending` when `syncStatus='pending'`, `localOnly` otherwise | FR-011 |

Run them:

```bash
flutter test test/features/craft/application/craft_audio_cloud_uploader_test.dart
flutter test test/features/sync/data/sync_upload_service_crafted_branch_test.dart
flutter test test/features/library/data/library_repository_crafted_test.dart
flutter test test/data/files/file_storage_read_app_managed_media_test.dart
flutter test test/core/theme/widgets/media_card/row_cloud_sync_badge_test.dart
```

The full suite (regression):

```bash
flutter analyze
flutter test
```

## End-to-end manual validation scenarios

These scenarios prove the user-facing success criteria. They are run after the automated tests pass.

### Scenario A — Cross-platform playback (SC-001, US-1)

1. Sign in to device A (Android). Open Craft studio.
2. Type a phrase, choose a voice, synthesize, add to library.
3. Open the library. Verify the new audio plays locally on device A.
4. Verify the sync badge shows "Synced to cloud" (cloud-check icon) within 30 s on a normal network. If it shows "Pending sync", wait and pull-to-refresh.
5. Sign in to device B (Windows or macOS) with the **same** account.
6. Open the library on device B. The crafted audio MUST appear within the sync window.
7. Tap the audio on device B. **Expected**: playback starts within ~3 s on a normal network. **No** "cannot find the audio file" error.

If step 7 fails, check:
- `adb logcat | grep craft_audio` (Android) or Console.app (macOS) for `craft_audio_upload_failure` log lines.
- Server logs for the `POST /api/v1/direct_uploads` and `POST /api/v1/mine/audios` calls — confirm `mediaUrl` is in the response.

### Scenario B — Offline craft then sync (US-1 acceptance 3, SC-005)

1. Sign in to device A. Turn on airplane mode.
2. Open Craft studio. Type, synthesize, add to library. Confirm it plays locally.
3. Verify the badge shows "Pending sync" (cloud-upload icon, muted color).
4. Turn off airplane mode.
5. Wait up to 5 minutes (or pull-to-refresh in the library).
6. **Expected**: badge transitions to "Synced to cloud".

### Scenario C — Re-craft updates the cloud copy (US-2, SC-004)

1. Sign in to device A. Craft "Version 1" of a phrase. Save to library.
2. Wait for "Synced to cloud" badge.
3. Open Craft studio → edit the same entry. Change the voice. Save.
4. Wait for "Synced to cloud" badge again.
5. On device B (different platform), open the same library entry.
6. **Expected**: device B plays "Version 2" (the updated audio). Listen for the new voice.

### Scenario D — Imported files are NOT uploaded (US-3, SC-003)

1. Sign in to device A. Import a large local audio file (e.g. 50 MB podcast) via the file picker.
2. Verify the badge shows "Local only" (cloud-off icon), **not** "Synced to cloud".
3. Open Settings → Sync Status. Verify there is no pending upload of a `provider='user'` row.
4. Sign in to device B. **Expected**: the imported file does **not** appear in device B's library (unless the user explicitly used cloud add-to-library, which is a separate flow).

### Scenario E — Delete cleans up the cloud copy (US-4, SC-006)

1. Sign in to device A. Craft and save an audio. Wait for "Synced to cloud".
2. Delete the entry from the library.
3. Confirm via server-side inspection (e.g. `rails runner 'puts ActiveStorage::Attachment.count'` or the equivalent admin UI) that the underlying blob is removed within 5 minutes.
4. **Expected**: blob is gone. If the contract-3 server behavior is "best-effort orphan cleanup" (case (c) in the contracts), the blob may briefly persist until a cleanup job runs — accept that as a known limitation documented in `docs/decisions/0081-crafted-audio-cloud-sync.md`.

### Scenario F — Deduplication (FR-008, SC-007)

1. Sign in to device A. Craft a phrase with text "Hello", voice "alloy", language "en". Save.
2. Wait for "Synced to cloud".
3. Sign in to device B with the same account. Use Craft studio. Type **exactly** the same text, same voice, same language.
4. Save.
5. **Expected**: only one server-side blob is created (the dedup happens because `importCraftedFromText` matches on `md5` before inserting a new row). Confirm via server-side storage listing or the admin UI.

### Scenario G — Simultaneous edits (Edge case)

1. Sign in to device A and device B with the same account.
2. On both devices, open the same crafted audio for editing.
3. On device A, change the voice and save.
4. On device B, change the text (keep the original voice) and save, ~30 s later.
6. **Expected**: device B's version wins (later `serverUpdatedAt`). Both devices converge to device B's content on the next sync. Verify by reopening the library on both devices.

## Performance smoke checks

These map to the performance goals in `plan.md`.

- **P-1**: In Scenario A, time from "Add to library" to "Synced to cloud" badge. **Expected**: ≤ 30 s for a 5 MB craft on a normal network (matches SC-002).
- **P-2**: In Scenario A, time from "Add to library" to "audio plays locally". **Expected**: unchanged from the pre-feature baseline (no regression).
- **P-3**: Verify the byte read happens off the main isolate by inspecting the logs for `Isolate.run` log lines (or temporarily adding a log line). On Android, no `Choreographer` skipped-frame warnings during the upload.

## Regression checks

These confirm the feature does not break adjacent behavior.

- **Imports still work**: file picker import still produces a playable row with `provider='user'`, `mediaUrl=null`.
- **YouTube still works**: YouTube download still produces a playable row with `provider='youtube'`, `mediaUrl=non-null`.
- **Pre-feature crafted audios**: existing pre-feature crafted audios show "Pending sync" on first launch and re-sync on the next queue drain. Verify by signing in on a device that already has pre-feature crafted audios.
- **Non-craft cloud audios**: opening a `provider='user'` row that was previously added via cloud add-to-library still plays via `mediaUrl` (this is the existing resolver path — no change).
- **iOS / macOS / Linux**: build and smoke-test the crafted-audio flow on each of iOS, macOS, and Linux. The constitution requires first-class Linux support (ADR-0048).

## Telemetry verification

To verify SC-001 / SC-002 / SC-006 in production (post-release):

- Look for `craft_audio_upload_attempt`, `craft_audio_upload_success`, `craft_audio_upload_failure` log lines.
- Aggregate success rate by craft size bucket; verify ≥ 95% success for crafts ≤ 5 MB within 30 s.
- Aggregate deletion success; verify ≥ 95% of deletes have the blob removed within 5 minutes (server-side metric).

## Done when

- [ ] All required automated tests pass (`flutter test`).
- [ ] Scenarios A–G pass on at least two different platforms (e.g. Android + Windows).
- [ ] `flutter analyze` reports no new warnings.
- [ ] `dart run build_runner build` succeeds and generated files are committed.
- [ ] Constitution compliance items in `plan.md` are satisfied (tests, ARB strings, `docs/features/craft-studio.md` update, ADR 0049 filed).
- [ ] Telemetry log lines are present in the binary (grep the AOT artifact or check that the logger calls are wired up).