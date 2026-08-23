# Feature: Vocabulary (porting spec)

## Summary

Vocabulary is Enjoy’s **local-first spaced-repetition (SRS) word book**: save a word while watching/listening (or reading on web), keep every **context** (sentence + locator back into media), review with **3-button flashcards**, optionally **sync** items/contexts to the cloud, and **export Anki CSV** (Pro).

This document is the implementation contract for Enjoy Player (Flutter). It describes **what the Enjoy web app actually implements today** (`~/dev/enjoy/apps/web`), not the aspirational marketing copy under `enjoy/apps/docs/**/vocabulary.md`.

**Status in Flutter:** P0–**P4 shipping**. Local Drift schema + SRS + lookup add/remove; Vocabulary destination (`/vocabulary` from Profile) with compact expandable stats, Review/All Words, flashcard session (flip/rate/skip/undo, desktop in-session shortcuts); review Context/Dictionary write-through; in-route adaptive practice overlay for clip play + in-session echo recorder; open-in-player to full player; multi-context pager; cloud sync of items/contexts with SRS-preserving conflict resolution ([ADR-0054](../decisions/0054-vocabulary-cloud-sync.md)); Pro-gated Anki CSV export from All Words.

**Tracking:** [#375](https://github.com/baizhiheizi/enjoy_player/issues/375).

---

## Goals for the Flutter port

1. Behavioral parity with current web code for add / review / list / delete / AI cache / Anki export.
2. **API- and ID-compatible** schema so multi-device sync can land later without re-keying user data.
3. Fit existing Flutter architecture: Drift + DAOs, Riverpod, `lib/features/vocabulary/`, wire into lookup sheet without regressing ADR-0042 language catalogs.
4. Ship in phases (see [Phased plan](#phased-implementation-plan)); defer ebook add and cloud sync until prerequisites exist.

---

## Implemented vs aspirational (do not port fiction)

| Claim in marketing docs | Web code today |
|-------------------------|----------------|
| Tags / difficulty grouping | **Not implemented** |
| Manual entry & batch import | **Not implemented** |
| Distinct New / Review / Test study modes | **Not implemented** (one flashcard session with selection options) |
| Daily trend charts / “weakest words” | **Not implemented** |
| Custom study plans | **Not implemented** |
| Flashcard Notes tab | **Placeholder only** (`notesPlaceholder`) |
| Local-first word + contexts + SRS | **Yes** |
| 3-rating SM-2 variant | **Yes** |
| Review: due / all / status / language / random N | **Yes** |
| AI dictionary + contextual translation cached on entities | **Yes** |
| Sync items + contexts | **Yes** (reviews **not** synced) |
| Anki CSV export (Pro) | **Yes** |

---

## User journeys

### Entry points (web → Flutter mapping)

| Journey | Web | Flutter target |
|---------|-----|----------------|
| Browse / manage | Sidebar → `/vocabulary` | New route / shell destination (TBD navigation ADR) |
| Home due nudge | `VocabularyReviewSection` | Optional home card once feature ships |
| Add from transcript | Selection → `TextSelectionPanel` → `AddToVocabularyButton` | CTA on existing [dictionary lookup sheet](dictionary-lookup.md) |
| Add from ebook | Ebook selection toolbar | **Defer** until Flutter ebook exists |
| Review session | Review tab → options → fullscreen flashcard | Immersive full-window review route (`/vocabulary/review`): `RootShell` hides sidebar / bottom nav and the mini media player bar for the session (shell-covering immersion; still under `ShellRoute`, ADR-0053) |
| Export Anki | List → Export (Pro) | Same, gated by [subscription](subscription.md) |
| Extension API-only add | Sidepanel (no Dexie) | Out of scope for player |

### Primary flows

1. **Add word + context** — User selects text → lookup sheet → header bookmark icon (Add to Vocabulary / Add Context / Already in Vocabulary). Remove deletes the **entire item** (all contexts), not one context.
2. **Review** — Open Vocabulary → Review → choose due / all / filter / random → immersive full-window cards (no app sidebar / bottom nav) → flip → rate `0|1|2` or skip → optional undo last rating → session complete → leave restores normal shell chrome.
3. **Manage** — All Words tab: search + status/language filters → delete confirm → Export Anki.
4. **During review (card back)** — Context tab (practice overlay for play clip / echo reading; open player; contextual AI; context pager when multi-context); Dictionary tab (persist explanation on item); Notes placeholder.

### Keyboard (desktop review)

| Key | Action |
|-----|--------|
| Space | Toggle flip (front ↔ back) |
| `1` / `2` / `3` | Rate 0 / 1 / 2 |
| ← | Previous (session stack) |
| → | Skip |
| Esc | Exit review (global `modal.close` / GoRouter pop only — not also handled in-session). Session clear runs in `/vocabulary/review` `onExit`, not `State.dispose`. |

Block rating while a mutation is in flight. Align with [hotkeys](hotkeys.md) when wiring global shortcuts.

---

## Domain model

### `VocabularyItem`

Word-level SRS entity. One row per `(normalizedWord, language, targetLanguage)`.

| Field | Type | Notes |
|-------|------|--------|
| `id` | `string` (UUID **v5**) | Deterministic — see [Identity](#identity-normalization-duplicates) |
| `word` | `string` | Normalized form stored |
| `language` | `string` | BCP-47 source language of the word |
| `targetLanguage` | `string` | User native / lookup target |
| `status` | enum | `new` \| `learning` \| `reviewing` \| `mastered` |
| `easeFactor` | `number` | Initial `2.5`; clamp `[1.3, 2.5]` |
| `interval` | `number` | Days; **new items start at `0`** until first successful review path forces min `1` |
| `nextReviewAt` | ISO 8601 | Due when predicate matches (below) |
| `reviewsCount` | `number` | Incremented on **every** rating including “don’t know” |
| `lastReviewedAt` | ISO 8601? | Set on each rating |
| `contextsCount` | `number` | Denormalized count of contexts |
| `explanation` | JSON? | Cached dictionary result (`DictionaryResult` / web `DictionaryResponse`) |
| `createdAt` / `updatedAt` | ISO 8601 | |
| `syncStatus` | enum? | `local` \| `synced` \| `pending` (web `SyncableEntity`) |
| `serverUpdatedAt` | ISO 8601? | Sync bookkeeping |

> **Stale comments in web types** say “UUID v4”. Implementation uses UUID v5 via `generateVocabularyItemId`. Flutter must follow the generator, not the comment.

### `VocabularyContext`

Many contexts per item (appearances in media/ebook).

| Field | Type | Notes |
|-------|------|--------|
| `id` | UUID **v5** | Deterministic from item + source + text + locator |
| `vocabularyItemId` | FK | → item |
| `text` | `string` | Full sentence / paragraph |
| `sourceType` | enum | `Video` \| `Audio` \| `Ebook` |
| `sourceId` | `string` | Media / ebook entity id (must match library ids when possible) |
| `locator` | JSON | `MediaLocator` or `EbookLocator` |
| `explanation` | JSON? | Cached contextual translation |
| timestamps + sync fields | | Same syncable pattern as item |

#### `MediaLocator`

```json
{ "type": "media", "start": 1234, "duration": 5000 }
```

- `start` / `duration` in **milliseconds** (same as transcript lines / web `Recording` ms convention).

#### `EbookLocator` (defer UI; keep schema ready)

Readium-shaped:

```json
{
  "type": "ebook",
  "href": "chapter01.xhtml",
  "locatorType": "application/xhtml+xml",
  "title": "Chapter 1",
  "locations": {
    "fragments": ["epubcfi(...)"],
    "progression": 0.12,
    "totalProgression": 0.05,
    "position": 42
  },
  "text": "selected snippet"
}
```

### `VocabularyReview` (local audit only)

One row per rating for **undo**. **Not uploaded** — no API entity.

| Field | Notes |
|-------|--------|
| `id` | UUID **v4** (random) on web |
| `vocabularyItemId` | FK |
| `rating` | `0` \| `1` \| `2` |
| `at` | ISO timestamp of the action |
| `easeFactorBefore`, `intervalBefore`, `statusBefore`, `reviewsCountBefore`, `nextReviewAtBefore`, `lastReviewedAtBefore?` | Pre-image for undo |
| timestamps + `syncStatus` | Local only; never queue for sync |

### Status lifecycle (via SRS only)

There is no separate “mark known” API outside the three flashcard ratings:

| Transition | When |
|------------|------|
| → `new` | Fresh add, or rating `0` |
| → `learning` | Rating `1` when **pre-increment** `reviewsCount < 3` |
| → `reviewing` | Rating `1` with count `≥ 3`, or rating `2` before mastery |
| → `mastered` | Rating `2` when **post-increment** `reviewsCount >= 5` |

---

## Identity, normalization, duplicates

### Namespace

Same RFC 4122 URL namespace as all Enjoy deterministic ids:

```
6ba7b811-9dad-11d1-80b4-00c04fd430c8
```

Already in Flutter: [`lib/core/ids/enjoy_ids.dart`](../../lib/core/ids/enjoy_ids.dart) (`enjoyUuidNamespaceUrl`).

### Normalize word

Canonical (web `lib/vocabulary-utils.ts` — **use this everywhere**):

```dart
// Conceptual — Unicode letters/numbers/spaces only
word.toLowerCase().trim().replaceAll(RegExp(r'[^\p{L}\p{N}\s]', unicode: true), '');
```

**Bug to avoid:** web `AddToVocabularyButton` existence check uses ASCII `\w` (`/[^\w\s]/g`), which can disagree with DB normalize for non-Latin words. Flutter must use **one** Unicode-safe normalizer for storage, lookup, and UI state.

### Item id (UUID v5)

```
uuidv5("vocabulary-item:${normalizedWord}:${language}:${targetLanguage}", NAMESPACE)
```

Add helpers next to `enjoyVideoId` / `enjoyAudioId`, e.g. `enjoyVocabularyItemId(...)`.

### Context id (UUID v5)

```
uuidv5(
  "vocabulary-context:${itemId}:${sourceType}:${sourceId}:${text.slice(0,100)}:${stableLocatorJSON}",
  NAMESPACE
)
```

`stableLocatorJSON` = `JSON.stringify(locator, sortedKeys)` (web sorts `Object.keys(locator)` before stringify). Flutter must produce the **same string** for the same locator fields or sync will fork duplicates.

### Duplicate rules (`addVocabularyWithContext`)

Atomic transaction (item + context + sync queue):

1. Normalize word; find by `(word, language)` then `targetLanguage`.
2. If no item: create with defaults below; queue item create.
3. If item exists: keep it; load contexts for `(itemId, sourceType, sourceId)`.
4. Duplicate context if same locator:
   - **media:** equal `start` and `duration`
   - **ebook:** `compareEbookLocators` equality
5. If duplicate context → return `{ item, context, isNew: false }` (no count bump).
6. Else insert context; if item already existed, `contextsCount++`; queue context create.

### New item defaults

| Field | Value |
|-------|--------|
| `status` | `new` |
| `easeFactor` | `2.5` |
| `interval` | `0` |
| `nextReviewAt` | `now + 24 hours` (ISO) |
| `reviewsCount` | `0` |
| `contextsCount` | `1` (on first context) |

### Delete

Deleting an item **cascades** all local contexts (and should delete local review audit rows). Queue item delete for sync. Document/verify server cascade for orphaned contexts when sync lands.

---

## SRS algorithm (must match exactly)

Source of truth: `enjoy/apps/web/src/lib/vocabulary-srs.ts` (+ `vocabulary-srs.test.ts`).

### Constants

| Name | Value |
|------|--------|
| `MIN_EASE_FACTOR` | `1.3` |
| `MAX_EASE_FACTOR` | `2.5` |
| `DEFAULT_EASE_FACTOR` | `2.5` |
| `MIN_INTERVAL_DAYS` | `1` |
| `MAX_INTERVAL_DAYS` | `365` |

### Ratings

| UI | Value | Meaning |
|----|-------|---------|
| Don’t Know | `0` | Reset / harder |
| Know | `1` | Normal progression |
| Know Well | `2` | Easier / longer interval |

### Formulas

Let `ease`, `interval`, `reviewsCount` be **current** (pre-update) values. Always:

- `reviewsCount' = reviewsCount + 1`
- `lastReviewedAt' = now (ISO)`

**Rating 0**

```
ease'     = max(1.3, ease - 0.15)
interval' = 1
status'   = new
```

**Rating 1**

```
interval' = (reviewsCount == 0 || interval == 0)
            ? 1
            : clamp(round(interval * ease), 1, 365)
status'   = reviewsCount < 3 ? learning : reviewing   // PRE-increment count
```

**Rating 2**

```
ease'     = min(2.5, ease + 0.1)
interval' = (interval == 0)
            ? 1
            : clamp(round(interval * ease' * 1.5), 1, 365)
status'   = reviewsCount' >= 5 ? mastered : reviewing  // POST-increment count
```

### `nextReviewAt`

UTC midnight of calendar day `(today UTC + interval' days)`:

```
date = now UTC
date.day += interval'
date.setUTCHours(0, 0, 0, 0)
nextReviewAt = date.toISOString()
```

### Due predicate

```
nextReviewAt <= now
AND (lastReviewedAt is null OR nextReviewAt > lastReviewedAt)
```

Web once repaired corrupt rows (`interval < 1` or `nextReviewAt <= lastReviewedAt`) in Dexie schema v20. Flutter should enforce invariants on write and optionally include a one-time migration if importing bad data.

### Review write + undo

**Mark reviewed** (atomic):

1. Capture pre-image into `VocabularyReview`.
2. Apply `calculateNextReview`.
3. Update item; insert audit; queue item sync (`update`).

**Undo latest** (atomic):

1. Load latest audit by `(vocabularyItemId, at)` descending.
2. Restore `*Before` fields onto item.
3. Delete audit row; re-queue item sync.
4. Session UI keeps a stack of rated item ids for undo order.

---

## Data layer

### Web (reference)

| Store | Dexie indexes (current) |
|-------|-------------------------|
| `vocabularyItems` | `id, word, language, [word+language], status, nextReviewAt, [language+status], syncStatus, createdAt, updatedAt` |
| `vocabularyContexts` | `id, vocabularyItemId, sourceType, sourceId, [sourceType+sourceId], syncStatus, …` |
| `vocabularyReviews` | `id, vocabularyItemId, [vocabularyItemId+at], at, syncStatus, …` |

React Query: `use-vocabulary-queries.ts`, `staleTime` 30s; mutations invalidate list/detail/stats/contexts/`byWord`.

### Flutter (target)

| Layer | Responsibility |
|-------|----------------|
| Drift tables | `vocabulary_items`, `vocabulary_contexts`, `vocabulary_reviews` under `lib/data/db/tables/` |
| DAOs | CRUD, due query, add-with-context transaction, undo |
| Domain | Pure models + `calculateNextReview` (no Flutter imports) |
| Application | Riverpod notifiers / repositories; sync enqueue when sync lands |
| Presentation | `lib/features/vocabulary/presentation/` |

Suggested feature layout:

```
lib/features/vocabulary/
  application/   # notifiers, review session controller
  data/          # repositories wrapping DAOs + API clients (when sync)
  domain/        # models, srs, normalize, id helpers (or reuse core/ids)
  presentation/  # page, list, flashcard, dialogs
```

Persist JSON blobs (`explanation`, `locator`) as text columns with typed encode/decode — same pattern as other Drift JSON fields in the app.

### REST API

Client reference: `enjoy/packages/api/src/services/vocabulary.ts`.

| Method | Path | Body / params |
|--------|------|----------------|
| List items | `GET /api/v1/mine/vocabulary_items` | `language?`, `limit?` (default 50), `updatedAfter?` |
| Get item | `GET /api/v1/mine/vocabulary_items/:id` | |
| Upload item | `POST /api/v1/mine/vocabulary_items` | `{ vocabularyItem: {...} }` |
| Delete item | `DELETE /api/v1/mine/vocabulary_items/:id` | |
| List contexts | `GET /api/v1/mine/vocabulary_contexts` | `vocabularyItemId?`, `sourceType?`, `sourceId?`, `limit?`, `updatedAfter?` |
| Get / upload / delete context | same under `/vocabulary_contexts` | POST body `{ vocabularyContext: {...} }` |

**No** review-audit endpoints.

Cursor pagination: `updatedAfter` ISO timestamp.

### Sync semantics

[ADR-0054](../decisions/0054-vocabulary-cloud-sync.md) extends [ADR-0010](../decisions/0010-cloud-sync-mvp.md) / [sync.md](sync.md) (previously audio/video/recording only) to cover vocabulary items and contexts:

| Entity | Upload / download | Conflict |
|--------|-------------------|----------|
| `vocabularyItem` | Yes | Prefer newer SRS: compare `lastReviewedAt`, else higher `reviewsCount`; may keep local SRS while adopting newer server metadata (`resolveVocabularyItemConflict`, [lib/features/vocabulary/domain/vocabulary_item_conflict.dart](../../lib/features/vocabulary/domain/vocabulary_item_conflict.dart)) |
| `vocabularyContext` | Yes | Last-write-wins on `updatedAt` |
| `vocabularyReview` | **Never** | Device-local undo history |

Unlike audio/video/recording, vocabulary **auto-pulls on every signed-in `fullSync`** (paged `updatedAfter` cursors) — a documented, narrow exception to [ADR-0013](../decisions/0013-local-first-sync.md)'s no-auto-mirror policy, since a word book is a cross-device dataset rather than local-path media.

Offline: full local CRUD/review. AI dictionary / contextual translation require network when cache empty.

---

## UI surfaces

### Vocabulary page

- Compact header with back + title; centered column (`contentMaxWidth`).
- List-first chrome: no persistent stats banner. **Due** count is a badge on the **Review** tab; Total / Due / status breakdown opens from an app-bar insights action (adaptive sheet).
- Equal-width segmented tabs: **Review** | **All Words** (due badge on Review).

### Review entry + options

On **mobile** the word list is the default landing tab; the Review tab provides
statistics (total / due / status breakdown) as a collapsible detail within the
review setup rather than a persistent banner, keeping the word list as the
primary focus.

Modes (selectable cards with short hints + live queue count):

| Mode | Behavior |
|------|----------|
| Due | Items matching due predicate |
| All | Entire vocabulary |
| By status | Filter one status |
| By language | Filter one source language |
| Random | Shuffle then take N (Fisher–Yates; default N=20) |

Empty states: no words; no due with **Custom review** CTA in the empty panel (not a contradictory bottom “Start review”).

### Flashcard session

- Immersive study chrome (no dense AppBar): progress `current / total` + progress track (5px); **Skip** as quiet header text; undo; desktop-only muted keyboard shortcut hint; close tooltip = exit review.
- **Adaptive study stage:** compact windows fill available height (cap 560); regular windows use ~82% height (420–640) and `contentMaxWidth`; front/back share the same stage; fade-only flip.
- Front: hero word + muted context with **word highlight**; **Pronounce** control beside the headword (Worker model audio via shared pronounce stack — [ADR-0064](../decisions/0064-word-pronounce-client.md)); locale from the card’s **`item.language`** (bare tags like `ja` resolve to regional Worker locales). Distinct from Context **Play segment** (media clip). Stronger pill “tap to flip” affordance + semantics.
- Space **toggles** flip; **Flip back** under ratings. Flipping prefetches contextual translation **and** dictionary when missing (signed-in).
- Back tabs (pill segmented control — **Notes hidden until implemented**):
  - **Context** — quote block with word highlight; **context pager** (prev/next + n of m) when the item has 2+ contexts; **media title** from library; locator meta; media actions; contextual content parsed into app section labels + body markdown (redundant/empty heading sections pruned). Headword row repeats the same **Pronounce** control as the front (not the Play segment / Echo media chips). Flip, rate, and session transitions stop any in-flight pronounce playback.
  - **Dictionary** — auto-loads when cache empty (loading spinner while fetching; retry only after failure). Structured senses (IPA single slash pair, POS, definition, translation, examples) when available.
- **Practice overlay (in-route, adaptive):** Play segment and Echo reading open a shared panel stacked over the flashcard (bottom-aligned on compact, centered on wide) — not a navigator modal/dialog. Clip practice claims a `PlayerSurfaceTarget` so the permanent RootShell [`PlayerSurfaceHost`](../../lib/features/player/presentation/widgets/player_surface_host.dart) positions its sole video/WebView stage at the modal's global bounds (ADR-0057). Pipeline: `clipOpening` (resolve/open with `OpenMediaOptions.explicitLaunch`) → await surface readiness → seek → activate bounded clip window → play → `clipReady` (attach portal). Dismiss pauses, clears the playback session (no mini-bar), keeps the YouTube WebView mounted on its idle page, parks the surface, and keeps the flashcard mounted. Echo is recorder-only (`ShadowReadingPanel` with context media id / locator / language; no `PlayerController` / global echo activation): the overlay shows the **context sentence** (word highlighted) above the recorder so the learner can read while practicing; its recorder controls remain enabled independently of global EchoMode. Shadow-reading hotkeys (record / play take / pitch / assess) pulse the shared bus while echo practice is open even without a player session. Modes are mutually exclusive. Overlay is modal (dismiss before rate/flip; Esc clears practice, does not exit review). Global mini-bar is suppressed while clip practice is open.
- **Open in player / source** — confirm **replaces** the review route with `/player/:id?start=…&end=…&autoplay=1&clip=1&norestore=1` via `PlayerLaunchRequest.vocabularyOpenSource`. This opens the normal expanded video + transcript screen at the context locator with Echo active, rather than a standalone video-only destination. Review `onExit` clears the session once; do not pop-then-navigate.

Rating row: one-line chips (48px tall, max width 400, centered) with soft error / primary / tertiary fills. Scrollable study body is independent of the sticky rating footer.

**Desktop scrolling:** back-tab content (`_TabBody`) attaches an explicit `ScrollController` to both `SingleChildScrollView` and `Scrollbar`. Desktop `Scrollbar` defaults to `PrimaryScrollController`, which `SingleChildScrollView` does not auto-attach to — without the explicit pair, scrolling the Context / Dictionary tabs on desktop throws. Mobile scrollables are unaffected.

### Word list

- One toolbar: search + filter toggle + Export. On **mobile** the filter
  controls (status/language menus) are collapsed behind the toolbar toggle by
  default to maximize word-list viewport — they expand inline when activated.
  Gutters match `EnjoyPage` hub metrics.
- Rows: word title; one status chip + muted secondary line (`contexts · reviews · next-review`); language trailing + overflow delete (confirm).
- Localized load-failure + retry; no-match empty copy.

### Add-to-vocabulary control (lookup sheet)

Icon button in the sheet header next to **Copy** (same 44×44 chrome). Tooltip carries the CTA label; filled bookmark when already saved.

States:

| State | Tooltip | Icon | Action |
|-------|---------|------|--------|
| Not in book | Add to Vocabulary | `bookmark_add_outlined` | Create item + context |
| In book, new context | Add Context | `bookmark_add_rounded` | Append context |
| Exact context exists | Already in Vocabulary | `bookmark_rounded` (primary) | Offer delete whole item |
| Busy | Adding… / Removing… | Spinner | Disable |

Wire into [`dictionary_lookup_sheet.dart`](../../lib/features/lookup/presentation/dictionary_lookup_sheet.dart) without changing lookup language catalog rules ([ADR-0042](../decisions/0042-multi-language-lookup-catalog.md)).

Default `targetLanguage`: user’s native preference (web `settingsStore.nativeLanguage`). Source: lookup source resolution already in lookup feature.

### Home widget (optional P1+)

Due count + up to 4 random word chips → open Vocabulary.

---

## Context builders (media)

### Transcript → context (required for P0)

Web: `components/transcript/vocabulary-context-builder.ts`.

Rules:

1. Prefer a **complete sentence** containing the **active cue**: expand ±`kVocabularyContextLineRadius` (3) cues from that single seed line, then trim with `getSentenceBoundaries`.
2. If echo is active and the echo region itself is **more than one sentence** (2+ terminators, or a terminator plus trailing text) → use the **full echo region** (do not shrink to one sentence). Locator = first echo line start → last echo line end (ms).
3. If the transcript has **no punctuation** (no sentence terminators in the search window) → use that same bounded ±3 window around the active cue. Never expand from the full echo span, or context can become the entire transcript.
4. `sourceType` = `Audio` or `Video` from session; `sourceId` = media id.
5. Locator via `createMediaLocatorFromSeconds(start, duration)`.

Flutter already has a **string-only** builder for lookup AI:

- [`lib/features/lookup/application/vocabulary_context_builder.dart`](../../lib/features/lookup/application/vocabulary_context_builder.dart)
- Tests: `test/features/lookup/vocabulary_context_builder_test.dart`

**Port gap:** extend (or add a sibling) that returns `{ text, sourceType, sourceId, locator }` for persistence — do not only return the string.

### Ebook → context (defer)

Web: `lib/ebook/selection/vocabulary-builder.ts` + Readium locator. Keep types in Drift schema; no UI until ebook reader exists.

---

## AI integrations

| Capability | Persist on | Flutter today |
|------------|------------|---------------|
| Dictionary | `VocabularyItem.explanation` | [`DictionaryResult`](../../lib/features/ai/domain/models/dictionary_result.dart) via lookup / AI services |
| Contextual translation | `VocabularyContext.explanation` | Contextual translation service + lookup sheet section |

### Dictionary JSON shape (web `DictionaryAIResult`)

```ts
{
  word: string
  sourceLanguage: string
  targetLanguage: string
  lemma?: string
  ipa?: string
  senses: Array<{
    definition: string
    translation?: string
    partOfSpeech?: string
    examples?: Array<{ source: string; target?: string }>
    notes?: string
  }>
}
```

### Contextual translation shape

```ts
{
  translatedText: string
  aiModel?: string
  tokensUsed?: number
}
```

When user opens Dictionary / Contextual tabs during review, reuse existing AI services; write-through to the entity so Anki export and offline re-open work.

Auth: same signed-in / credits rules as [dictionary-lookup](dictionary-lookup.md) and [ai](ai.md).

---

## Anki export (Pro)

Spec: `enjoy/apps/web/docs/anki-export-data-standard.md`  
Impl: `enjoy/apps/web/src/lib/anki/export-csv.ts`

| Rule | Detail |
|------|--------|
| Gate | `subscriptionTier == pro` ([subscription.md](subscription.md)) |
| Format | UTF-8 **with BOM** CSV |
| Columns | `Front`, `Back`, `Tags` |
| Note type | Anki **Basic** (HTML in fields) |
| Tags | `vocabulary`, `{language}-{targetLanguage}`, plus `status` if not `new` |
| Front | Large word + all contexts joined by `<hr>` |
| Back | Context translations (markdown→HTML), IPA, translation, POS, numbered definitions, examples, source refs |
| One card | Per vocabulary **item** (contexts merged) |

Limitations to document in UI: ebook titles often unresolved; rich backs need cached explanations.

---

## i18n

Web namespace: `locales/*/vocabulary.json` (en, zh, ja, ko, es, fr, de, pt).

Flutter: add ARB keys under `lib/l10n/` matching user-visible strings (stats labels, review modes, rating buttons, empty states, export Pro copy, add-button states). Mirror the English keys in [User-visible string inventory](#user-visible-string-inventory) below; run `flutter gen-l10n`.

---

## Edge cases & constraints

- Same surface form + different `targetLanguage` (or source language) → **separate items**.
- Remove from add control deletes **whole word**, not one context.
- Review audit / undo is **device-local**.
- New item `interval = 0` but due in 24h; first rating still forces min interval 1 day.
- No offline AI fill when `explanation` empty.
- Pro gate **only** Anki export, not core vocabulary.
- List search is in-memory on the filtered set (no FTS required for v1).
- Opening full player from review **ends** the session (confirm dialog).
- Echo reading from the review practice overlay reuses [shadow-reading](shadow-reading.md) `ShadowReadingPanel`; media clip playback must go through existing `PlayerController` (never construct a second `media_kit` `Player`).

---

## Phased implementation plan

### P0 — Domain + Drift + add from lookup

- [x] Domain models + `normalizeWord` + `enjoyVocabularyItemId` / `enjoyVocabularyContextId`
- [x] Pure `calculateNextReview` + unit tests matching web cases
- [x] Drift tables + DAOs + `addWithContext` transaction + cascade delete
- [x] “Add to vocabulary” CTA on lookup sheet (media contexts only)
- [x] Feature docs stay updated as behavior lands ([ADR-0052](../decisions/0052-vocabulary-local-first-schema.md))

### P1 — Vocabulary screen + review

- [x] Stats + Review / All Words UI
- [x] Review options dialog + fullscreen session + flip + rate + skip + undo
- [x] Keyboard shortcuts (desktop)
- [x] List search/filters/delete
- [x] Empty states

### P2 — Context richness

- [x] Persist dictionary / contextual explanation on entities from review tabs
- [x] Context clip playback via locator
- [x] Open-in-player confirm (exit review)
- [x] Shadow reading entry from context tab (hand-off to player + echo; not embedded in flashcard)

### P3 — Sync

- [x] New ADR ([ADR-0054](../decisions/0054-vocabulary-cloud-sync.md)) extending ADR-0010 for vocabulary entities
- [x] API client + queue entity types + download/upload + conflict rules
- [x] Tests for SRS-preserving merge

### P4 — Anki export

- [x] Pro gate + CSV builder + share/save file UX
- [x] Filter dialog parity with web

### Explicitly out of scope unless product asks

- Tags, difficulty, batch/manual import, trend charts, Notes content
- Ebook add (until ebook reader)
- Extension-only API path
- Marketing “New/Review/Test” modes as separate products

---

## Open decisions (resolve before / during Speckit)

1. **Navigation:** Resolved in [ADR-0053](../decisions/0053-vocabulary-secondary-route.md) — secondary `/vocabulary` route from Profile (not a primary shell tab).
2. **Sync in v1?** Recommend local-first Drift first; sync as P3 with new ADR — but **IDs/schema API-compatible from day one**.
3. Keep web UX “delete whole item from Already in Vocabulary”? Yes (P0).
4. Hotkey registration vs in-modal-only shortcuts ([hotkeys.md](hotkeys.md))? In-session only for P1 (ADR-0053).
5. Home due widget timing (with P1 or later)? Later (not in P1).
6. Random review: Fisher–Yates vs web’s weak shuffle — Fisher–Yates (P1).

---

## Test & verification matrix

| Area | Must cover |
|------|------------|
| SRS | All rating branches; ease clamps; interval caps; mastery at 5; status from pre/post count |
| Normalize / ids | Unicode words; stable context id for same locator; different targetLanguage → different item id |
| addWithContext | New item; add second context; exact duplicate no-op; cascade delete |
| Due query | Boundary on `nextReviewAt`; invalid `nextReviewAt <= lastReviewedAt` excluded |
| Undo | Restores pre-image; second undo / empty stack |
| Widget | Add button states; flashcard flip/rate; list filters; Pro export gate |
| Manual | Add during playback; review due set offline; (later) sync two devices without losing newer SRS |

Port web fixtures from:

- `apps/web/src/lib/vocabulary-srs.test.ts`
- `apps/web/src/db/repositories/vocabulary-item-repository.test.ts`
- `apps/web/src/db/repositories/vocabulary-review-repository.test.ts`

---

## Code map

### Web / packages (source of truth)

| Path | Role |
|------|------|
| `apps/web/src/types/db/vocabulary-item.ts` | Item entity |
| `apps/web/src/types/db/vocabulary-context.ts` | Context + locators |
| `apps/web/src/types/db/vocabulary-review.ts` | Review audit |
| `apps/web/src/lib/vocabulary-srs.ts` | SM-2 variant |
| `apps/web/src/lib/vocabulary-utils.ts` | normalize + locators |
| `apps/web/src/db/id-generator.ts` | UUID v5 helpers + namespace |
| `apps/web/src/db/repositories/vocabulary-*-repository.ts` | CRUD / due / add / undo |
| `apps/web/src/db/schema.ts` | Dexie indexes / migrations |
| `apps/web/src/hooks/queries/use-vocabulary-queries.ts` | React Query API |
| `apps/web/src/db/services/sync-utils.ts` | `resolveVocabularyItemConflict` |
| `packages/api/src/services/vocabulary.ts` | HTTP client |
| `apps/web/src/components/vocabulary/**` | UI |
| `apps/web/src/components/transcript/vocabulary-context-builder.ts` | Media context |
| `apps/web/src/lib/ebook/selection/vocabulary-builder.ts` | Ebook context |
| `apps/web/src/lib/anki/export-csv.ts` | Anki CSV |
| `apps/web/docs/anki-export-data-standard.md` | Export contract |
| `apps/web/src/locales/*/vocabulary.json` | Copy |
| `packages/ai/src/prompts/dictionary.ts` | Dictionary schema |
| `apps/docs/**/vocabulary.md` | Marketing — **aspirational** |

### Flutter (existing footholds)

| Path | Role |
|------|------|
| [`lib/features/lookup/`](../../lib/features/lookup/) | Lookup sheet — attach Add CTA |
| [`vocabulary_context_builder.dart`](../../lib/features/lookup/application/vocabulary_context_builder.dart) | Context **string** for AI |
| [`lib/features/ai/domain/models/dictionary_result.dart`](../../lib/features/ai/domain/models/dictionary_result.dart) | Dictionary JSON model |
| [`lib/core/ids/enjoy_ids.dart`](../../lib/core/ids/enjoy_ids.dart) | Shared UUID v5 namespace |
| [`lib/data/db/`](../../lib/data/db/) | Drift — add vocab tables/DAOs |
| [`lib/features/sync/`](../../lib/features/sync/) | Extended for vocab entities (ADR-0054) |
| [`lib/data/api/services/vocabulary_api.dart`](../../lib/data/api/services/vocabulary_api.dart) | Vocabulary REST client |
| [dictionary-lookup.md](dictionary-lookup.md), [ADR-0019](../decisions/0019-transcript-dictionary-lookup.md), [ADR-0042](../decisions/0042-multi-language-lookup-catalog.md) | Lookup rules |
| [ADR-0010](../decisions/0010-cloud-sync-mvp.md), [ADR-0054](../decisions/0054-vocabulary-cloud-sync.md), [sync.md](sync.md) | Sync scope (vocabulary included) |
| [shadow-reading.md](shadow-reading.md), [subscription.md](subscription.md), [ai.md](ai.md) | Related features |

#### Presentation (`lib/features/vocabulary/presentation/`)

The flashcard and related UI were extracted from a single file into focused modules under a `widgets/` subdirectory (PR #402):

| File | Role |
|------|------|
| [`vocabulary_flashcard.dart`](../../lib/features/vocabulary/presentation/vocabulary_flashcard.dart) | Top-level `VocabularyFlashcard` with front/back flip, rating bar, scrollable tab body |
| [`widgets/vocabulary_flashcard_context_tab.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_flashcard_context_tab.dart) | `FlashcardContextTab` — context quote, source info, media actions, contextual translation |
| [`widgets/vocabulary_flashcard_dictionary_tab.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_flashcard_dictionary_tab.dart) | `FlashcardDictionaryTab` — IPA, POS, senses, definitions, examples |
| [`widgets/vocabulary_context_pager.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_context_pager.dart) | `VocabularyContextPager` — prev/next navigation for multi-context items |
| [`widgets/vocabulary_practice_sheet.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_practice_sheet.dart) | `VocabularyPracticeOverlay` + `VocabularyPracticeSheet` — in-route modal overlay for clip play / echo |
| [`widgets/vocabulary_practice_clip_body.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_practice_clip_body.dart) | `VocabularyPracticeClipBody` — clip mini-player body (video surface target) |
| [`widgets/vocabulary_practice_echo_body.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_practice_echo_body.dart) | `VocabularyPracticeEchoBody` — recorder-only echo practice body |
| [`widgets/vocabulary_stats_strip.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_stats_strip.dart) | `showVocabularyStatsSheet` + `VocabularyStatsBreakdown` — stats metrics grid |
| [`widgets/vocabulary_empty_states.dart`](../../lib/features/vocabulary/presentation/widgets/vocabulary_empty_states.dart) | `VocabularyEmptyState` — reusable empty states (no words / no due / no matches) |
| [`widgets/flashcard_soft_error.dart`](../../lib/features/vocabulary/presentation/widgets/flashcard_soft_error.dart) | `FlashcardSoftError` — reusable error banner widget |

---

## User-visible string inventory

Minimum ARB coverage (from web `en/vocabulary.json`):

`title`, `description`, `review`, `allWords`, `total`, `due`, `new`, `learning`, `reviewing`, `mastered`, `noWords`, `noWordsDescription`, `noDueItems`, `noDueItemsDescription`, `selectReviewItems`, `reviewDueItems`, `reviewAll`, `reviewByStatus`, `reviewByLanguage`, `reviewRandom`, `numberOfWords`, `startReview`, `keyboardShortcuts`, `howWellDoYouKnow`, `dontKnow`, `know`, `knowWell`, `skip`, `progress`, `reviewComplete`, `addToVocabulary`, `addContext`, `alreadyInVocabulary`, `adding`, `searchPlaceholder`, `confirmDelete`, `delete`, `exportToAnki`, `proRequired`, `proRequiredDescription`, `upgradeToPro`, `context`, `dictionary`, `notes`, `notesPlaceholder`, `openInPlayer`, `openInPlayerDescription`, `shadowReading`, `contextualTranslation`, `noContextAvailable`, `dictionaryNotAvailable`, relative next-review labels (`overdue`, `today`, `tomorrow`, `inDays`).

---

## Related ADRs to write when implementing

| Decision | When |
|----------|------|
| Drift schema + local-first vocab (no sync yet) | P0 ([ADR-0052](../decisions/0052-vocabulary-local-first-schema.md)) |
| Vocabulary cloud sync + conflict policy | P3 ([ADR-0054](../decisions/0054-vocabulary-cloud-sync.md)) |
| Shell navigation / IA for Vocabulary destination | P1 ([ADR-0053](../decisions/0053-vocabulary-secondary-route.md)) |

Does not rewrite ADR-0010 / ADR-0013 — extended/clarified via ADR-0054.

---

## Acceptance criteria (feature complete)

- [x] User can add a word + media context from the lookup sheet; duplicates merge correctly.
- [x] Vocabulary screen shows stats, list filters/search, delete.
- [x] Review session supports due/custom selection, flip, 3 ratings, skip, undo; SRS matches web tests.
- [x] Dictionary / contextual results can persist onto item/context.
- [x] Context clip playback and open-in-player work without a second `media_kit` Player.
- [x] Anki CSV export works for Pro with Front/Back/Tags contract.
- [x] Sync upload/download preserves newer SRS state across devices.
- [x] Docs + tests green; `flutter analyze` / `flutter test` / format + codegen gates pass.
