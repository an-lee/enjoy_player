# ADR-0019: Transcript dictionary lookup (selection + bottom sheet)

## Status

Accepted

## Context

Language learners need quick **translation**, **contextual explanation**, and **dictionary** entries while reading transcripts, matching the web app’s `TextSelectionPanel` behavior. The Enjoy worker already exposes `/translations`, `/chat/completions`, and `/dictionary/query` (see ADR-0014).

## Decision

1. **Selection scope** — Only the **currently active** transcript cue and cues inside the **echo window** are selectable. Other cues keep **tap-to-seek** and non-selectable text (web parity: `select-none` elsewhere).
2. **Interaction** — `SelectableText.rich` with markup parity; **no `InkWell` seek** when selectable. After any selection change that yields a **non-empty** range, a **200 ms debounce** runs; trimmed length must be **1–100** characters before opening the sheet (covers **double-tap word select**, drag, long-press, keyboard, etc.; we intentionally do **not** filter on `SelectionChangedCause` because double-tap uses `doubleTap`, not `drag`).
3. **Context for LLM** — `buildVocabularyContext` mirrors the web vocabulary builder: echo region with **≥ 2 lines** uses joined cue text; otherwise **±3 line expansion** plus **sentence-boundary** trimming for contextual translation only.
4. **Presentation** — Results open in a **modal bottom sheet** on narrow viewports (`DraggableScrollableSheet` + shared drag handle) and in a **bounded centered dialog** at desktop widths (same breakpoint as the sidebar rail, ≥900px), both sharing the same widget tree. Three **expandable tonal cards** (custom header + `AnimatedSize` body; shimmer skeletons while loading): **Translation** (loads immediately when expanded), **Contextual translation** (markdown via `flutter_markdown_plus`; collapsed by default to save credits), **Dictionary** (collapsed by default). Dictionary calls use **selected text only** (no extra context payload), matching web. Header chrome aligns with the subtitle track picker (title row + 48×48 close; selection + copy; **language picker** row). The sheet body does **not** wrap an additional `SafeArea` when shown from `showModalBottomSheet` with `useSafeArea: true` (avoids double padding).
5. **Languages** — **Source** resolution is layered:
   - `resolveLookupSourceLanguage({chromeLanguage, activeTrackLanguage})` (pure helper in [`transcript_lookup_open.dart`](../../lib/features/lookup/application/transcript_lookup_open.dart)) picks the authoritative raw BCP-47 string with precedence: (a) `PlaybackChrome.language` (mirrors `VideoRow.language` set by the user at import time), (b) the **active transcript track**'s `language` (`activeTranscriptId` + `allTranscriptsForMedia` → `TranscriptTrack.language`) when the video's language is `und` / empty, (c) `null` otherwise.
   - The result is canonicalized via `resolveLookupSource` (`canonicalLookupTag` in [`app_language_catalog.dart`](../../lib/core/application/app_language_catalog.dart), then full BCP-47 or primary-subtag match against `kSupportedLookupLanguageTags`). `und` / empty / unsupported / denylisted primaries fall back to the learner’s **learning language**.
   - The previous "first sibling transcript track" heuristic was deliberately dropped: with Chinese + Korean tracks stored it silently returned `zh-CN` and produced a `zh → zh` sheet that mistranslated Korean selections against Chinese as the source.
   - **Target** = learner **native** preference, canonicalized and never equal to learning (`resolveLookupTarget` + `coerceNativeIfEqualsLearning`). The sheet shows an **ephemeral** source/target picker row (not persisted). **Worker** requests (`EnjoyTranslationCapability`, `EnjoyDictionaryCapability`, `EnjoyContextualTranslationCapability` system prompt) send **base** codes only (`workerLanguageBase`, e.g. `en-US` → `en`) so payloads match the web two-letter contract and never send `und`.
6. **Architecture** — New `lib/features/lookup/` feature slice (`application` / `domain` / `presentation`). Contextual translation is a dedicated **capability** over existing `LlmCapability` (`EnjoyContextualTranslationCapability`) plus `contextualTranslationServiceProvider`.

## Consequences

- **Credits / latency**: Lazy expansion for contextual + dictionary reduces accidental spend; users must expand those sections once per lookup.
- **Toolbar**: Default selection **context menu is suppressed** on transcript selections (sheet auto-opens); users can still use selection handles.
- **Follow-ups**: External links, add-to-vocabulary, TTS on selection, and pausing playback when the sheet opens are intentionally **out of scope** for this ADR.
