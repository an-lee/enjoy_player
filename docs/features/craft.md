# Craft from Text

## Summary

**Craft** helps language learners build a personal library of shadow-reading audio by turning spoken or typed thoughts into idiomatic target-language audio. Generated items are regular library media (`provider = 'craft'`) — they support echo mode, transcripts, library browsing, and cloud sync without special wiring.

Craft ships two modes (see [ADR-0060](../decisions/0060-craft-voice-express-dual-mode.md)):

| Mode | Entry | What it does | When to use |
|------|-------|-------------|-------------|
| **Express** (default) | Speak a thought | Voice-first linear flow: speak → ASR → AI rewrite → TTS → save/loop | You want to capture spontaneous thoughts fast |
| **Advanced** | Paste / type text | Two-tool layout: Translate panel + Synthesize panel | You already have prepared text |

The mode is selected with a `SegmentedButton<CraftScreenMode>` in the app bar (`craftModeExpress` / `craftModeAdvanced` labels).

## Navigation

Craft is a first-class entry point (see [ADR-0061](../decisions/0061-craft-first-class-history.md)), reachable from three places:

- **Home header** — an `OutlinedButton.icon` labelled `homeCraftAction` sits before the `Import` button in both `EditorialHeader` trailing sites on Home (loaded and loading/skeleton states share a `_HomeHeaderActions` widget) → `/craft`.
- **Global hotkey** — `c` (`global.craft` in `hotkey_definitions.dart`, scope `global`, customizable) opens Craft from anywhere in the app. No-op when already on `/craft` or a `/craft/*` route.
- **Import chooser** → **Craft from text…** → `/craft` (original entry point, retained).

Flows as a full-screen route; back returns to wherever the user came from.

**Branding**: "Craft" is kept as an untranslated brand term in the Chinese locale (`craftScreenTitle` / `homeCraftAction` both render `"Craft"` in `app_zh.arb`), matching the existing `importCraftFromText` → `"Craft…"` convention — it is not translated to a Chinese word.

### Craft history (`/craft/history`)

An in-app-bar history `IconButton` (tooltip `craftHistoryTooltip`) on the Craft screen opens `CraftHistoryScreen`, which lists every media item where `Audios.provider == 'craft'`, newest-updated first (`craftHistoryProvider` — a thin `StreamProvider` over the existing `mediaLibraryRepositoryProvider.watchAll()`, no new query or schema). Empty state uses `craftHistoryEmptyTitle` / `craftHistoryEmptyHint` / `craftHistoryEmptyAction`.

Each row can **Remove Craft record** (`MediaLibraryRepository.removeCraftHistoryRecord`): clears Craft provenance by setting `Audios.provider` from `'craft'` to `'user'`. The same media id, audio file, and transcript stay in the library for practice (no Craft badge). This is not a library delete and not a soft-hide list. If the removed item is the active edit session (`editingMediaId`), the controller resets via `resetForNextCapture`.

### Edit an existing Craft item

Tapping a history item calls `CraftController.loadForEdit(mediaId)`:

- Loads a `CraftEditSource` snapshot (`lib/features/library/domain/craft_edit_source.dart`) via `MediaLibraryRepository.getCraftEditSource` — returns `null` (surfaced as `craftEditUnavailable`) if the item no longer exists.
- Prefills **Express** mode (stage `rewrite`) when the item's `sourceFlag == 'craft-express'` and it has a native-language transcript; otherwise prefills **Advanced** mode with the reconstructed practice text loaded into the Synthesize tool.
- Sets `CraftJobState.editingMediaId`, which routes the next `saveToLibrary` call to `MediaLibraryRepository.updateCraftedFromText` (update the same media id, replacing audio + primary transcript) instead of `importCraftedFromText` — editing never creates a duplicate library entry. `editingMediaId` is cleared by `setScreenMode` and `resetForNextCapture`.

## Express mode

A linear three-stage pipeline (`CraftStage` enum: `capture` → `rewrite` → `audio`) orchestrated by `ExpressFlow`. The core product insight: **learners can't speak fluently because they don't have enough to say** — so the default flow starts from the user's own voice, not prepared text.

### Capture stage (`CaptureStage`)

- Large mic button (72px phone / 88px tablet+); tap to start, tap red stop button to finish
- Live waveform animation + recording timer while recording
- **Cancel** — discards the take without ASR (`CraftController.cancelCapture()`); also wired to Escape (cancel in place, same priority as shadow-reading cancel) and route leave / back (clears `isCapturing` so reopen cannot stick on a dead Stop UI)
- **Text fallback** — "type instead" link replaces the mic with a `TextField` (skips ASR)
- `AudioRecorder` is owned by the widget (not the controller), recreated after each stop — mirrors the `ShadowReadingPanel` pattern (16kHz mono WAV)
- On stop, `CraftController.stopCapture(bytes)` stores the bytes and `transcribeAndRewrite()` runs ASR (`CraftTranscriber`) → guarded empty-transcript check → LLM rewrite (`CraftTranslator`) → advances to the rewrite stage

### Rewrite stage (`RewriteStage`)

- **Raw transcript card** (muted, italic, labelled "Your words") — long transcripts collapse to 3 lines and expand on tap
- **Editable target text card** (labelled "In [target]…") — `TextEditingController` synced to `state.translatedText` only when the field is not focused, so user edits are preserved across regenerations; field is height-capped (`maxLines: 10`) to avoid layout overflow
- **Options panel** — always-visible `StylePicker` + Azure Neural `VoicePicker` before Generate; style defaults to **Auto**; voice defaults via `defaultVoiceForLanguage` when unset
- Three action buttons:
  - **Regenerate** → `controller.regenerate()` — re-runs the LLM rewrite on the existing raw transcript with the current style
  - **Re-record** → `controller.resetForNextCapture()` — back to the capture stage
  - **Generate audio** → `controller.generateAudio()` — synthesizes with `selectedVoice` and advances to the audio stage

### "Auto" translation style

A new `TranslationStyle.auto` is the **default** for Express mode. Instead of a literal translation, the system prompt (defined in `CraftTranslationServiceTranslator._autoStylePrompt()`) instructs the LLM to act as a **language partner** — reading the user's spontaneous thought, understanding their intent and personal style, and rewriting it idiomatically in the target language as a fluent speaker would naturally say it. The prompt is distinct from all other style prompts (literal, natural, casual, etc.).

`auto.promptSuffix` returns an empty string (the full prompt is assembled by the translator) and `showsCustomPrompt` returns false (no custom-prompt field is shown when Auto is selected).

### Audio stage (`AudioStage`)

- **Collapsed summary block** (language pair + style + truncated target text with a left-border accent)
- **Inline preview player** — play/pause circle + progress slider + time labels, driven by `audiopackets` `AudioPlayer` reading `state.previewAudioBytes` from memory via `BytesSource`
- **Voice** control (shows current voice label; expandable to full `VoicePicker` — changing voice re-synthesizes)
- Two action buttons:
  - **Practice now** (`saveAndPractice`) — primary CTA; saves and navigates to the player route with the new media ID
  - **Say something else** (`saveAndCaptureNext`) — saves to library, shows a snackbar confirmation ("Saved to library"), then resets to the capture stage while preserving session preferences (language pair, style, voice). This is the **rapid-capture loop** for building a personal library in quick succession.

### Failure handling in Express stages

Every Express stage watches `state.failure` and renders a calm error card using the failure's localized `message(l10n)` with a concrete action button mapped from `failure.action`. New failure types for the voice flow:

| Failure | Trigger | Action |
|---------|---------|--------|
| `CraftAsrFailure` | ASR service error (offline, vendor down) | Retry |
| `CraftEmptyTranscriptFailure` | ASR returned a transcript shorter than `craftMinTextLength` | Retry |

Existing failures (`CraftTranslateFailure`, `CraftTtsFailure`, `CraftSaveFailure`, etc.) surface in the same way.

## Advanced mode

Retained for users who already have prepared text. Uses `EnjoyPageKind.hub` (same width family as AI settings) with **stacked** `EnjoyCard` panels — Translate above Synthesize — instead of a cramped dual column.

### Translate tool (`TranslateTool`)

- **Source language** picker (from the lookup language catalog)
- **Target language** pre-filled from the learner's focus language
- **Style preset** selector (formal, casual, etc.) with an optional custom prompt
- **Edit / copy / re-translate** actions on the translated output
- **Same-language guard**: selecting the same source and target language surfaces a localized hint to switch to Speak directly

### Synthesize tool (`SynthesizeTool`)

- **Text** input (either the translated result or pasted learning-language text)
- **Target language** (pre-filled)
- **Voice picker** (Azure Neural voices per language)
- **Preview** button to hear a sample before saving
- **Save** generates the audio file and inserts the media row

### Voice picker (v1)

Azure Neural voices grouped by language. Supported languages map to the subset of the lookup catalog that Enjoy TTS supports:

| Code | Language | Voices |
|------|----------|--------|
| en-US | English (US) | 15+ neural voices |
| zh-CN | Chinese (Mandarin) | 8+ neural voices |
| ja-JP | Japanese | 5+ neural voices |
| ko-KR | Korean | 3+ neural voices |
| es-ES / es-MX | Spanish | 6+ neural voices |
| fr-FR / fr-CA | French | 6+ neural voices |
| de-DE | German | 5+ neural voices |
| pt-BR / pt-PT | Portuguese | 3+ neural voices |
| it-IT | Italian | 3+ neural voices |
| ru-RU | Russian | 2+ neural voices |

Per-call voice selection is v1 scope; the provider-default voice is used for initial creation. Voice names and gender labels come from `AzureVoice` (`lib/features/craft/domain/azure_voice.dart`).

## Provider / capability routing

| Action | Enjoy (default) | BYOK |
|--------|----------------|------|
| Translate | `chatServiceProvider` → Enjoy worker `POST /translations` | `chatServiceProvider` → BYOK LLM (OpenAI / Anthropic / Google-compatible) |
| Synthesize | `ttsServiceProvider` → `EnjoyTtsCapability` → Azure Speech SDK (worker token) | `ttsServiceProvider` → BYOK TTS (OpenAI `/audio/speech` or Azure Speech subscription key) |

**Azure Speech SDK wiring** (`lib/features/craft/data/craft_tts_service_synthesizer.dart`):
1. Fetch a short-lived Azure token via `AzureTokenCache.getToken(purpose: 'tts')` (worker endpoint `POST /azure/tokens`, 9-min TTL).
2. Call `AzureSpeech.instance.synthesize(text, voice, locale)` through the native plugin ([`packages/azure_speech`](../../packages/azure_speech/)).
3. The native SDK returns a WAV byte buffer; saved to the app's audio directory.

BYOK TTS follows the same `AzureSpeech.instance.synthesize` path when BYOK is configured with an Azure subscription key, or calls `TtsService` via the OpenAI-compatible HTTP path.

## Word-segmented transcript

After synthesis, `wordBoundary` events from the Azure Speech SDK produce time-aligned `startMs` / `durationMs` segments. The word segmenter (`lib/features/craft/domain/word_boundary_segmenter.dart`) groups words into ~6-word segments, using sentence-end punctuation as break points. The resulting `track.lines` list is a standard transcript track, so the transcript viewer and echo mode operate without craft-specific code.

## Output schema

| Field | Value |
|-------|-------|
| `Audios.provider` | `'craft'` |
| `Audios.source` | `'craft-express'` (Express mode), `'craft-translate'` (Advanced translate mode), or `'craft-direct'` (Advanced speak directly) |
| `Audios.sourceText` | Original text (retained for re-generation). In Express mode this is the raw ASR transcript; in Advanced translate mode it is the source text; in speak directly it is empty. |
| Audio file | WAV in app audio directory |
| Transcript | One track (`source = 'ai'`) with word-boundary-segmented lines; secondary source-text track in translate mode |

### Deduplication

`SHA-256(sourceFlag | learningLanguage | normalizedText)`. Re-pasting identical text returns the existing media id without making any AI calls. `normalizedText` strips whitespace differences and normalizes Unicode so copy-paste variation does not defeat dedup. Express items use `sourceFlag = 'craft-express'`, so they dedupe independently from Advanced-mode items with the same text.

## Library surface

- **Craft badge**: Library tiles show a Craft indicator for items where `Audios.provider == 'craft'`.
- **Sync routing**: `provider = 'craft'` participates in the existing sync queue (metadata + recording uploads).
- **`deleteMedia` cleanup**: Deleting a Craft media item removes the audio file, transcript rows, and sync queue entry.

## Failure handling

All failures go through the `CraftFailure` sealed hierarchy (`lib/features/craft/domain/craft_failure.dart`):

| Failure | Trigger | Action |
|---------|---------|--------|
| `CraftTranslateFailure` | Translation API error | Retry |
| `CraftTtsFailure` | TTS synthesis error | Retry or open AI settings |
| `CraftSaveFailure` | File write or DB insert error | Retry |
| `CraftSignInRequiredFailure` | Auth session missing | Sign in |
| `CraftOfflineFailure` | No network | Retry when online |
| `CraftSameLanguageFailure` | Source and target language match | Switch to Speak directly |
| `CraftVendorUnsupportedLanguageFailure` | Vendor doesn't support the language | Retry (change language) |
| `CraftAsrFailure` | ASR service error (Express mode only) | Retry |
| `CraftEmptyTranscriptFailure` | ASR transcript shorter than `craftMinTextLength` (Express mode only) | Retry |

**All-or-nothing write**: Translation, synthesis, and save run in a single try block. If any stage fails, no repository write happens — no orphan transcript rows or audio files.

## v1 limits and out-of-scope

| Constraint | Detail |
|------------|--------|
| Text length | 5 000 characters (truncated with ellipsis) |
| Voice picker | Azure Neural only; no local/offline TTS |
| Output format | Audio-only (no video generation) |
| Per-call voice | Provider-default voice used; picker is v1 |
| Offline | Requires network (Enjoy worker or BYOK endpoint) |

## Responsive layout

The Craft screen adapts to phone, tablet, and desktop widths (see [ADR-0055](../decisions/0055-adaptive-page-layout-system.md)):

- **Express mode** uses `EnjoyPageKind.form` — a centered single column with adaptive gutters (no per-screen max widths)
- **Advanced mode** uses `pageGutterOf` for full-bleed gutters
- **AdvancedTools** uses a `LayoutBuilder` with a 600px breakpoint: side-by-side `Row` (TranslateTool left, SynthesizeTool right) on wide screens, stacked `Column` on narrow screens

No `isWide` width calculations or ad-hoc max widths live in Craft widgets — all spacing flows from the layout-token system.

## Architecture map

| Layer | Key files |
|-------|----------|
| **Domain** | `craft_mode.dart`, `craft_screen_mode.dart`, `craft_stage.dart`, `craft_transcriber.dart`, `craft_failure.dart`, `craft_request.dart`, `craft_job_state.dart`, `craft_job_status.dart`, `craft_translator.dart`, `craft_synthesizer.dart`, `azure_voice.dart`, `translation_style.dart`, `word_boundary_segmenter.dart`, `transcript_timestamp_estimator.dart`, `wav_duration.dart` |
| **Application** | `craft_controller.dart`, `craft_history_provider.dart` |
| **Data** | `craft_translation_service_translator.dart`, `craft_tts_service_synthesizer.dart`, `craft_asr_service_transcriber.dart` |
| **Presentation** | `craft_screen.dart`, `craft_history_screen.dart`, `express_flow.dart`, `capture_stage.dart`, `rewrite_stage.dart`, `audio_stage.dart`, `advanced_tools.dart`, `translate_tool.dart`, `synthesize_tool.dart`, `voice_picker.dart`, `style_picker.dart` |
| **Integration** | `LibraryRepository.importCraftedFromText()`, `getCraftEditSource()`, `updateCraftedFromText()` (library data layer); `CraftEditSource` (library domain layer) |
| **AI wiring** | `EnjoyTtsCapability` (`lib/features/ai/data/enjoy/`), `ChatService` / `TtsService` / `AsrService` providers |
| **Native plugin** | [`packages/azure_speech`](../../packages/azure_speech/) (synthesize, word boundary events) |

## Test pointers

- Unit tests: `test/features/craft/` — covers `CraftFailure` messages, `WordBoundarySegmenter` grouping, dedup hashing, `TranscriptTimestampEstimator`, Auto-style prompt, Express capture/rewrite/save/reset flow, ASR + empty-transcript failure mapping, `loadForEdit` mode inference + editing save path (`craft_controller_test.dart`), `craftHistoryProvider` filter/sort (`craft_history_provider_test.dart`).
- Widget tests: `test/features/craft/` — covers CraftScreen mode toggle, CaptureStage idle state, RewriteStage editable target + actions, AudioStage preview + actions, AdvancedTools responsive layout, TranslateTool / SynthesizeTool.
- Repository tests: `test/features/library/library_repository_craft_test.dart` — `getCraftEditSource` timeline reconstruction, `updateCraftedFromText` same-id update + stale-file cleanup.
- Home / hotkey tests: `test/features/library/home_screen_test.dart` (Craft header action navigation), `test/features/hotkeys/global_craft_hotkey_test.dart` (hotkey registration).
- Integration test surface: Craft import flow is exercised in the import-chooser integration test suite.

## Related

- [ADR-0061: Craft first-class Home entry, history, edit](../decisions/0061-craft-first-class-history.md)
- [ADR-0060: Craft Voice-Express dual-mode redesign](../decisions/0060-craft-voice-express-dual-mode.md)
- [ADR-0043: Craft from Text Import](../decisions/0043-craft-from-text-import.md)
- [ADR-0055: Adaptive page layout system](../decisions/0055-adaptive-page-layout-system.md)
- [ADR-0014: AI Capabilities Layer](../decisions/0014-ai-capabilities-layer.md)
- [ADR-0033: BYOK AI Provider Settings](../decisions/0033-byok-ai-provider-settings.md)
- [AI capabilities](ai.md)
- [Library](library.md)
- [Transcript](transcript.md)
- [Settings](settings.md)
- [Spec 010: Craft from Text](../../specs/010-craft-from-text/)
- [Spec 011: Craft Studio Redesign](../../specs/011-craft-studio-redesign/)
- [Spec 028: Craft Voice-Express](../../specs/028-craft-voice-express/)
