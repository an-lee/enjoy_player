# Research: Friendly AI Credits-Exhausted Errors (045)

**Date**: 2026-08-30 | Sources: enjoy_player working tree, enjoy worker (`/home/an-lee/Projects/enjoy/apps/worker`), three parallel code explorations.

## Current-state facts

### Where the 402 comes from and what the client keeps

- Worker 402 envelope (`enjoy/apps/worker/src/utils/errors.ts:171`): `{error: 'credits_exhausted', message, code: 'CREDITS_EXHAUSTED', required, limit: {label, used, limit, resetAt, window, scope}}`. The soft gate that rejects Azure token (TTS/assessment) requests writes the `allowed: false` audit rows the Credits Usage screen shows.
- `ApiClient._throwApiError` (`lib/data/api/api_client.dart:531-548`) throws `ApiException(message: 'HTTP <status>', statusCode, body)` where `body` is the **camelCased decoded JSON** (`decodeJsonToCamel`, `lib/data/api/json_isolate.dart`). The envelope keys are already camelCase, so `body['error']`, `body['required']`, `body['limit']['resetAt']` survive verbatim.
- **No lib code reads `ApiException.body` today** (only `isDuplicateEntity` indirectly). `AppFailure.toString() => message` → every surface printing `e.message`/`toString()` shows the literal `HTTP 402`.
- `CreditsFailure` is constructed in exactly 3 places: `ai_api_failures.dart:9-11` (all AI via `guardAiCall`), `credits_packages_repository.dart:42-45`, `subscription_repository.dart:69-77` (purchase paths; the Rails 402 body shape is unverified — parser must be best-effort).
- `AppNotice` (`lib/core/notices/app_notice.dart`): `error/warning/info/success(context, message, {SnackBarAction? action})`. **error/warning call `clearSnackBars()` before showing** — repeated failures replace rather than stack (FR-006 satisfied for snackbar idiom). No inline/dialog variants exist.
- `showCreditsFailureWithUpgradeAction` (`lib/features/subscription/presentation/credits_failure_actions.dart:11-26`) — snackbar + `View plans & packages` → `/subscription`. **Zero production callers** (only its test).
- Routes confirmed: `/subscription` = SubscriptionScreen (plans **and** credits packages sections), `/credits` = usage audit.
- Locales: `app_en.arb` (template), `app_zh.arb`, `app_zh_CN.arb`. Real generated `AppLocalizations` used in tests; no fake l10n class, no mockito — fakes implement capability interfaces via provider overrides.

### Surface inventory (14 found) and current 402 behavior

| # | Surface | Credits handling today | User sees on 402 |
|---|---|---|---|
| 1 | Dictionary lookup section (`dictionary_lookup_section.dart:86-101`) | branch + inline "View plans" | **`HTTP 402`** + CTA |
| 2 | Translation lookup section (`translation_lookup_section.dart:68-85`) | branch + inline "View plans" | **`HTTP 402`** + CTA |
| 3 | Contextual translation section (`contextual_translation_lookup_section.dart:283-296`) | **none** (only AuthFailure branch) | **`HTTP 402`**, no CTA |
| 4 | Pronounce icon (`pronounce_icon_button.dart:99-101`) | branch, key `pronounceCreditsExhausted` | localized warning, **no CTA** |
| 5 | Auto-translate (`auto_translate_controller.dart:397-403` → `subtitle_track_picker_sheet.dart:415-429`) | state `blockReason: credits`, key `subtitlesAutoTranslateBlockedCredits` | localized inline text, **no CTA** |
| 6 | ASR generation (`asr_generation_controller.dart:441-448`) | key `asrErrorCreditsExhausted` (+ **unused** `…Hint`) | localized snackbar, **no CTA** |
| 7 | Shadow-reading assessment (`recording_assessment_controller.dart:177-187`) | **none** — collapses to `serviceError` with `debugMessage: e.toString()` | **`Couldn't run assessment: HTTP 402`**, no CTA |
| 8 | Craft translate (`craft_controller.dart:142-148`) | none — generic `CraftTranslateFailure` | generic craft failure text |
| 9 | Craft express ASR (`craft_controller.dart:491-498`) | none — generic `CraftAsrFailure` | generic + Retry |
| 10 | Craft rewrite (`:543-550`) / synthesize TTS (`:201-204`, `_mapTtsFailure:637-645` — the `/azure/tokens` 402 path) | none — generic | generic + Retry |
| 11 | Vocabulary dictionary tab (`vocabulary_review_session.dart:536-542`) | none — masked as `'fetch_failed'` | "network" message (wrong cause) |
| 12 | Vocabulary contextual tab (`:593-599`) | none — masked | same |
| 13 | AI playground (`ai_playground_screen.dart:74-79`) | none | raw `e.message` — internal diagnostic screen |
| 14 | `showCreditsFailureWithUpgradeAction` | exists, correct pattern | **orphaned** |

State preservation/retry: verified intact on all surfaces (selections, drafts, captured audio kept; every surface has a re-trigger affordance) → FR-007 is presentation-only work, no controller redesign needed.

### The BYOK classification trap (spec FR-008)

`throwByokHttpError` (`lib/features/ai/data/byok/byok_http_client.dart:49-59`) preserves the user's own provider's `statusCode`. A BYOK provider 402 flows through `guardAiCall` → **becomes `CreditsFailure` today** → would show the Enjoy upsell CTA. FR-008 forbids this. `guardAiCall` cannot tell Enjoy-worker 402s from BYOK 402s from status alone.

## Decisions

### D1 — Enrich `CreditsFailure` at construction, parse once in core
**Decision**: `CreditsFailure` (`lib/core/errors/app_failure.dart`) gains optional fields `requiredCredits`, `usedCredits`, `limitCredits`, `resetAt` (plus derived `remainingCredits`). A shared best-effort parser `CreditsFailure.fromApiException(ApiException)` lives beside it in `core/errors` (all 3 construction sites already import core; keeping it out of `features/ai` avoids a feature-to-feature dependency for the two repositories).
**Rationale**: single parse point; presentation never touches `ApiException`; const-constructible stays possible; falls back to nulls for empty/garbled bodies (Rails shape unverified).
**Alternatives rejected**: (a) parse at each surface — 14 duplicated decodes, drift risk; (b) a parallel `CreditsInfo` type carried alongside the failure — forces every catch-site signature change for no benefit.

### D2 — Classification: 402 + Enjoy origin → `CreditsFailure`; 402 + BYOK origin → `ProviderBillingFailure`
**Decision**: add `final bool byokProvider` (default `false`) to `ApiException`; `throwByokHttpError` sets it. `mapApiExceptionToAppFailure`: `statusCode == 402 && byokProvider` → new `ProviderBillingFailure extends AppFailure` (localized "your AI provider declined the request (billing)…" message, no Enjoy CTA); `402 && !byokProvider` → `CreditsFailure` with parsed envelope. Both repo mappers (credits/subscription) reuse the same constructor for their Enjoy 402s.
**Rationale**: origin is knowable only where the request was made; a marker flag is the smallest change that makes FR-008 decidable at the single mapping seam. The envelope `error: 'credits_exhausted'` marker alone is insufficient (Rails 402 body unverified) though the parser still uses envelope fields best-effort for numbers.
**Alternatives rejected**: (a) sniffing body shape — fragile against unverified Rails bodies and provider quirks; (b) letting BYOK 402 stay `CreditsFailure` and hiding the CTA per-surface — every surface would need capability-context plumbing.

### D3 — One shared presentation module, three idioms
**Decision**: extend `credits_failure_actions.dart` into the single presentation seam: `creditsFailureMessage(CreditsFailure, l10n)` (numbered message when fields present — "This needs 750 credits, but 200 left today" + reset time; falls back to `subscriptionCreditsLimitMessageWithPackages`), `showCreditsFailureNotice(context, failure)` (existing snackbar + action, now using the builder), and a reusable inline pattern contract (message + `View plans & packages` action) documented for section rows/cards. All CTA labels unify on `subscriptionViewPlansAndPackages` (replacing `subscriptionViewPlans` at the 2 lookup sites for consistency); CTA always → `/subscription`. Snackbar idiom: `AppNotice.error`'s existing `clearSnackBars()` covers FR-006; inline/controller idioms render one row by construction.
**Rationale**: reuses the orphaned helper, keeps route knowledge inside the subscription feature (constitution I), fits all three display idioms without a new widget system.
**Alternatives rejected**: (a) a global error-listener/router that intercepts `CreditsFailure` anywhere — Riverpod has no exception channel; would require wrapper plumbing at every call; (b) per-surface bespoke messages — the inconsistency being fixed.

### D4 — Per-surface mechanics (scope matrix)
**Decision** (minimal-diff, per idiom):
1–2. Lookup sections: keep inline pattern, swap message → builder, CTA label → shared key.
3. Contextual section: add `CreditsFailure` branch mirroring siblings.
4. Pronounce: keep `warning` severity, add `SnackBarAction` CTA, message → builder.
5. Auto-translate: keep `blockReason: credits` state; render site shows builder message + a "View plans" `TextButton` row (currently plain text).
6. ASR: controller maps `CreditsFailure` → existing key **plus** carry a failure-kind flag/envelope in job state so `asr_generation_launcher` can attach the snackbar action (and finally use the unused `asrErrorCreditsExhaustedHint` where the card idiom allows).
7. Shadow reading: add `RecordingAssessmentFailureKind.credits` + catch branch (no `debugMessage` leak for credits); flow renders builder message + CTA action.
8–10. Craft: `CraftTranslateFailure`/`CraftAsrFailure`/`CraftTtsFailure` gain a credits kind (craft failures already forbid raw text); `CraftFailureCard` renders credits message + "View plans" action alongside Retry.
11–12. Vocabulary tabs: session state error token gains `'credits'`; tabs render credits message + CTA instead of the network-flavored text.
13. AI playground: **out of scope** (internal diagnostics screen; raw output is its purpose — documented exception).
14. Purchase paths (FR-010): locate repository-failure display sites in subscription/credits screens and route through the same builder.
**Rationale**: every surface already has a working error slot; this swaps content + adds an action rather than redesigning flows.
**Alternatives rejected**: unifying all surfaces into snackbar-only — would regress inline contexts (lookup sheet) where users expect in-place retry.

### D5 — Localization
**Decision**: new keys (all three ARBs): `creditsExhaustedDetailed` (placeholders required/remaining), `creditsExhaustedResets` (placeholder time), `byokProviderBillingMessage`; CTA reuses `subscriptionViewPlansAndPackages`; fallback reuses `subscriptionCreditsLimitMessageWithPackages`. Reset time formatted with the app's existing intl date/time formatting. Server-provided `message` strings are never displayed (locale mismatch; FR-002).
**Alternatives rejected**: reusing per-feature keys (`pronounceCreditsExhausted` etc.) for the shared message — those stay for their surfaces' severity/lead-in, but the numbered body must be identical everywhere (spec FR-004 consistency).

### D6 — Testing strategy (constitution II)
- **Unit**: envelope parser (full/missing/non-map body, camel keys); `mapApiExceptionToAppFailure` matrix incl. BYOK marker split (extends `chat_service_test.dart` pin); `RecordingAssessmentFailureKind.credits` mapping (new branch in `recording_assessment_controller_test.dart`); craft failure-kind mapping.
- **Widget**: `credits_failure_actions_test` (numbered text + action navigates); dictionary section test updated (CTA label + message); contextual section gains credits case; pronounce action; craft failure card credits kind; vocabulary tab credits token; ASR launcher attaches action. Conventions per existing harness: real `AppLocalizations` delegates, `ProviderScope`/`ProviderContainer` overrides with fake capabilities, no mockito.
- **Regression**: non-402 failures unchanged (existing tests cover several; add network-error assertions where touched).
- Gates: `flutter analyze`, `flutter test`, `bash .github/scripts/validate_ci_gates.sh`; `build_runner` not required (no codegen-annotated additions planned — provider wiring only touches hand-written providers; re-check at task time).

### D7 — Documentation (constitution V)
Update `docs/features/`: `ai.md` (error-translation table gains envelope + origin split), `subscription.md` (entry points now list every AI surface), `dictionary-lookup.md`, `transcript.md`, `asr.md`, `shadow-reading.md`, `craft.md`, `credits-usage.md` (marginal). No ADR: single-seam enrichment + origin flag are reversible implementation choices, not costly-to-reverse architecture (next free number 0086 stays reserved).

## Resolved NEEDS CLARIFICATION
None — Technical Context carried no unknowns after exploration; the two spec-level judgment calls (BYOK handling, recovery destination) were settled in the spec (FR-008, Assumptions) before planning.
