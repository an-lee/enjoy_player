# Feature: Dictionary lookup (transcript)

## Summary

While playback is open, the user can **select 1–100 characters** on the **active** transcript cue or on any cue inside the **echo window**. A **bottom sheet** opens automatically (debounced) with:

1. **Translation** — `POST /translations` via `translationServiceProvider`.
2. **Definition (dictionary)** — `POST /dictionary/query` via `dictionaryServiceProvider` (word = selected text only). In the sheet UI this section is labeled **Definition** / **释义** (`lookupSectionDictionary`).
3. **Contextual translation** — LLM markdown via `POST /chat/completions` through `contextualTranslationServiceProvider` (system prompts aligned with web `contextual-translation`); includes optional **surrounding transcript context** from `buildVocabularyContext` (same span rules as add-to-vocabulary: prefer a complete sentence; multi-sentence echo keeps the full echo region; unpunctuated transcripts use a bounded ±3 cue window around the active line).

Sections appear in the sheet in that order: translation, then definition/dictionary, then contextual translation.

## Languages

- **Lookup catalog** — `kSupportedLookupLanguageTags` ([`lib/core/application/app_language_catalog.dart`](../../lib/core/application/app_language_catalog.dart)) is the **separate** source of truth for the lookup sheet's source / target options. First-wave 14 tags: `en-US`, `en-GB`, `zh-CN`, `ja-JP`, `ko-KR`, `es-ES`, `es-MX`, `fr-FR`, `fr-CA`, `de-DE`, `it-IT`, `pt-BR`, `pt-PT`, `ru-RU`. Decoupled from `kSupportedNativeLanguageTags` (profile "native") and `kSupportedFocusLanguageTags` (profile "learning") so widening the lookup picker does not regress profile / settings UI.
- **Default source** is resolved by `resolveLookupSourceLanguage({chromeLanguage, activeTrackLanguage})` with this precedence:
  1. `PlaybackChrome.language` — the video's stored language, set by the user at import time on `VideoRow.language` and propagated to `PlaybackChrome.language`. This is the **authoritative** source per the lookup spec (FR-005). Picking the first sibling track instead previously produced wrong-language lookups when the user had tracks in multiple languages.
  2. The **active transcript track**'s `language` — used only when the video's language is `und` / empty (e.g. imported without picking one but with a Korean / Japanese / etc. transcript attached).
  3. Otherwise the resolver returns `null` and `resolveLookupSource` falls back to the **learning language**.
- `resolveLookupSource` then canonicalizes the resolved BCP-47 string: `canonicalLookupTag` (narrow en / zh short-circuit), then matches against the lookup catalog by full BCP-47 tag (e.g. `ko-KR` → `ko-KR`) or by primary subtag (e.g. `ja` → `ja-JP`). `und` / empty / denylisted primaries fall back to the **learning language**.
- **Default target** — `resolveLookupTarget` returns the user's stored native preference when it is in the lookup list; otherwise it falls back via primary-subtag match (e.g. stored `de-AT` → `de-DE`), then to the first non-source non-learning entry. Null / empty / denylisted natives use the legacy `coerceNativeIfEqualsLearning` path so existing en-US / zh-CN users see no behavior change (zh-CN for learn=en-US, en-US for learn=zh-CN).
- **In-sheet override** — Source / target can be changed per lookup via the picker row (`LookupLanguagePickerRow`); choices are **not** persisted (web parity). Option lists are pre-sorted with the user's learning language first (via `sortLookupLanguages`), then alphabetical by primary subtag, then by region.
- **Cache invalidation** — `LookupSheetResultCache.evictForPair(source, target)` is called before each `setState` on source / target change and on swap, so stale results from the prior pair cannot be observed above the new pair's loading skeletons (FR-006, FR-010, SC-004).
- **Worker payloads** — Translation, dictionary, and contextual system prompts use **stripped base** language codes (`workerLanguageBase`) so the backend never receives regioned `und` or full BCP-47 where the worker expects `en` / `ko` / `ja` etc.
- **Worker rejection** — When the worker rejects a chosen source / target pair (e.g. unsupported regional variant), the section renders `LookupErrorRow` with the localized message + **Retry** affordance. No silent fallback to `en-US` / `zh-CN`.

## UX rules

- **Tap-to-seek** is **disabled** on selectable rows (active + echo cues); other rows behave as before.
- **Selection toolbar** is suppressed on transcript selections; the sheet is the primary affordance.
- **Signed out** — Translation, dictionary, and contextual sections **do not** call the Worker while the user is not `AuthSignedIn`. Each section shows a compact **Account required** callout with a **Sign in** button (`AuthRequiredCallout`) that navigates to `/sign-in?from=…`. After **AuthFailure** (e.g. expired session), the same callout is shown instead of a retry-only error row.
- **Translation** section is expanded on first open and fetches immediately when signed in. **Definition (dictionary)** and **contextual translation** start **collapsed** — expand once to fetch when signed in (saves credits vs eager triple fetch). A credits-exhausted rejection (worker 402, spec 045) shows the shared friendly message — required vs. remaining credits when the worker envelope was parsed — with the **View plans & packages** CTA → `/subscription` in all three sections; BYOK provider billing rejections show provider copy without the Enjoy CTA.
- **Sheet chrome** — Header, selected term, and language row are grouped at the top; scrollable sections use elevated cards (`LookupExpansionCard`) with a nested content well. Header actions (left → right): **Pronounce** (model audio via Worker `POST /pronounce`) + **Add/remove vocabulary** (bookmark icon) + **Copy** + **Close** — matching tonal `IconButton` chrome. Pronounce uses the shared [`PronounceIconButton`](../../lib/features/pronounce/presentation/pronounce_icon_button.dart) with the selection text and **source** language; unsupported locales (outside the Worker allowlist) disable the control with a tooltip — no cross-language voice fallback. Playback stops when the sheet dismisses, the source language changes, or source/target are **swapped**. Copy shows a short **success notice** (`AppNotice` / `lookupCopySuccess`). Auth / credits failures on pronounce use the same notice patterns as other AI calls. Contextual translation body sits in a subtle inset panel so it reads apart from other section content.
- **Language row** — Single segmented control with chevrons on source/target and a centered swap control.

## Code map

| Area | Path |
|------|------|
| Open sheet from transcript | [`lib/features/lookup/application/transcript_lookup_open.dart`](../../lib/features/lookup/application/transcript_lookup_open.dart) |
| Source/target resolution | [`lib/features/lookup/application/lookup_target_languages.dart`](../../lib/features/lookup/application/lookup_target_languages.dart) |
| Language catalog + worker base | [`lib/core/application/app_language_catalog.dart`](../../lib/core/application/app_language_catalog.dart) |
| Context builder | [`lib/features/lookup/application/vocabulary_context_builder.dart`](../../lib/features/lookup/application/vocabulary_context_builder.dart) |
| Sheet UI | [`lib/features/lookup/presentation/dictionary_lookup_sheet.dart`](../../lib/features/lookup/presentation/dictionary_lookup_sheet.dart) |
| Model pronounce (header) | [`lib/features/pronounce/`](../../lib/features/pronounce/) + Worker `POST /pronounce` |
| Language picker row | [`lib/features/lookup/presentation/widgets/lookup_language_picker_row.dart`](../../lib/features/lookup/presentation/widgets/lookup_language_picker_row.dart) |
| Section async providers | [`lib/features/lookup/application/lookup_section_providers.dart`](../../lib/features/lookup/application/lookup_section_providers.dart) |
| Auth-required callout (sign-in CTA) | [`lib/features/auth/presentation/widgets/auth_required_callout.dart`](../../lib/features/auth/presentation/widgets/auth_required_callout.dart) |
| Selectable cue row | [`lib/features/transcript/presentation/transcript_line_tile.dart`](../../lib/features/transcript/presentation/transcript_line_tile.dart) |

## Related

- ADR: [`docs/decisions/0019-transcript-dictionary-lookup.md`](../decisions/0019-transcript-dictionary-lookup.md)
- Pronounce client: [`docs/decisions/0064-word-pronounce-client.md`](../decisions/0064-word-pronounce-client.md)
- AI routes: [`docs/features/ai.md`](ai.md)
- Transcript panel: [`docs/features/transcript.md`](transcript.md)
