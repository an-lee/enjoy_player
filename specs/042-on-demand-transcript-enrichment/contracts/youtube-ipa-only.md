# Contract: YouTube IPA-only enrich

Applies when `canTrustWordTimes` is false (YouTube WebView / remote without a local file).

## Must

- Split each primary line with `tokenizeWords` (or eSpeak word events) and attach phone **labels** from `EspeakSynthHost.synthesize` via a package `phonemize` API.
- Persist nested `timeline` with **omitted** word `start`/`duration` and omitted phone clocks ([optional-word-times.md](./optional-word-times.md)).
- Keep line text/start/duration/`sourceKey` unchanged.
- Enable IPA after success if any labels exist. Keep karaoke **disabled**.
- Run on the existing eSpeak isolate; cancel between lines. Typical ≤100 lines: **< 15 s** on a current mid-range device (SC-008) without freezing transport.

## Must not

- Download, demux, or FFmpeg the YouTube media URL.
- Call `align` / `alignSegments` (those require source PCM).
- Write dummy word windows (equal split, line duration / n, etc.).
- Seek or loop on IPA tap (`wordMediaWindowMs` is null → existing no-op).
- Swap to another language’s voice when the caption language is unsupported — fail and retry.

## Tests

Pin: YouTube enrich path never invokes PCM extract / FFmpeg helpers. Stored words have no usable `wordMediaWindowMs`. Overlay can show IPA. `karaokeWordIndex` stays null with preference on.
