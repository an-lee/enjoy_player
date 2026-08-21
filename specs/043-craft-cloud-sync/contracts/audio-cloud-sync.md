# Contracts: Crafted Audio Cloud Sync

**Date**: 2026-08-21
**Feature**: [spec.md](./spec.md) | [plan.md](./plan.md) | [research.md](./research.md)

This document specifies the external interfaces that participate in the feature. There are three contracts:

1. **Direct upload (blob)**: existing client `DirectUploadsApi.uploadBlob` → Rails `POST /api/v1/direct_uploads` → returns `signedId`.
2. **Audio metadata + blob attach (existing)**: existing client `AudioApi.uploadAudio` → Rails `POST /api/v1/mine/audios`, now with an added `signedId` field for crafted rows.
3. **Audio delete (existing)**: existing client `AudioApi.deleteAudio` → Rails `DELETE /api/v1/mine/audios/:id`, extended (TBD — see below) to also remove the underlying blob.

The contracts below describe what the *client* sends and what the *server* must return. They are forward-compatible with the existing web app implementation in `~/projects/enjoy/apps/web/src/lib/activestorage/uploader.ts` and `apps/web/src/db/services/sync-upload-helpers.ts`.

---

## Contract 1 — Direct upload (blob)

### Client → server: `POST /api/v1/direct_uploads`

Headers:
- `Authorization: Bearer <user_token>` (set by `ApiClient._ensureAuthenticated`)

Request body (JSON):
```json
{
  "blob": {
    "filename": "craft-<sha256-prefix>.wav",
    "byteSize": 245760,
    "checksum": "<md5-base64-of-bytes>",
    "contentType": "audio/wav"
  }
}
```

Notes:
- `filename` is a hint for storage; the client should set it to a content-derived name (e.g. `craft-<first-8-chars-of-sha256>.<ext>`) so multiple devices uploading the same content produce the same filename. This is *advisory* — the server may rewrite it.
- `byteSize` is the exact byte length of the audio.
- `checksum` is **MD5** of the bytes (base64-encoded), per Rails Active Storage convention. The client must compute this before the POST. (`DirectUploadsApi.uploadBlob` already does this.)
- `contentType` is the audio MIME type (`audio/wav`, `audio/mpeg`, `audio/mp4`, etc.).

### Server → client: 200 OK

Response body (JSON):
```json
{
  "signedId": "eyJfcmFpbHMi...",
  "directUpload": {
    "url": "https://storage.example.com/.../...",
    "headers": {
      "Content-MD5": "<md5-base64>",
      "Content-Type": "audio/wav"
    }
  }
}
```

### Client → storage: `PUT <directUpload.url>`

Headers:
- Each key/value in `directUpload.headers` (set by the server, not the client).
- **No `Authorization` header** — the storage URL is pre-signed.

Body: raw audio bytes.

Expected: `200 OK` from storage (no body parsing).

### Client usage (Dart)

```dart
final signedId = await directUploadsApi.uploadBlob(
  bytes: audioBytes,
  filename: 'craft-${row.md5!.substring(0, 8)}.${audioFormat}',
  contentType: 'audio/$audioFormat',
);
```

Already implemented in `lib/data/api/services/direct_uploads_api.dart`. **No change required.**

---

## Contract 2 — Audio metadata + blob attach

### Client → server: `POST /api/v1/mine/audios`

Headers:
- `Authorization: Bearer <user_token>`

Request body (JSON):
```json
{
  "audio": {
    "id": "<server-issued-or-client-id>",
    "aid": "<alt-id>",
    "provider": "craft",
    "title": "Hello, world!",
    "sourceText": "Hello, world!",
    "voice": "alloy",
    "translationKey": "<translation-cache-key>",
    "source": "craft-direct",
    "language": "en",
    "durationSeconds": 3,
    "md5": "<sha256-hex-of-bytes>",
    "size": 245760,

    "signedId": "eyJfcmFpbHMi...",
    "mediaUrl": null
  }
}
```

**New field for this feature**: `signedId` (optional, only present for crafted rows). When set, the server MUST attach the previously-uploaded blob to the audio model and populate `mediaUrl` in the response.

For non-crafted rows (`provider = 'user'`, `'youtube'`), `signedId` MUST NOT be sent — these rows either have no binary (YouTube) or already have a `mediaUrl` from a separate user-driven cloud add (`provider = 'user'` from `cloud_add_to_library`).

### Server → client: 200 OK (or 200 with `mediaUrl` populated)

Response body (JSON):
```json
{
  "audio": {
    "id": "<server-issued-or-echoed-id>",
    "mediaUrl": "https://storage.example.com/.../.../audio.wav?...",
    "serverUpdatedAt": "2026-08-21T12:34:56.789Z"
    // ... all other fields echoed back
  }
}
```

For a crafted audio, the server MUST return `mediaUrl` populated.

### Server → client: 409 Conflict (existing behavior)

If the audio already exists on the server with the same `id`, the server returns 409 with the existing audio. The client MUST then fetch the existing row via `GET /api/v1/mine/audios/:id` and copy its `mediaUrl` locally. (This is the existing 409-dedupe path in `SyncUploadService.uploadAudio` — unchanged.)

### Fallback contract

If the server does not implement the `signedId` attach and returns `mediaUrl = null` despite our request:

- The client MUST NOT treat this as a hard error.
- The client MUST log a warning (`craft_audio_attach_unsupported`) and keep the row with `mediaUrl = null`, `syncStatus = 'pending'`.
- The next queue drain re-attempts the upload.
- The UI badge shows "Pending sync" until `mediaUrl` is eventually populated.

This is the same offline-tolerant behavior as a network failure.

### Client usage (Dart)

```dart
// In SyncUploadService.uploadAudio
String? signedId;
if (row.provider == 'craft') {
  signedId = await craftAudioCloudUploader.uploadIfNeeded(row);
}

final response = await audioApi.uploadAudio(
  prepareForSyncAudioMap(row, signedId: signedId),
);
// ... existing 409-dedupe + mediaUrl stamping logic
```

---

## Contract 3 — Audio delete (extended)

### Client → server: `DELETE /api/v1/mine/audios/:id`

Headers:
- `Authorization: Bearer <user_token>`

Request body: none (the `id` is in the URL).

Response: `200 OK` or `204 No Content`. The server MUST remove the underlying Active Storage blob associated with this audio id.

**Status of this contract**: the existing `AudioApi.deleteAudio` works for non-crafted rows (which have no client-uploaded blob). For crafted rows, the server-side contract is **TBD** — implementation needs to confirm whether:

  (a) The existing `DELETE /api/v1/mine/audios/:id` endpoint already cascades to the blob (Rails `dependent: :destroy` on the `has_one_attached :file`), OR
  (b) A separate `DELETE /api/v1/direct_uploads/:signedId` endpoint is required, OR
  (c) The blob persists server-side after the row is deleted and must be cleaned up via a separate `ActiveStorage::Blob` purge job.

**Recommended approach** for the implementation phase:
- First, audit the web app (`~/projects/enjoy/apps/web/src/db/repositories/audio-repository.ts` and any delete code) to confirm whether (a), (b), or (c) is the existing pattern.
- If (a): no contract change needed — just ensure the client sends the right `id` and trusts the cascade.
- If (b): add a new `DirectUploadsApi.deleteBlob(signedId)` method and call it from `SyncUploadService.deleteAudio` after the row delete succeeds.
- If (c): best-effort, fire-and-forget a cleanup request via a new server endpoint (or accept that orphaned blobs may exist for a short period).

This contract is intentionally left **TBD in the planning phase** and will be resolved during implementation by reading the web app's delete path and the Rails server's model definition (if accessible). The decision is recorded in `docs/decisions/0081-crafted-audio-cloud-sync.md`.

### Client usage (Dart, current)

```dart
await audioApi.deleteAudio(id);
```

Already implemented in `lib/data/api/services/audio_api.dart`. **Extension TBD** based on the audit above.

---

## Contract 4 — UI badge (internal contract, no server)

The `MediaCardSyncBadge` value rendered by `MediaCardRow` / `MediaCardTile` is computed from the row:

| `mediaUrl` | `syncStatus` | Badge |
|---|---|---|
| non-null | any | `MediaCardSyncBadge.synced` (icon: cloud-check, color: success-green) |
| null | `'pending'` | `MediaCardSyncBadge.pending` (icon: cloud-upload, color: muted) |
| null | `'synced'` | (impossible — synced requires `mediaUrl`); render nothing |
| null | `'local'` or `null` | `MediaCardSyncBadge.localOnly` (icon: cloud-off, color: muted) |
| null | anything else | `MediaCardSyncBadge.localOnly` (defensive default) |

This is a derived value, computed at render time by the row builder. No persistence, no server contract.

### Dart type (illustrative)

```dart
enum MediaCardSyncBadge {
  synced,
  pending,
  localOnly;

  IconData get icon => switch (this) {
    synced => Icons.cloud_done_outlined,
    pending => Icons.cloud_upload_outlined,
    localOnly => Icons.cloud_off_outlined,
  };
}
```

Implementation detail — final shape lives in `lib/core/theme/widgets/media_card/`.

---

## Backward compatibility

- **Server**: adding `signedId` to the JSON body is additive. Existing servers that don't read it will continue to work (the row will have `mediaUrl = null` and the client will retry on next drain, then fall back to the offline-tolerant behavior described in Contract 2).
- **Client**: `signedId` is optional in `prepareForSyncAudioMap`. Non-crafted audios send the same body they do today.
- **Database**: no schema change. Existing rows continue to work.
- **Web app**: not affected. The web app already uses `signedId` (via `attachMediaBlobToPayload`).