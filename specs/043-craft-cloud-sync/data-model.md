# Data Model: Crafted Audio Cloud Sync

**Date**: 2026-08-21
**Feature**: [spec.md](./spec.md) | [plan.md](./plan.md) | [research.md](./research.md)

This document captures the data-model changes and the existing entities that participate in the feature. **No new columns or tables are introduced** — the data model already has the right shape (see Decision 8 in `research.md`). The work is in how the existing columns are populated and read.

## Existing entities

### `AudioRow` (Drift `audios` table — `lib/data/db/tables/audios.dart`)

The full table is unchanged. The relevant columns for this feature:

| Column | Type | Purpose for crafted-audio cloud sync |
|---|---|---|
| `id` | `text` PK | Stable row identity (server-issued on first sync). |
| `provider` | `text` default `'user'` | Discriminator. Crafted audios are `provider = 'craft'`. **This feature only acts on rows where `provider = 'craft'`.** |
| `title` | `text` | User-facing title of the crafted audio. |
| `localUri` | `text?` | App-managed path to the audio binary on the current device (e.g. `<appDocs>/media/<sha256>.wav`). Set by `FileStorage.importBytes` during craft. |
| `bookmarkData` | `blob?` | macOS security-scoped bookmark bytes. Always `null` for crafted audios (they're app-managed). |
| `md5` | `text?` | SHA-256 hex of the audio bytes (the column is mis-named; it stores SHA-256 per `FileStorage.importBytes`). Used as the content hash for cloud deduplication and as the local filename. |
| `size` | `int?` | Size of the audio bytes in bytes. |
| `localMtimeMs` | `int?` | Last-modified ms of the local file at write time. |
| `mediaUrl` | `text?` | **Cloud URL returned by the server after upload.** Currently `null` for crafted audios. **This feature populates this column** so that the resolver can fall back to it on other devices. |
| `syncStatus` | `text?` (from `SyncMetadataColumns`) | `'pending'`, `'synced'`, `'local'`, or `null`. Drives the queue + badge. |

Indexes (`idx_audios_local_uri`, `idx_audios_md5`) are reused unchanged.

### `sync_queue` (Drift table — `lib/features/sync/data/sync_queue_repository.dart`)

Unchanged. The offline queue already supports arbitrary entity types and action types; crafted audios reuse `SyncEntityType.audio` + `SyncAction.create` / `SyncAction.update`.

### `transcripts` (Drift table)

Unchanged. The transcript metadata for a crafted audio is already synced via the existing metadata-only flow (see `MediaLibraryRepository.updateCraftedFromText:526-622`).

## Domain model

The `Media` domain class at `lib/features/library/domain/media.dart` already exposes:

```dart
bool get isLink => mediaUrl != null && mediaUrl!.isNotEmpty;
bool get isLocal => !isLink;
```

After this feature, a crafted audio row with `provider = 'craft'` and `mediaUrl != null` will report `isLink == true` even though `localUri` is also set. This is fine because the `MediaSourceResolver.resolvePlayableSource` precedence is:

1. `localUri` if trusted → `LocalFilePlayableSource`
2. `mediaUrl` if present → `RemoteUrlPlayableSource`
3. `null` → fail

The `isLink` accessor would change meaning slightly (currently "no local file, only cloud"; will become "has a cloud URL, may or may not have a local file"). We must check all consumers of `isLink`/`isLocal` and either:

- Update them to use `MediaTargetResolver` as the source of truth, or
- Add a new accessor `bool get isCloudBacked => mediaUrl != null && mediaUrl!.isNotEmpty` and migrate consumers.

**Action item for implementation**: grep all consumers of `media.isLink` / `media.isLocal` and verify they still work correctly when a row has both `localUri` and `mediaUrl`. If any consumer is broken (e.g. "if isLocal, show re-import button" no longer makes sense when the row is also cloud-backed), update the consumer to use the new accessor. See `lib/features/library/presentation/widgets/local_library_tab_view.dart` and `home_screen.dart` for likely consumers.

## State transitions

### Crafted audio lifecycle (this feature)

```
                ┌─────────────────────────────┐
                │   user crafts + saves to    │
                │       library               │
                └────────────┬────────────────┘
                             │
                             ▼
   ┌─────────────────────────────────────────────┐
   │  localUri set, md5 set, mediaUrl = null     │
   │  syncStatus = 'pending'                     │
   │  sync_queue row: (audio, id, create)        │
   └────────────┬────────────────────────────────┘
                │ SyncEngine picks up
                ▼
   ┌─────────────────────────────────────────────┐
   │  SyncUploadService.uploadAudio              │
   │   1. if provider == 'craft':                │
   │        read bytes off-isolate               │
   │        DirectUploadsApi.uploadBlob          │
   │        signedId obtained                    │
   │   2. POST /api/v1/mine/audios               │
   │        {audio: {...row..., signedId}}       │
   │   3. response.mediaUrl → stamp on row       │
   └────────────┬────────────────────────────────┘
                │
       ┌────────┴───────────┐
       │ success            │ failure
       ▼                    ▼
   ┌──────────┐         ┌────────────────┐
   │ mediaUrl │         │ retry with      │
   │ set,     │         │ exponential    │
   │ syncStatus│        │ backoff (≤5x); │
   │ ='synced'│         │ row stays      │
   │          │         │ 'pending'      │
   └────┬─────┘         └────┬───────────┘
        │                    │
        ▼                    ▼
   ┌─────────────────────────────────────────────┐
   │  badge renders "Synced to cloud"            │
   │  resolver can use mediaUrl on other devices │
   └─────────────────────────────────────────────┘
```

### Re-craft (editing an existing crafted audio)

```
   ┌─────────────────────────────────────────────┐
   │  user edits + saves in Craft studio         │
   │  updateCraftedFromText()                    │
   │   - overwrite localUri bytes                │
   │   - overwrite md5 (new SHA-256)             │
   │   - overwrite size, localMtimeMs            │
   │   - mediaUrl stays (will be replaced)       │
   │   - syncStatus = 'pending'                  │
   │   - sync_queue row: (audio, id, update)     │
   └────────────┬────────────────────────────────┘
                │
                ▼
   ┌─────────────────────────────────────────────┐
   │  SyncUploadService.uploadAudio (update)     │
   │   - new bytes uploaded via DirectUploadsApi │
   │   - new signedId sent to server             │
   │   - server replaces blob, returns new URL   │
   │   - mediaUrl overwritten on row             │
   └─────────────────────────────────────────────┘
```

### Delete

```
   ┌─────────────────────────────────────────────┐
   │  user deletes crafted audio from library     │
   │  MediaLibraryRepository.deleteMedia          │
   │   - local row deleted                       │
   │   - sync_queue row: (audio, id, delete)     │
   └────────────┬────────────────────────────────┘
                │
                ▼
   ┌─────────────────────────────────────────────┐
   │  SyncUploadService.deleteAudio (TBD)        │
   │   - send server DELETE with signedId        │
   │   - server removes blob                     │
   │   - row removed from sync_queue             │
   └─────────────────────────────────────────────┘
```

(TBD: the exact server contract for delete is one of the items in Decision 6 — implementation must confirm the delete endpoint accepts a `signedId` and removes the underlying blob, or use a parallel endpoint. If the server does not support this, the delete is best-effort and a follow-up ADR is filed.)

## Validation rules

- A row with `provider = 'craft'` MUST have a non-null `md5` (SHA-256 hex of the audio bytes) — guaranteed by `FileStorage.importBytes` which sets it before the row is inserted.
- A row with `provider = 'craft'` MUST have a non-null `localUri` — guaranteed by `importBytes` returning a `fileUri`.
- A row with `provider = 'craft'` MUST have a `mediaUrl` set within 5 minutes of being enqueued (under normal network) — the offline queue enforces this.
- `mediaUrl` MUST match the same scheme/host the server uses for other audios — enforced by reusing the existing `mediaUrl` parsing path in `MediaSourceResolver`.
- The `md5` column is SHA-256 hex (64 chars). For deduplication, two crafted rows with the same `md5` (i.e., same source text + voice + language) share the same cloud blob (the server handles this via Active Storage's content-addressing).

## Migration

**None.** No schema changes. Existing pre-feature crafted audios have `mediaUrl = null` and will be transparently re-synced on first launch because:

- `MediaLibraryRepository` enqueues a `'pending'` sync for any audio that is opened / listed / interacted with via the existing refresh path.
- Even without explicit re-enqueue, the user can trigger a full sync from Settings → Sync Status, which calls `SyncEngine.fullSync` → `processQueue` → drains the queue.

No data loss. No downtime. No user-facing migration step.

## Implementation hooks

| Concern | File | Change |
|---|---|---|
| Bytes read off-isolate | `lib/data/files/file_storage.dart` | Add `readAppManagedMedia(fileUri)` |
| Binary upload encapsulation | `lib/features/craft/application/craft_audio_cloud_uploader.dart` | NEW class. Composes `FileStorage`, `DirectUploadsApi`, `AudioDao`. Method: `Future<String?> uploadIfNeeded(AudioRow row)` |
| Wire binary upload into sync | `lib/features/sync/data/sync_upload_service.dart` | Inject `CraftAudioCloudUploader` into the constructor. In `uploadAudio()`, call it before the JSON POST when `row.provider == 'craft'`. Pass the `signedId` to the serializer. |
| Send signedId in JSON | `lib/features/sync/data/sync_serializers.dart` | Extend `prepareForSyncAudioMap` to accept an optional `signedId` and include it in the body. |
| Delete lifecycle | `lib/features/sync/data/sync_upload_service.dart` | Extend `deleteAudio` to send the `signedId` (or use a server-side endpoint) to remove the cloud blob. |
| UI badge | `lib/core/theme/widgets/media_card/row.dart` and `tile.dart` | Add optional `cloudSyncBadge: MediaCardSyncBadge?` parameter. |
| UI badge state | `lib/features/library/presentation/widgets/local_library_tab_view.dart`, `home_screen.dart` | Populate `cloudSyncBadge` from `row.mediaUrl` + `row.syncStatus`. |
| DirectUploadsApi wiring | `lib/features/sync/application/sync_providers.dart` | Expose a Riverpod provider for `DirectUploadsApi` (currently only instantiated in auth). |
| ARB strings | `lib/l10n/app_en.arb` (and other locales) | Add "Synced to cloud", "Pending sync", "Local only". |