# Data Model: Feature Onboarding Guides

**Feature**: 034-feature-onboarding | **Date**: 2026-08-06

## Entities

### OnboardingTipId (catalog, code-defined)

| Field | Description |
|-------|-------------|
| `id` | Stable string (e.g. `home.import`, `player.echo`) |
| `sequenceId` | Group: `home.entries` \| `player.empty_transcript` \| `player.practice` |
| `progressScope` | `global` \| `perMedia` |
| `titleKey` / `bodyKey` | ARB message keys |
| `preconditions` | Declared in eligibility (not persisted) |

v1 tip set is listed in [research R5](./research.md) and [contracts/tip-catalog.md](./contracts/tip-catalog.md).

### TipStatus

| Value | Meaning |
|-------|---------|
| `pending` | Never completed or skipped (default when absent) |
| `completed` | Seen through / acted via target / auto-completed |
| `skipped` | User dismissed/skipped; counts as resolved for auto-show |

### TipProgressSnapshot

In-memory + persisted view for the signed-in user:

| Field | Type | Notes |
|-------|------|-------|
| `global` | `Map<tipId, TipStatus>` | Home + practice tips |
| `emptyTranscriptByMediaId` | `Map<mediaId, TipStatus>` | Applies to both local & YouTube empty tips for that media |

### TriggerContext (ephemeral)

| Field | Notes |
|-------|-------|
| `routePath` | e.g. `/`, `/player/:id` |
| `mediaId` | Player only |
| `isYoutube` | From `VideoRow.provider == 'youtube'` |
| `hasTranscript` | Usable lines present |
| `echoActive` | Echo mode on |
| `recordUiReady` | Echo active + shadow record control mounted/enabled |
| `assessUiReady` | Recording available + assess control enabled |
| `blockingOverlay` | Auth/permission/modal that must win |

### Settings persistence

| Key | Value | Scope |
|-----|-------|-------|
| `onboarding.tip_progress_v1` | JSON object `{ "<tipId>": "completed\|skipped", ... }` | User DB |
| `onboarding.empty_transcript.<mediaId>` | `completed` \| `skipped` | User DB, dynamic |

`Reset product tips` deletes the global key and every key with prefix `onboarding.empty_transcript.`.

No sync of these keys to the Enjoy cloud in v1.

## Relationships

```text
OnboardingTipId (catalog)
       │
       ├── TipProgressSnapshot.global[tipId]          (if scope=global)
       └── TipProgressSnapshot.emptyTranscript[mediaId]
                (if scope=perMedia; tip variant local|youtube chosen by TriggerContext)

TriggerContext ──evaluates──► eligible tip sequence
OnboardingController ──reads/writes──► TipProgressSnapshot
Showcase host ──presents──► tips in sequence order
```

## State transitions

### Global tip

```text
pending --(complete via Next / target tap / soft auto-complete)--> completed
pending --(Skip / dismiss sequence)--> skipped
completed|skipped --(Reset product tips)--> pending
```

### Per-media empty-transcript

```text
pending(media A) --(dismiss/skip/complete/obtain transcript)--> resolved(media A)
pending(media B) remains pending independently
resolved(*) --(Reset product tips)--> pending(*)
```

Obtaining a transcript for media A → `completed` for A even if tip never shown.

### Practice sequence (same visit)

```text
eligible echo (hasTranscript, echo tip pending)
  → show echo
  → resolve echo
  → if record pending && recordUiReady → show record (same visit)
  → resolve record
  → if assess pending && assessUiReady → show assess (same visit)
```

Only one showcase active; next tip starts after prior overlay fully closes.

## Validation rules

- Unknown tip ids in JSON are ignored (forward compatible); unknown statuses treated as `pending`.
- Empty-transcript tip id variant (`local` vs `youtube`) is chosen at show time; **progress key is mediaId only** (one resolution covers both variants for that item).
- `resetAll` must not delete non-onboarding settings keys.
- Controllers must not write tip keys unless `SettingsKeys.isKnown` accepts them.
