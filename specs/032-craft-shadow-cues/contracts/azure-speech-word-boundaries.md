# Contract: Method-Channel Synthesis Word Boundaries

**Feature**: `032-craft-shadow-cues` | **Date**: 2026-07-30

This contract documents the JSON shape exchanged across the `azure_speech` method channel for the `synthesize` method. It is **already implemented** on Android (Kotlin) and Windows (C++); the iOS/macOS Swift plugin must produce the **identical** shape. The Dart parser (`method_channel_azure_speech.dart`) is the consumer and is unchanged.

Reference: research.md §R8, §R9.1.

---

## Method

`azure_speech` method channel, method `synthesize`.

## Request (Dart → native)

Unchanged by this feature. Documented for completeness:

| Key | Type | Required | Notes |
|---|---|---|---|
| `text` | String | yes | Text to synthesize. |
| `language` | String | yes | BCP-47 locale (e.g. `en-US`, `zh-CN`). |
| `voice` | String | no | Azure neural voice name. |
| `token` | String | no* | Azure auth token (Enjoy default path). |
| `subscriptionKey` | String | no* | Azure subscription key (BYOK-Azure path). |
| `region` | String | yes | Azure region. |

\* Exactly one of `token` / `subscriptionKey` must be non-empty.

## Response (native → Dart)

The native handler returns a **String**. Two accepted shapes:

### Shape A — JSON object (word boundaries present)

```json
{
  "audio": "<base64-encoded WAV bytes>",
  "wordBoundaries": [
    { "text": "Hello", "audioOffset": 50000, "duration": 320000 },
    { "text": ",", "audioOffset": 380000, "duration": 40000 },
    { "text": "world", "audioOffset": 430000, "duration": 300000 }
  ]
}
```

### Shape B — plain base64 string (legacy / no boundaries)

`"<base64-encoded WAV bytes>"` — Dart detects by `!raw.startsWith('{')`; word boundaries come back empty (blank-transcript fallback).

## Word-boundary object

| Key | Type | Unit | Required | Notes |
|---|---|---|---|---|
| `text` | String | — | yes | The spoken token text. For punctuation boundaries, the punctuation character(s). |
| `audioOffset` | integer | **100-nanosecond ticks** | yes | Offset from audio start. |
| `duration` | integer | **100-nanosecond ticks** | yes | Spoken duration of this token. |

**Dart decode** (`method_channel_azure_speech.dart:120-130`): `audioOffsetMs = (audioOffset / 10000).round()`; `durationMs = (duration / 10000).round()`.

## Platform-specific unit notes (the cross-platform gotcha)

The contract requires **ticks** for both `audioOffset` and `duration`. Each platform's SDK exposes different native units:

| Platform | `audioOffset` native unit | `duration` native unit | Conversion to ticks |
|---|---|---|---|
| Android (Java/Kotlin) | ticks (`Long`) | ticks (`Long`) | none — emit verbatim |
| Windows (C++) | ticks (`uint64_t`) | **milliseconds** | `duration * 10000` |
| **iOS/macOS (Swift/ObjC)** | ticks (`NSUInteger`) | **seconds** (`NSTimeInterval` / `Double`) | `Int(duration * 10_000_000)` |

`audioOffset` is uniformly ticks across all three SDKs; **only `duration` differs** and must be normalized to ticks before emitting.

## What is NOT emitted

- `boundaryType` — the ObjC/Swift enum has a `Word`/`Punctuation` collision (research.md §R8 gotcha 2) and the Dart parser does not read it. Punctuation classification is done on the Dart side by text content (`mergePunctuationTokens`).
- `textOffset` / `wordLength` / `resultId` — unused by the Dart parser.

## Error handling (unchanged)

Native returns a `FlutterError` with code `azure_speech_error` (or `no_speech` for code 1) and a localized message on synthesis failure. No change to error semantics.

## Backward compatibility

- Shape B (plain base64) remains valid — a platform/path that cannot supply boundaries (BYOK OpenAI HTTP, Linux) still produces playable audio with empty boundaries → blank transcript.
- Adding `wordBoundaries` to the iOS/macOS response **does not** change the Dart parser (it already decodes the array when present).
