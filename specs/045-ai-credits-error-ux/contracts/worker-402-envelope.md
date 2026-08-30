# Contract: Worker 402 Envelope (consumed, external)

The Enjoy worker's credits-exhausted rejection. Consumed as-is — **no server changes in this feature**. Source of truth: `enjoy/apps/worker/src/utils/errors.ts:171` (`buildCreditsExhaustedBody`), emitted by every 402 the worker returns (AI routes, `POST /azure/tokens`, purchase routes on the worker).

## Wire shape (as seen by the client after `decodeJsonToCamel`)

```json
{
  "error": "credits_exhausted",
  "message": "<English server text — MUST NOT be displayed (locale mismatch)>",
  "code": "CREDITS_EXHAUSTED",
  "required": 750,
  "limit": {
    "label": "daily_credits",
    "used": 800,
    "limit": 1000,
    "resetAt": "2026-08-31T00:00:00.000Z",
    "window": "daily",
    "scope": "user"
  }
}
```

## Field contract

| Field | Type | Presence | Client use |
|---|---|---|---|
| `error` | string, `"credits_exhausted"` | always on 402 | Marker that this 402 is a credits rejection (not parsed for message text) |
| `code` | string | always | Unused (redundant with `error`) |
| `message` | string | always | **Never rendered** — English-only server copy; FR-002 forbids raw text |
| `required` | number | on exhaustion | `CreditsFailure.requiredCredits` |
| `limit.used` | number | on exhaustion | `CreditsFailure.usedCredits` |
| `limit.limit` | number | on exhaustion | `CreditsFailure.limitCredits` |
| `limit.resetAt` | ISO-8601 string | on exhaustion | `CreditsFailure.resetAt` (parse as UTC, display localized) |
| `limit.window` / `limit.label` / `limit.scope` | string | on exhaustion | Unused in v1 (single daily window today) |

## Robustness rules (client-side)

1. Parsing is best-effort: any missing key, non-map body, empty body, or JSON-decode fallback (raw string body) → all envelope fields null → generic fallback message. Never throws, never blocks classification.
2. The Rails-side 402 body shape (subscription routes) is **unverified** — the parser must not assume the envelope there; the status code + non-BYOK origin remains the classification trigger (see [client-presentation-api.md](client-presentation-api.md)).
3. Keys arrive camelCased (client decodes with `decodeJsonToCamel`); the parser reads camelCase keys only.
4. BYOK provider 402s never carry this envelope — they are distinguished by the `byokProvider` marker on `ApiException`, not by body sniffing.
