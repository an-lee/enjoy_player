# ADR-0081: Crafted Audio Cloud Sync

## Status

Accepted

## Context

Before this ADR, a user who crafted a TTS audio on one device (e.g. Android) could not open it on another device (e.g. Windows). The library row referenced a local sandbox path (`<appDocs>/media/<sha256>.<ext>`) that did not exist on the new device. `MediaSourceResolver` fell back to `mediaUrl`, but for crafted audios `mediaUrl` was always `null` because the sync layer only uploaded metadata — never the audio binary.

The web app at `~/projects/enjoy/apps/web` solved the same problem by uploading the audio binary via Rails Active Storage Direct Uploads (POST `/api/v1/direct_uploads` → PUT bytes to the signed URL → returns `signedId`) and sending the `signedId` in the JSON payload of `POST /api/v1/mine/audios` so the server could attach the blob and persist a `mediaUrl`. The Flutter player had the building blocks (`DirectUploadsApi.uploadBlob`) but did not wire them into the sync flow.

### T001 delete-audit finding

A pre-implementation audit of the web app's delete path confirmed that the Rails server handles `DELETE /api/v1/mine/audios/:id` with `dependent: :destroy` on the `has_one_attached :file` association — case (a) in `specs/043-craft-cloud-sync/contracts/audio-cloud-sync.md#contract-3`. The web app never sends a `signedId` on delete, never hits a separate `/api/v1/direct_uploads/:signedId` DELETE endpoint, and the Flutter player therefore matches the same behavior: the existing `SyncUploadService.deleteAudio` already calls `audioApi.deleteAudio(id)` and relies on the server cascade. No new client-side blob-deletion code is needed.

## Decision

### Where the binary upload lives

The binary upload step is injected into `SyncUploadService.uploadAudio()` as a pre-step, gated on `row.provider == 'craft'`. This:

- Reuses the existing queue + retry + offline-tolerance machinery for free.
- Works for both `SyncAction.create` (from `importCraftedFromText`) and `SyncAction.update` (from `updateCraftedFromText`).
- Keeps the offline-craft UX intact: `localUri` is set and the audio plays locally before the upload completes.

### Reuse existing infrastructure

- **HTTP**: existing `DirectUploadsApi.uploadBlob` wraps the Rails Active Storage direct-upload dance. No new HTTP code.
- **Auth**: bearer token via the shared `ApiClient`; PUT to the storage URL uses pre-signed headers (no bearer).
- **Read helper**: new `FileStorage.readAppManagedMedia(fileUri)` mirrors `deleteAppManagedMedia`. Reads off the main isolate via `Isolate.run`.
- **UI**: new `MediaCardSyncBadgePill` reuses the existing `MediaCardProviderBadgePill` slot on `MediaCardRow` / `MediaCardTile`.

### Server contract

The client sends an optional `signedId` field in the JSON payload of `POST /api/v1/mine/audios`. The Rails server attaches the blob (mirrors the web app's `attachMediaBlobToPayload`) and returns `mediaUrl` in the response. The client stamps `mediaUrl` on the row.

**Fallback**: if the server accepts `signedId` but returns `mediaUrl = null`, the client logs `craft_audio_attach_unsupported` and keeps the row valid locally. The next queue drain retries. This matches the offline-tolerance story.

### Scope is explicit

Only `provider = 'craft'` rows trigger the binary upload. `provider = 'user'` (imported files) and `provider = 'youtube'` (downloads) are explicitly excluded — verified by `sync_upload_service_crafted_branch_test.dart` (SC-003).

### Re-craft updates the cloud copy

`MediaLibraryRepository.updateCraftedFromText` now resets `mediaUrl` to `null` and `syncStatus` to `'pending'` on every edit. Combined with the uploader's idempotent skip-when-already-synced rule, this ensures the new bytes are uploaded on the next sync drain — without the previous-cloud-URL short-circuit bug.

### No schema change

The `audios` Drift table already had `localUri`, `mediaUrl`, `md5`, `syncStatus` — no schema migration. Pre-feature crafted audios with `mediaUrl = null` re-sync transparently on the next queue drain.

## Consequences

### Positive

- Cross-platform playback for crafted audios (the original user pain).
- Re-craft edits propagate to other devices (US2).
- Imported files remain local-only by design (US3).
- Existing offline queue + retry machinery handles crafted-audio uploads with no new infrastructure.
- No schema migration; pre-feature rows self-heal on next sync.

### Negative / accepted

- Larger overall code path on `SyncUploadService.uploadAudio` (the binary upload pre-step). Mitigated by logging + idempotent skip when `mediaUrl` is already populated.
- `Media` domain class gains a `syncStatus` field so the badge UI can render all three states. Touches one projection (`_mediaFromLibraryRow`).
- Widget tests for `CraftAudioCloudUploader` and `FileStorage.readAppManagedMedia` are not yet written (T006, T007). They require `Isolate.run` mocking or platform channel stubs which is non-trivial; the existing `sync_upload_service_crafted_branch_test.dart` covers the most important gate (SC-003) end-to-end.

### Reversibility

The change is reversible: removing the `craftAudioCloudUploader` parameter from `SyncUploadService` (and reverting `prepareForSyncAudioMap`'s `signedId` parameter) restores the pre-feature behavior. The `readAppManagedMedia` helper and the `cloudSyncBadge` UI are independently removable.

## Alternatives considered

- *Place the binary upload directly in `CraftController.saveToLibrary` (eager sync).* Rejected: would block the "save to library" action and fail entirely when offline.
- *Two-stage upload: blob first, then JSON sync as a separate queue item.* Rejected: doubles queue churn; the single combined step is sufficient.
- *Use `ApiClient.postMultipartJson` with the audio as a multipart field.* Rejected: doubles bandwidth for large audios (the server would re-receive the bytes it is about to PUT to storage anyway).
- *Build a new presigned-URL flow against R2/S3 directly.* Rejected: requires knowing the storage backend; the Rails server already exposes the abstraction.
- *Add a new `mediaBytesSynced: bool` column to the audios table.* Rejected: the state is fully derivable from `(mediaUrl != null, syncStatus)`; adding a denormalized column would invite drift.
- *Add a transient `'uploading'` value to `syncStatus`.* Rejected: would need to be persisted (otherwise disappears on app restart) for a fast operation (≤ 30 s). The existing `'pending'` value already covers "upload not yet completed".
- *For delete: a separate `DELETE /api/v1/direct_uploads/:signedId` endpoint.* Rejected (T001 audit): the web app's pattern is server cascade via `dependent: :destroy`; the existing `deleteAudio(id)` already works.

## References

- Spec: `specs/043-craft-cloud-sync/spec.md`
- Plan: `specs/043-craft-cloud-sync/plan.md`
- Research: `specs/043-craft-cloud-sync/research.md`
- Data model: `specs/043-craft-cloud-sync/data-model.md`
- Contracts: `specs/043-craft-cloud-sync/contracts/audio-cloud-sync.md`
- Quickstart: `specs/043-craft-cloud-sync/quickstart.md`
- Tasks: `specs/043-craft-cloud-sync/tasks.md`
- Web app reference: `~/projects/enjoy/apps/web/src/db/services/sync-upload-helpers.ts:72` (`attachMediaBlobToPayload`)
- Existing client: `lib/data/api/services/direct_uploads_api.dart`, `lib/features/sync/data/sync_upload_service.dart`, `lib/data/files/file_storage.dart`
- New code: `lib/features/craft/application/craft_audio_cloud_uploader.dart`, `lib/core/theme/widgets/media_card/media_card_sync_badge.dart`