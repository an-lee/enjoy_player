# Feature: Share practice poster (echo-tailored)

## Summary

The **share practice poster** feature renders a **9:16** branded poster from the user's local recordings and exports it as PNG via the system share sheet (`share_plus`) on iOS / Android or a file picker on Windows / macOS. The poster is **echo-tailored**: when echo mode is active, the cover and hero quote adapt to the **active echo region** and the **live video frame**, making the shared artifact reflect *what the user was just practicing*.

## MVP behavior

- **Trigger**: the shadow-reading toolbar's **leading share slot** shows a **share** action (`SharePracticePosterButton`) on the left of the idle toolbar row. The button is visible only when **echo mode is active** **and** the open media has at least one local recording (the button self-hides via `SizedBox.shrink()` otherwise). Tapping it opens `PracticePosterPreviewSheet`. See [ADR-0068](../decisions/0068-shadow-toolbar-share-button.md) for the relocation from the previously-overlaid transcript chrome.
- **Preview sheet** (`practice_poster_preview_sheet.dart`): 9:16 poster, hero quote, takes / sentences / spoken stats, QR to `https://player.enjoy.bot`.
- **Cover priority**: `echoCoverBytes` (echo-region live capture) → `localThumbnailPath` → `networkThumbnailUrl` → **generative cover** (`GenerativeMediaCover`) seeded by content hash.
- **Export pipeline**: `practice_poster_export.dart` rasterizes the widget tree at the configured pixel ratio and writes PNG to a temp file; the system share sheet picks it up. Capture must **not** read `RenderObject.debugNeedsPaint` (that getter throws `LateInitializationError` in release/profile on Flutter versions that still use `late` + `assert`).

## Echo-aware poster

When echo mode is active and the current media is a video, the poster adapts:

- **Hero quote resolution** (`resolvePracticePosterQuote`): joins the transcript lines spanning `[startLineIndex, endLineIndex]` of the active echo region; strips markup via `subtitleMarkupParser`; emits a `PracticePosterQuote` whose `trailingEllipsis` flag is set when the echo region ends mid-cue. If the echo region is empty, the resolver falls back through (in order): **most-practiced line** (per `TranscriptRecordingCounts`), **longest `referenceText`** in the transcript, then `null` (no quote line).
- **Live cover frame** (`capturePracticePosterEchoFrame`): when the active player exposes a screenshot surface (`media_kit` `Player.screenshot`, i.e. `PlayerEngine.supportsVideoPosterCapture`), the cover is captured as a `Uint8List` and bound to `echoCoverBytes`. YouTube (`YoutubePlayerEngine.supportsVideoPosterCapture == false`) never attempts a capture — its WebView screenshot only rasterizes the HTML chrome, not the composited video frame, producing a solid black image — so the resolver returns `null` immediately and falls through to the local / network cover thumbnail (the YouTube cover URL) instead.

When echo mode is **not** active, the poster falls back to the standard path: local thumbnail → network thumbnail → generative cover, with the most-practiced line as the hero quote.

## Quote resolution priority

1. **Echo region** → join `[startLineIndex, endLineIndex]`, strip markup, ellipsis on cut.
2. **Most-practiced line** (the line with the most `RecordingRow`s intersecting its time range).
3. **Longest `referenceText`** in the loaded transcript.
4. **`null`** → poster renders without a quote (covers and stats still present).

## 9:16 layout overview

```
+----------------------------+
|                            |   ← Cover (echo frame / local / network / generative)
|                            |
+----------------------------+
|                            |
|   Hero quote (2 lines      |   ← First quote line highlighted in echo orange
|   max, ellipsis on cut)    |
|                            |
+----------------------------+
|                            |
|   Takes / Sentences /      |   ← Stats row
|   Spoken time              |
|                            |
+----------------------------+
|   QR → player.enjoy.bot    |   ← Fixed bottom-right corner
+----------------------------+
```

Logical size: `practicePosterLogicalWidth × practicePosterLogicalHeight = 360 × 640` (logical px); the export pipeline scales by `pixelRatio`.

## Code map

| Area | Path |
|------|------|
| Trigger button | [`lib/features/share_poster/presentation/share_practice_poster_button.dart`](../../lib/features/share_poster/presentation/share_practice_poster_button.dart) |
| Preview sheet | [`lib/features/share_poster/presentation/practice_poster_preview_sheet.dart`](../../lib/features/share_poster/presentation/practice_poster_preview_sheet.dart) |
| Widget tree (cover, quote, stats) | [`lib/features/share_poster/presentation/practice_poster_widget.dart`](../../lib/features/share_poster/presentation/practice_poster_widget.dart) |
| Domain model + resolvers | [`lib/features/share_poster/domain/practice_poster_data.dart`](../../lib/features/share_poster/domain/practice_poster_data.dart) |
| Builder / aggregation | [`lib/features/share_poster/application/practice_poster_builder.dart`](../../lib/features/share_poster/application/practice_poster_builder.dart) |
| Echo frame capture | [`lib/features/share_poster/application/practice_poster_echo_frame_capture.dart`](../../lib/features/share_poster/application/practice_poster_echo_frame_capture.dart) |
| Export pipeline | [`lib/features/share_poster/application/practice_poster_export.dart`](../../lib/features/share_poster/application/practice_poster_export.dart) |

## Test coverage pointers

- `test/features/share_poster/practice_poster_aggregate_test.dart` — quote resolution priority + ellipsis flag.
- `test/features/share_poster/practice_poster_echo_frame_capture_test.dart` — frame capture fallback chain.
- `test/features/share_poster/practice_poster_widget_test.dart` — widget tree rendering.
- `test/features/share_poster/practice_poster_export_test.dart` — RepaintBoundary → PNG capture (release-safe path).

## Related

- Echo mode (parent context, share-poster blurb updated to link here): [`docs/features/echo-mode.md`](echo-mode.md)
- Shadow reading (the take-source for the poster's stats + quote): [`docs/features/shadow-reading.md`](shadow-reading.md)