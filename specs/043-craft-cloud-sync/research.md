# Research: Crafted Audio Cloud Sync

**Date**: 2026-08-21
**Feature**: [spec.md](./spec.md) | [plan.md](./plan.md)

This document captures the technology and integration decisions for syncing crafted audio binaries to cloud storage. It is the output of Phase 0 research; the resulting design decisions are reflected in the plan and in `data-model.md` / `contracts/` / `quickstart.md`.

## Decision 1 — Where the binary upload step lives in the request flow

**Decision**: Add the binary upload as a pre-step inside `SyncUploadService.uploadAudio()` (at `lib/features/sync/data/sync_upload_service.dart:65`), gated on `row.provider == 'craft'`. Before the existing JSON POST to `/api/v1/mine/audios`, call a new `CraftAudioCloudUploader.upload(row)` that uploads bytes via `DirectUploadsApi.uploadBlob` and returns a `signedId`. The `signedId` is then included in the JSON body the existing serializer sends.

**Rationale**:
- The existing `SyncUploadService.uploadAudio` already has the right shape for this: it picks up rows from `SyncEngine`, calls the server, stamps `mediaUrl` / `syncStatus` / `serverUpdatedAt` on the row, and integrates with the offline queue + retry/backoff machinery.
- Inserting the binary step inside the same method means crafted audios automatically inherit the offline queue, retry-with-backoff (`_kMaxRetries = 5`, exponential), and 409-dedupe behavior.
- Both `SyncAction.create` (from `importCraftedFromText`) and `SyncAction.update` (from `updateCraftedFromText`) flow through this method, so re-crafting a row automatically re-uploads the new bytes.
- Local-first semantics are preserved: `_storage.importBytes` writes to local `media/` first, then the queue is enqueued with `syncStatus: 'pending'`. The user can play locally before the upload completes.

**Alternatives considered**:
- *Place it in `MediaLibraryRepository.importCraftedFromText` directly.* Rejected: it would duplicate the offline / retry / conflict logic, and would miss the re-craft path (which goes through `updateCraftedFromText`).
- *Place it in `CraftController.saveToLibrary` directly (eager sync).* Rejected: eager blocking upload would delay the "save to library" action and fail entirely when offline. The queue-based approach is better UX and consistent with the rest of the sync layer.
- *Two-stage upload: blob first, then JSON sync as a separate queue item.* Rejected: doubles queue churn; the single combined step is sufficient because `DirectUploadsApi.uploadBlob` is idempotent given the same content hash and the existing 409 path handles dedupe.

## Decision 2 — Reuse `DirectUploadsApi.uploadBlob` (no new HTTP code)

**Decision**: Reuse the existing `DirectUploadsApi` at `lib/data/api/services/direct_uploads_api.dart` as-is. It already wraps the Rails Active Storage direct-upload protocol: POST metadata → receive signed URL + signed headers → PUT raw bytes to the signed URL → return `signedId`. No new HTTP client code is needed.

**Rationale**:
- The same endpoint is used by the web app (`apps/web/src/lib/activestorage/uploader.ts`) and by the avatar upload in this codebase (`lib/features/auth/data/auth_repository.dart:262`). The Rails server already accepts these calls and returns a `signedId` that can be attached to any model.
- The MD5 checksum the server expects is cheap to compute (we already have SHA-256 of the bytes; computing MD5 in the upload step is negligible).
- Auth pattern is correct: the `POST /api/v1/direct_uploads` request carries the user's bearer token (set by `ApiClient._ensureAuthenticated`), but the subsequent `PUT` to the signed storage URL uses pre-signed headers (no bearer token) — exactly matching the web app's `ActiveStorageUploader`.

**Alternatives considered**:
- *Use `ApiClient.postMultipartJson` with the audio as a multipart field.* Rejected: doubles bandwidth for large audios (Rails server has to re-receive the bytes it's about to PUT to storage anyway). Direct upload avoids the double-handling.
- *Build a new presigned-URL flow against R2/S3 directly.* Rejected: would require knowing the storage backend and the signing keys. The Rails server already exposes the right abstraction.

## Decision 3 — Add a `FileStorage.readAppManagedMedia` helper

**Decision**: Add `Future<Uint8List?> readAppManagedMedia(String fileUri)` to `FileStorage` in `lib/data/files/file_storage.dart`. The method:
- Returns `null` for null/empty input, non-app-managed paths, and missing files (mirroring `deleteAppManagedMedia`).
- Otherwise reads the bytes from the file.
- Runs the read inside `Isolate.run` so the calling isolate (Riverpod notifier / sync engine) is not blocked on a multi-MB read.

**Rationale**:
- The current code pattern is `File(Uri.parse(localUri).toFilePath()).readAsBytes()` inline at call sites (e.g. `capture_stage.dart:208`, `asr_audio_extractor.dart:85`). The new helper centralizes this for the new sync path.
- The sync flow reads bytes off the main isolate; doing it inside `FileStorage` keeps the off-isolate policy consistent with `importOrLinkPickedFile` (which already uses `Isolate.run`).
- Returning `null` (not throwing) lets the sync layer cleanly distinguish "no local file to upload" from "I/O failed", and lets it no-op when the row is already cloud-synced (no need to re-upload).

**Alternatives considered**:
- *Inline the read at the call site.* Rejected: the off-isolate policy is non-obvious; centralizing in `FileStorage` keeps the rule consistent.
- *Cache bytes in memory at write time.* Rejected: would double memory usage for libraries with many crafted audios and is irrelevant for sync because uploads happen infrequently.

## Decision 4 — Server contract: `signedId` in the JSON body

**Decision**: Extend `prepareForSyncAudioMap` (in `lib/features/sync/data/sync_serializers.dart:41`) to accept an optional `signedId` and include it in the JSON payload to `/api/v1/mine/audios`. The Rails server is expected to attach the blob (via Active Storage) to the audio model and return a populated `mediaUrl` in the response.

**Rationale**:
- Mirrors the web app's `attachMediaBlobToPayload` in `apps/web/src/db/services/sync-upload-helpers.ts:72`. The server already implements this contract for the web client.
- Sending the `signedId` instead of pre-populating `mediaUrl` keeps the server in control of the canonical cloud URL — important because the URL can change if storage is migrated or signed URLs expire.

**Fallback**:
- If the server response does not include `mediaUrl` after we sent `signedId`, we log a warning and continue: the row stays valid locally (`localUri` is the source of truth on this device), and the next queue drain will retry. The `cloudSyncBadge` will show "Pending sync" until it succeeds. This matches the spec's offline-tolerance story (FR-004, US-1 acceptance 3).

**Alternatives considered**:
- *Pre-resolve the `mediaUrl` ourselves (e.g. construct a CDN URL from the blob key).* Rejected: we don't know the storage topology, and the server is the source of truth for URLs.
- *Two-step: upload blob first, wait for server response with `mediaUrl`, then issue a second JSON PATCH to update the row.* Rejected: doubles server round-trips. The single-request attach is sufficient.

## Decision 5 — UI indicator via existing `providerBadge` slot

**Decision**: Add an optional `cloudSyncBadge: MediaCardSyncBadge?` parameter to `MediaCardRow` and `MediaCardTile` in `lib/core/theme/widgets/media_card/`. The badge reuses the existing `MediaCardProviderBadgePill` style (rounded pill, top-right of thumbnail) but with new icon + color mapping:

| State | Icon | Color | Tooltip / text |
|---|---|---|---|
| `mediaUrl != null` | cloud-check | green | "Synced to cloud" |
| `mediaUrl == null && syncStatus == 'pending'` | cloud-upload | muted | "Pending sync" |
| `mediaUrl == null && syncStatus == null` (never enqueued) | cloud-off | muted | "Local only" |

The badge is populated by the row builders in `local_library_tab_view.dart:151/271` and `home_screen.dart:478` from `row.mediaUrl` and `row.syncStatus`.

**Rationale**:
- The existing `MediaCardProviderBadgePill` is the only per-card status indicator today (used for the `youtube` and `craft` pills). Adding a parallel pill slot keeps the layout consistent and avoids inventing a new widget family.
- The state is derived from existing row fields — no new column or schema change needed.
- Localized strings ("Synced to cloud", "Pending sync", "Local only") are added to ARB; the badge widget is fed the resolved localized string from its caller so it stays presentation-only.

**Alternatives considered**:
- *Add a third column `mediaBytesSynced: boolean` to the audios table.* Rejected: the state is fully derivable from `(mediaUrl != null, syncStatus)`; adding a denormalized column would invite drift.
- *Inline the badge inside each row builder.* Rejected: three call sites already exist; centralizing in the widget prevents drift.

## Decision 6 — Delete lifecycle (FR-007, US-4)

**Decision**: Extend the existing `SyncUploadService.deleteAudio` path (or add a new pre-step inside the delete handler) so that when a crafted audio row is deleted locally, the server is told to remove the underlying blob. We do this by sending the audio's `signedId` to a new field in the DELETE request (or via a server-side endpoint that deletes by audio id). The existing best-effort semantics of the queue apply: if the delete request fails, the row stays in the `sync_queue` retrying; the user sees the cloud object may briefly persist until the queue catches up.

**Rationale**:
- The web app's `saveLocalAudio` and `saveTTSAudio` both delete via the `SyncEngine`; mirroring that behavior for our delete path keeps the lifecycle consistent.
- Best-effort is acceptable per US-4 / SC-006: "scheduled for deletion" within 5 minutes — not a hard real-time guarantee.

**Alternatives considered**:
- *Two-step delete: orphan the local row first, then asynchronously fire-and-forget the cloud delete.* Rejected: makes auditing harder; the queue-based approach gives us retry + observability for free.
- *Skip the cloud delete entirely and rely on storage TTL / GC.* Rejected: the spec requires explicit removal (FR-007, SC-006). Also: we don't have a TTL contract from the storage backend.

## Decision 7 — Performance: off-isolate bytes read + PUT

**Decision**:
- The byte read (`FileStorage.readAppManagedMedia`) runs inside `Isolate.run` so the main isolate is not blocked while loading multi-MB audio.
- The PUT of bytes (inside `DirectUploadsApi.uploadBlob`) already runs inside the `ApiClient.putBytesAbsolute` call, which uses an HTTP client without blocking the main isolate (Dart's `http` package is async). No additional change needed.
- The Riverpod notifier that wraps `CraftAudioCloudUploader` runs in a `FutureProvider` / `AsyncNotifier` so the UI badge updates reactively when `mediaUrl` is populated.

**Rationale**:
- Matches principle IV ("Performance Is a Requirement") and the constitution's "expensive work out of `build`" guidance.
- Without the off-isolate read, a 5 MB crafted audio could jank the UI thread for ~100 ms while the read is in flight (worse on Android with slow flash).

**Alternatives considered**:
- *Read bytes on the main isolate (simpler).* Rejected: violates the constitution's performance principle for a feature that is explicitly about adding an upload step.

## Decision 8 — No new `syncStatus` enum value

**Decision**: Reuse the existing `syncStatus` values (`'pending'`, `'synced'`, `'local'`, `null`). Do not introduce a transient `'uploading'` value.

**Rationale**:
- The transient `'uploading'` state would need to be persisted (otherwise it disappears on app restart), and the upload itself is fast (< 30 s on a normal network per SC-002). A persistent row flag for a transient UI state is not worth the complexity.
- The existing `'pending'` value already covers "upload not yet completed" — sufficient for the badge.

**Alternatives considered**:
- *Add `'uploading'` and `'failed'` to the enum.* Rejected: see rationale. The queue retry state already surfaces in `SyncQueueSnapshot` and the Settings → Sync Status screen, which is the right place for "permanent failure" visibility.

## Open items deferred to plan execution

- **Auth refresh on the direct-upload POST**: `ApiClient._ensureAuthenticated` already handles 401-refresh-retry for bearer-authenticated calls. The `PUT` to the signed URL is unauthenticated by design. No additional refresh logic needed.
- **Telemetry**: a `craft_audio_upload_attempt` / `craft_audio_upload_success` / `craft_audio_upload_failure` log line is added so SC-001 / SC-002 / SC-006 can be verified from production logs. No new analytics provider required.
- **Migration of existing `mediaUrl = null` crafted audios**: users with a pre-feature crafted audio will see "Pending sync" on first launch and the row will be re-enqueued. No data migration needed — the existing offline queue handles it.

## References

- Spec: `specs/043-craft-cloud-sync/spec.md`
- Plan: `specs/043-craft-cloud-sync/plan.md`
- Web app direct upload: `~/projects/enjoy/apps/web/src/lib/activestorage/uploader.ts`
- Web app attach helper: `~/projects/enjoy/apps/web/src/db/services/sync-upload-helpers.ts:72`
- Web app sync engine: `~/projects/enjoy/apps/web/src/db/services/sync-upload.ts:32`
- Existing client direct uploads: `lib/data/api/services/direct_uploads_api.dart`
- Existing client sync upload: `lib/features/sync/data/sync_upload_service.dart`
- Existing client craft repository: `lib/features/library/data/library_repository.dart:340`
- Existing client craft controller: `lib/features/craft/application/craft_controller.dart:209`
- Existing client resolver: `lib/data/db/media_target_resolver.dart`