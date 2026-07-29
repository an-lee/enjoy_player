# Contract: Worker Pronounce API (client)

**Upstream**: Enjoy Worker (see monorepo `apps/worker/docs/pronounce.md` and `specs/019-pronounce-api/contracts/http-api.md`)  
**Client entry**: `PronounceApi` on `aiApiClientProvider` (Bearer)

## POST /pronounce

### Request body

```json
{
  "text": "colour",
  "locale": "en-GB"
}
```

| Field | Required | Client rules |
|-------|----------|--------------|
| `text` | yes | Trim; 1–200 chars; do not POST if empty/over limit |
| `locale` | yes | Learning/lookup BCP-47 after client resolve (`en-UK` → `en-GB`; see Worker allowlist: en/zh/ja/ko/es/fr/de/it/pt/ru regional tags) |
| `voice` | no | Omit in v1 (server default voice) |

### Success 200

Parse at least: `audio_url`, `cached`, `locale`, `voice`, `text`, `format`, `provider`.

`audio_url` is playable **without** Bearer (public Worker file route).

### Errors (client mapping)

| Status | Map to |
|--------|--------|
| 401 | `AuthFailure` via `guardAiCall` |
| 402 | `CreditsFailure` |
| 400 | `NetworkFailure` / validation message (show notice) |
| 5xx / network | `NetworkFailure` |

Credits: client does not implement soft-gate; Worker owns charge-on-miss.

## GET audio_url

No auth. Expect `audio/mpeg`. Used by `AudioPlayer` `UrlSource`.
