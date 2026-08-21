# Implementation Plan: Crafted Audio Cloud Sync

**Branch**: `043-craft-cloud-sync` | **Date**: 2026-08-21 | **Spec**: [spec.md](./spec.md)

**Input**: Feature specification from `/specs/043-craft-cloud-sync/spec.md`

## Summary

Today, a user who crafts a TTS audio on one device (e.g. Android) cannot open it on another device (e.g. Windows) — the library row references a local sandbox path (`<appDocs>/media/<sha256>.wav`) that doesn't exist on the new device. The existing `MediaSourceResolver` falls back to `mediaUrl` when `localUri` is untrusted, but for crafted audios `mediaUrl` is always `null` because the sync layer only uploads metadata, never the audio binary.

This plan adds the missing step: when a crafted audio (`provider = 'craft'`) is added to the library, the audio binary is uploaded to cloud storage (Rails Active Storage via the existing `DirectUploadsApi.uploadBlob` endpoint) and the resulting `signedId` is attached to the audio row. The server returns a `mediaUrl` that is persisted locally and used by the resolver on every other device the user signs into. Imported user files (`provider = 'user'`) and YouTube downloads (`provider = 'youtube'`) are explicitly excluded.

Reference: web app implementation at `~/projects/enjoy/apps/web/src/lib/activestorage/uploader.ts` and `apps/web/src/db/services/sync-upload-helpers.ts` (`attachMediaBlobToPayload`).

## Technical Context

**Language/Version**: Dart 3.x on Flutter stable (matches `pubspec.yaml` minimum Flutter SDK).

**Primary Dependencies**:
- `flutter_riverpod` — state orchestration (existing standard).
- `drift` + `drift_flutter` — local persistence (existing).
- `dio`-less `ApiClient` in `lib/data/api/api_client.dart` — bearer-auth HTTP + raw-bytes PUT.
- `crypto` — MD5 + SHA-256 (already in deps for `importBytes`).
- `package:logging` via project helpers (existing standard).
- No new third-party dependencies required.

**Storage**:
- Local: Drift `audios` table (already has `localUri`, `mediaUrl`, `md5`, `size`, `syncStatus`, `sync_metadata` mixin).
- Cloud: Rails Active Storage behind `POST /api/v1/direct_uploads` (existing `DirectUploadsApi`). Blob storage backend is whatever the Rails app uses (R2/S3/etc.) — out of scope for the client.

**Testing**: `flutter test` for unit tests (Drift DAO, repository, sync upload service); widget tests for the new sync badge; integration smoke test by running the app against a stubbed `DirectUploadsApi`. Generated code (`build_runner`) re-run before analysis/tests.

**Target Platform**: Android, iOS, macOS, Windows, Linux (per constitution v1.2.0 — Flutter web is out of scope).

**Project Type**: cross-platform Flutter desktop + mobile app.

**Performance Goals**:
- P-1: Crafted-audio upload for an entry `< 5 MB` completes within 30 s on a normal network (matches SC-002).
- P-2: Local playback latency is unchanged — the binary upload is purely additive and must not delay the "play locally" path.
- P-3: Reading bytes from `localUri` to upload must happen off the main isolate (the bytes can be tens of MB for long TTS).
- P-4: Per-row sync badge must render within one frame; the existing `MediaCardRow`/`MediaCardTile` build path must not regress.

**Constraints**:
- Offline-capable: crafted audio must save and play locally even when the network is unavailable at craft time (FR-004).
- Cross-platform: the upload path must work identically across Android, iOS, macOS, Windows, Linux (per constitution v1.2.0).
- Local-first: cloud is a *replica*, not a *source of truth* — the local file is still authoritative when present.
- No silent quota consumption for imported files (FR-005).

**Scale/Scope**:
- Per-user library; typical library size ≤ a few thousand entries, of which a small minority are crafted audios.
- Crafted audios are short TTS outputs (target ≤ a few MB), so the volume of bytes uploaded is small in aggregate.
- One new HTTP endpoint usage (`/api/v1/direct_uploads`), one new field on the JSON payload to `/api/v1/mine/audios` (`signedId`).

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Status | Notes |
|---|---|---|
| I. Architecture & Code Quality — feature-first layout | **Pass** | All new code lives under existing `lib/features/craft/`, `lib/features/sync/`, and `lib/data/files/`. No feature-to-feature shortcuts. |
| I. — Drift DAOs + Riverpod providers | **Pass** | Reuses `AudioDao`, `SyncQueueRepository`, Riverpod `syncEnqueueProvider`. No new global singletons. |
| I. — Domain free of Flutter widgets | **Pass** | The new `CraftAudioCloudUploadService` and `FileStorage.readAppManagedMedia` are pure data/domain code. The badge widget lives under `lib/core/theme/widgets/media_card/`. |
| II. Testing Defines the Contract | **Pass (with required tests)** | Must include unit tests for `SyncUploadService.uploadAudioCraftedBranch`, `CraftAudioCloudUploadService.upload`, `FileStorage.readAppManagedMedia`; widget test for `MediaCardRow` with `cloudSyncBadge`. |
| II. — `build_runner` before analysis | **Pass** | No new Drift schemas, no `@riverpod` annotations required for the core upload logic (a new provider can be added; if so, generated files committed per `[[riverpod-codegen-hash-quirk]]` memory). |
| III. UX Consistency — reuse primitives | **Pass** | The new badge reuses the existing `MediaCardProviderBadgePill` slot on `MediaCardRow`/`MediaCardTile` (already used for `youtube`/`craft` provider pills). |
| III. — ARB localization | **Pass** | New user-visible strings ("Syncing to cloud", "Synced to cloud", "Cloud sync failed") are added to ARB. |
| III. — `docs/features/` update | **Pass (required)** | A new or updated `docs/features/craft-studio.md` (or equivalent) documents the cross-platform sync behavior. |
| IV. Performance Is a Requirement | **Pass** | Performance goals (P-1..P-4) are stated above. Byte read + PUT happens off the main isolate; UI badge reads cached sync state and does not block. |
| V. Documentation & Traceability | **Pass (required)** | A new ADR (`docs/decisions/0081-crafted-audio-cloud-sync.md`) records the choice of Active Storage direct-upload + per-row binary sync (vs alternatives). |

No constitution violations. The table above also lists the required tests / docs that must be produced alongside the implementation.

## Project Structure

### Documentation (this feature)

```text
specs/043-craft-cloud-sync/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
│   └── audio-cloud-sync.md
├── checklists/
│   └── requirements.md
└── spec.md
```

### Source Code (repository root)

```text
lib/
├── data/
│   ├── api/services/
│   │   └── direct_uploads_api.dart          # already exists — used as-is
│   ├── files/
│   │   └── file_storage.dart                # add readAppManagedMedia()
│   └── db/
│       └── tables/audios.dart               # no schema changes needed
├── features/
│   ├── craft/
│   │   ├── application/
│   │   │   ├── craft_controller.dart        # no change — repository handles it
│   │   │   └── craft_audio_cloud_uploader.dart   # NEW: encapsulates "upload binary + persist mediaUrl" for crafted rows
│   │   └── presentation/
│   │       └── widgets/local_library_tab_view.dart   # pass cloudSyncBadge
│   ├── library/
│   │   ├── data/
│   │   │   └── library_repository.dart      # call uploader after importBytes
│   │   └── presentation/
│   │       ├── home_screen.dart             # pass cloudSyncBadge
│   │       └── widgets/local_library_tab_view.dart  # pass cloudSyncBadge
│   ├── sync/
│   │   ├── data/
│   │   │   ├── sync_upload_service.dart     # inject binary upload before JSON POST for crafted rows
│   │   │   └── sync_serializers.dart        # send signedId in the payload
│   │   └── application/
│   │       └── sync_providers.dart          # wire DirectUploadsApi + CraftAudioCloudUploader
│   └── player/                              # no change — RemoteUrlPlayableSource already handled
└── core/
    └── theme/widgets/media_card/
        ├── row.dart                         # add cloudSyncBadge
        └── tile.dart                        # add cloudSyncBadge

test/
├── features/
│   ├── craft/application/craft_audio_cloud_uploader_test.dart   # NEW
│   ├── sync/data/sync_upload_service_crafted_branch_test.dart   # NEW
│   └── library/data/library_repository_crafted_test.dart         # NEW
├── data/files/file_storage_read_app_managed_media_test.dart    # NEW
└── core/theme/widgets/media_card/row_cloud_sync_badge_test.dart # NEW

docs/
├── features/craft-studio.md                 # UPDATE: document cross-platform sync
└── decisions/0049-crafted-audio-cloud-sync.md   # NEW ADR
```

**Structure Decision**: Single Flutter project (Option 1 in the template) — this is the standard for `enjoy_player`. New code is added inside the existing feature-first layout, no new top-level directories.

## Complexity Tracking

> **No violations to justify.** The plan follows every constitution principle.

| Violation | Why Needed | Simpler Alternative Rejected Because |
|---|---|---|
| (none) | — | — |

## Constitution Check (post-design)

Re-evaluated after `research.md`, `data-model.md`, `contracts/audio-cloud-sync.md`, and `quickstart.md` are produced.

| Principle | Status | Notes |
|---|---|---|
| I. Architecture & Code Quality | **Pass** | New code lives under existing feature boundaries; no cross-feature shortcuts. `CraftAudioCloudUploader` lives in `lib/features/craft/application/`, reuses `FileStorage` and `DirectUploadsApi` (no new infrastructure). |
| II. Testing Defines the Contract | **Pass** | `quickstart.md` enumerates five required test files mapping to FR-001, FR-002, FR-005, FR-008, FR-011. |
| III. UX Consistency | **Pass** | Reuses `MediaCardProviderBadgePill` slot on `MediaCardRow`/`Tile` (already exists for `provider` pills). Localized strings added to ARB. `docs/features/craft-studio.md` update listed as required. |
| IV. Performance | **Pass** | Byte read off-isolate (P-3), UI badge is derived from cached row state (P-4). No work inside `build` paths. |
| V. Documentation | **Pass** | ADR 0049 (`docs/decisions/0049-crafted-audio-cloud-sync.md`) listed as required; `docs/features/craft-studio.md` updated. |
| Flutter Quality Gates | **Pass** | `validate_ci_gates.sh`, `flutter analyze`, `flutter test`, `build_runner build` listed in `quickstart.md`. Linux is a supported target per ADR-0048 and is part of the regression checks. |

No constitution violations. Plan is ready for `/speckit-tasks`.

## Open questions resolved during research

These are the items the explore agent flagged as "UNCLEAR" and how the plan resolves them. The corresponding rationale is expanded in `research.md`.

1. **Where the binary upload lives** → `SyncUploadService.uploadAudio()` as a new pre-step for `provider == 'craft'`. Rationale: keeps a single code path that any future caller (not just Craft) can opt into; reuses the existing queue + retry + offline behavior.
2. **Read bytes from `localUri`** → add a small helper `FileStorage.readAppManagedMedia(String fileUri)` that mirrors `deleteAppManagedMedia` in shape and isolates `Uri.file` parsing from callers.
3. **Server contract for attaching a blob** → assume the server's `POST /api/v1/mine/audios` accepts `signedId` in the body (mirrors web app's `attachMediaBlobToPayload`). The plan includes a fallback path: if the server response does not include `mediaUrl` after attaching `signedId`, log and continue (the row stays valid locally; retry on the next queue drain will re-attempt).
4. **Extending `syncStatus`** → no new enum value needed. The existing `'pending'` (upload not yet attempted), `'synced'` (success), and `null` (never enqueued) cover the states we need. The `cloudSyncBadge` is computed from `(syncStatus, mediaUrl != null)`. No transient `'uploading'` state — the UI badge just shows "Synced" or "Pending sync" based on durable state.
5. **Per-item sync badge UI** → extend `MediaCardRow`/`MediaCardTile` with a new optional `cloudSyncBadge: MediaCardSyncBadge?` parameter that renders the existing `MediaCardProviderBadgePill` style with new icon + color mapping. This is consistent with the existing `providerBadge` slot.