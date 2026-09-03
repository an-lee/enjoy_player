# Contract: Event Catalog

**Feature**: `046-posthog-analytics-integration` | **Date**: 2026-09-03
Source of truth for analytics event names and properties. Code constants live in `lib/core/analytics/analytics_events.dart`; a unit test asserts the two stay in sync. Naming follows the vendor recommendation: `[object]_[verb]`, snake_case. Every journey event fires **at most once** per occurrence (spec FR-003 / 045-style dedup expectations).

## Common context (registered once as super properties — E5)

| Property | Type | Notes |
|---|---|---|
| `display_locale` | String (`en`, `zh`) | Current app display language |
| `learning_language` | String (BCP-47) | Current learning language |
| `distribution_channel` | String (`store`, `direct`) | From `distribution_channel.dart` |

Vendor-added system properties (app version, OS, device, session id) are not listed here and must not be duplicated app-side.

## Journey events

### Practice (shadow reading / word-level practice)

| Event | Properties | Fires when |
|---|---|---|
| `practice_session_started` | `surface` (`shadow_reading` \| `word_practice` \| `flashcard`), `item_count` | A practice session begins |
| `practice_session_completed` | `surface`, `duration_seconds`, `items_completed` | The session reaches its natural end (not app kill) |

### Transcripts

| Event | Properties | Fires when |
|---|---|---|
| `transcript_generation_requested` | `source` (`asr` \| `youtube` \| `local_file`), `media_kind` | A transcript job is submitted |
| `transcript_generation_completed` | `source`, `duration_seconds` | Job succeeds |
| `transcript_generation_failed` | `source`, `reason` (closed enum) | Job fails; `reason` ∈ `network`, `credits`, `auth`, `server`, `local`, `cancelled`, `unknown` — never a payload or server message |

### Lookup & translation

| Event | Properties | Fires when |
|---|---|---|
| `dictionary_lookup_performed` | `source` (`selection` \| `manual`), `cache_hit` (bool) | A lookup completes (result shown) |
| `translation_requested` | `kind` (`standard` \| `contextual`), `cache_hit` (bool) | A translation request is submitted |

### Craft

| Event | Properties | Fires when |
|---|---|---|
| `craft_project_created` | `mode` (`from_text` \| `capture` \| `import`) | A craft project is created (`craft-translate`/`craft-direct` → `from_text`, `craft-express` → `capture`; `import` reserved) |
| `craft_practice_completed` | `duration_seconds` | A practice take on a crafted media item is graded (mode is not retained on the crafted media row, so it is not claimed here) |

### Vocabulary

| Event | Properties | Fires when |
|---|---|---|
| `vocabulary_review_completed` | `reviewed_count`, `correct_count` | A review session ends (due-review flow) |

### Subscription & credits

| Event | Properties | Fires when |
|---|---|---|
| `subscription_purchase_started` | `tier` | Checkout entered |
| `subscription_purchase_completed` | `tier` | Confirmed entitlement lands |
| `credits_package_purchased` | `package_id` | Confirmed package purchase |

## Property rules (enforced by facade + beforeSend guard)

1. **Closed vocabulary** — property keys and enum values above are exhaustive; new events/keys extend this file **and** `analytics_events.dart` in the same change (a test enforces the pairing).
2. **No user-generated content** — no media names, transcript/subtitle text, notes, prompts, lookups, emails, or raw server payloads as property values, ever (spec FR-004). Durations and counts are integers; all other values are short tags/enums.
3. **Coarse failures only** — the `reason` enum above is the only sanctioned failure vocabulary; mapping from `AppFailure` types to it lives in one place next to the capture call.
4. **Vendor autocapture names are reserved** — `Application Opened`, `Application Backgrounded`, `Application Installed`, `Application Updated`, `$screen`, `$exception` come from the SDK/observer and are never captured manually.
5. **`$screen` values are route names** — added to `GoRoute(name: …)` entries in `app_router.dart` (e.g. `library`, `player`, `craft`, `settings`); they are route identifiers, not titles containing content.
