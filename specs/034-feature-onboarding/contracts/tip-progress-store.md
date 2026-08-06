# Contract C2: Tip progress store

## Purpose

Persist tip completion so guides do not auto-show again until **Reset product tips** (FR-006, FR-006a, FR-009).

## Storage

| API surface | Behavior |
|-------------|----------|
| DB | Signed-in `AppDatabase` via `appDatabaseProvider` |
| DAO | `SettingsDao.getValue` / `setValue` / `deleteValue` |
| Keys | See below; must pass `SettingsKeys.isKnown` |

### Keys

```text
onboarding.tip_progress_v1
  → JSON: { "<tipId>": "completed" | "skipped", ... }

onboarding.empty_transcript.<mediaId>
  → "completed" | "skipped"
```

`isKnown` accepts the static global key and prefix `onboarding.empty_transcript.`.

## Riverpod API (illustrative)

```text
OnboardingProgress (keepAlive)
  FutureOr<TipProgressSnapshot> build()
  Future<void> markGlobal(String tipId, TipStatus status)
  Future<void> markEmptyTranscript(String mediaId, TipStatus status)
  Future<void> resetAll()
  TipStatus statusOfGlobal(String tipId)
  TipStatus statusOfEmptyTranscript(String mediaId)
```

## Semantics

1. Missing key / missing map entry ⇒ `pending`.
2. `skipped` and `completed` both suppress auto-show for that scope.
3. Empty-transcript progress is **per mediaId** only (not per tip variant).
4. When transcript becomes available for `mediaId`, store MUST mark empty-transcript `completed` for that id.
5. `resetAll()` deletes `onboarding.tip_progress_v1` and every `onboarding.empty_transcript.*` row; MUST NOT touch library, account, or unrelated settings.
6. No cloud sync of onboarding keys in v1.

## Tests

- Mark global → reload provider → still resolved.
- Mark media A empty tip → media B still pending.
- Transcript appear → media A auto `completed`.
- `resetAll` clears global + per-media; other settings keys unchanged.
