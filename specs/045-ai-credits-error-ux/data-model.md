# Data Model: Friendly AI Credits-Exhausted Errors (045)

All changes are in-memory presentation models — no persistence, no Drift schema changes, no new server entities.

## 1. `CreditsFailure` (enriched) — `lib/core/errors/app_failure.dart`

The single carrier of a credits-exhausted rejection from the mapping seam to any surface.

| Field | Type | Source (worker envelope) | Notes |
|---|---|---|---|
| `message` | `String` (inherited) | — | Stays the internal diagnostic string (`'HTTP 402'`); **never rendered** after this feature — presentation uses the builder (D3) |
| `requiredCredits` | `int?` | `required` | Credits the rejected attempt needed |
| `usedCredits` | `int?` | `limit.used` | Credits consumed in the current window |
| `limitCredits` | `int?` | `limit.limit` | Window allowance (tier daily limit) |
| `resetAt` | `DateTime?` | `limit.resetAt` (ISO 8601) | When the window resets (UTC midnight today) |
| `remainingCredits` | `int?` (derived getter) | `limit.limit − limit.used` | Null when either input is null |

**Construction rule**: `CreditsFailure.fromApiException(ApiException e)` — best-effort parse of `e.body` (camelCased JSON). Non-map body, missing keys, or non-numeric values yield nulls (generic-message fallback); parsing never throws. Direct `const CreditsFailure(message)` stays available for tests.

**Validation invariants**: all numeric fields `>= 0` when present (parser clamps negative/garbage to null); `resetAt` parsed as UTC then displayed in the user's locale.

## 2. `ApiException` (one field added) — `lib/data/api/api_exception.dart`

| Field | Type | Set by | Meaning |
|---|---|---|---|
| `byokProvider` | `bool` (default `false`) | `throwByokHttpError` (`byok_http_client.dart`) — the only BYOK HTTP exit point | The error status came from the user's own AI provider, not the Enjoy worker |

## 3. `ProviderBillingFailure` (new) — `lib/core/errors/app_failure.dart`

`final class ProviderBillingFailure extends AppFailure` — a 402 from a BYOK provider. Message is the generic localized copy at render time; **never** carries the Enjoy subscription CTA (spec FR-008). Surfaces without a dedicated branch fall through to their generic error handling unchanged.

## 4. State-machine additions (per-surface kinds)

| State machine | Addition | Effect at render |
|---|---|---|
| `RecordingAssessmentFailureKind` (`recording_assessment_controller.dart`) | `credits` value + `CreditsFailure` catch branch (no `debugMessage`) | Builder message + View plans action (today: leaks `HTTP 402` via `serviceError`) |
| `CraftTranslateFailure` / `CraftAsrFailure` / `CraftTtsFailure` (`craft_failure.dart`, controller `_map*Failure`) | `credits` kind on each (raw-exception-text ban preserved) | `CraftFailureCard`: builder message + View plans action alongside Retry |
| ASR generation job state | failure-kind flag / envelope alongside existing `errorMessage` key | `asr_generation_launcher` snackbar gains action; unused `asrErrorCreditsExhaustedHint` becomes usable |
| `AutoTranslateBlockReason.credits` (exists) | none — render-site change only | Blocked row gains builder message + View plans `TextButton` |
| Vocabulary session `dictionaryError` / `contextualError` | `'credits'` token value | Tab shows credits message + CTA instead of network copy |
| Lookup sections (dictionary/translation/contextual) | none — branch + render change only | `LookupErrorRow` + shared CTA, builder message |

## 5. Existing entities consumed read-only

- `CreditsUsageLog` (`lib/features/credits/domain/credits_usage_log.dart`) — `allowed: false` rows are the server-side audit trail users can already inspect on `/credits`; this feature changes nothing there.
- Worker 402 envelope (see [contracts/worker-402-envelope.md](contracts/worker-402-envelope.md)) — parsed, never persisted.

## State transitions (error presentation, per surface)

```text
idle/ready --AI call--> running --402 (Enjoy)--> credits-error state --[CTA]--> /subscription --purchase--> return -> retry from preserved state
                                --402 (BYOK)---> ProviderBillingFailure path (generic, no CTA)
                                --other-------> existing behavior (unchanged)
```

No controller gains a new long-lived state; credits states are terminal-until-retry exactly like the error states they generalize.
